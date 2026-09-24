# Runbook — subir a captura de NF-e (módulo DFe) em homologação

Branch `feature/motor-busca-nfe-sefaz-no-lugar-da-qive` · PR #9

---

## ⚠️ Leia antes de tudo: o deploy pode ligar a rotina sozinho

O agendamento está dentro do guard que já existe:

```php
if (env('RUN_SCHEDULE') == 1) {
    $schedule->command('dfe:ingerir --agendado')->everyFifteenMinutes()->withoutOverlapping(30);
    $schedule->command('dfe:manifestar', ['--evento' => '210210', '--auto', '--confirmar'])
        ->cron('7,37 * * * *')->withoutOverlapping(30);
    $schedule->command('dfe:manifestar', ['--evento' => '210200', '--auto', '--confirmar'])
        ->cron('22 * * * *')->withoutOverlapping(60);
    $schedule->command('dfe:normalizar')->everyTenMinutes()->withoutOverlapping(20);
    $schedule->command('dfe:conciliar')->everyThirtyMinutes()->withoutOverlapping(30);
}
```

Atualizado em 24/09/2026 para refletir o `Kernel.php` real — a versão anterior
deste bloco já estava incompleta antes da manifestação (faltava o
`dfe:conciliar`, que existe desde antes desta atualização).

O servidor de homologação **já roda o scheduler** — é o que dispara `senig:averbar` e o `schedule-test:tick`. Ou seja: se `RUN_SCHEDULE` já estiver `1` lá, **o simples merge deste código começa a consultar a SEFAZ a cada 15 minutos, sem ninguém apertar nada.**

Combinado com `TIPO_AMBIENTE=1`, isso significa consultar os CNPJs da DPC na SEFAZ **de produção** enquanto a Qive está ativa — que é a causa documentada de consumo indevido (`cStat 656`). Cada bloqueio dura 1 hora, e consultar dentro dele **zera o tempo e reinicia** — um agendador de 15 min entra nesse laço e não sai sozinho.

**Antes do merge, garantir uma das duas:** `RUN_SCHEDULE=0`, ou as empresas da DPC pausadas em `dpc_dfe_empresa` (`status_sincronismo = 'P'`).

> Hoje, em `tst`, as 12 empresas da DPC **estão pausadas** — resquício do teste da ALL CARS. Isso protege por acidente, não por desenho. Não contar com isso sem conferir.

---

## O que NÃO precisa fazer

- **`composer install`** — o PR não adiciona nenhuma dependência (`composer.json` e `composer.lock` intactos).
- **`migrate`** — não há migration. O DDL é script, aplicado por DBA/DBeaver.
- **Criar cron** — o scheduler já existe para o Senig.

## 1. Conferir o banco

As **13 tabelas** `DPC_DFE_*` precisam existir no schema `POSEIDON` do banco que
o servidor usa.

```sql
select table_name from all_tables
 where owner = 'POSEIDON' and table_name like 'DPC_DFE_%' order by 1;
-- esperado: 13 linhas

select count(*) from all_triggers
 where table_owner = 'POSEIDON' and table_name like 'DPC_DFE_%';
-- esperado: 13  (sem trigger, todo insert falha com ORA-01400)

select count(*) from poseidon.dpc_dfe_empresa;
-- esperado: >0  (a carga inicial precisa ter rodado)

select count(*) from poseidon.dpc_parametro where lower(nome) like 'dfe%';
-- esperado: 4  (sem elas o freio cai para 5 e o motor se trava em silencio)
```

> Eram 7 tabelas na instalação de 06/08/2026, e chegaram a 13 com os alters `v2` a
> `v10`. Para a conferência completa — constraints, índices, colunas e comentários
> — rodar o `scripts/ddl/01_04_validacao_dbeaver.sql`, que compara com o esperado.

Se faltar, rodar `workspace/.claude/docs/nfe_dfe/scripts/ddl/01_01_estrutura_dbeaver.sql` — a explicacao esta no `07_ddl-instalacao.md`.

> O `install_dbeaver.sql` e os cinco alters (`v2` a `v6`) foram **removidos do repositório** em 20/08/2026, substituídos pelos scripts consolidados da raiz de `scripts/`. Aqueles arquivos recriariam objetos que o `alter_v2` havia removido por `cascade constraints` e manteriam a UK antiga de `dpc_dfe_documento`, cuja consequência é **perda de documento**. Continuam no histórico do git, se precisar consultar a sequência aplicada em homologação.

Valem ainda as duas armadilhas do DBeaver que já custaram uma instalação silenciosamente incompleta: o `/` que vira `ORA-00900` e o bind do `:new`. Os scripts de hoje foram escritos sem `/`.

## 2. Conferir o `.env` do servidor

**São duas variáveis, e nenhuma delas é parâmetro operacional.** Os quatro
parâmetros do módulo — `dfe_max_consultas`, `dfe_pausa_seg`,
`dfe_max_bloqueios_dia` e `dfe_min_backoff_656` — saíram do `.env` em 02/09/2026
e vivem em `POSEIDON.DPC_PARAMETRO`. Se a consulta da seção 1 vier vazia, rodar
o `scripts/ddl/01_03_parametros_dbeaver.sql` **antes do deploy do código**.

As duas que ficam no `.env` **decidem o comportamento** e precisam de decisão
consciente:

| Variável | Efeito |
|---|---|
| `TIPO_AMBIENTE` | `1` = SEFAZ de produção (documentos reais) · `2` = homologação (**não tem documento de ninguém**, devolve sempre `cStat 137` / `maxNSU 0`) |
| `RUN_SCHEDULE` | `1` liga o agendamento — inclusive o `dfe:ingerir` |

> Não adianta rodar com `TIPO_AMBIENTE=2` esperando capturar: o Ambiente Nacional
> em homologação não entrega documento. Capturar de verdade exige `1`, o que traz
> o risco descrito no topo.

**Conferir também `CACHE_DRIVER`.** O `withoutOverlapping` usa o cache para o
lock. Com `CACHE_DRIVER=array` o lock **não sobrevive entre processos** — e como
o `schedule:run` sobe um processo novo a cada minuto, a proteção contra
sobreposição vira letra morta e duas ingestões podem rodar juntas, dobrando o
consumo na SEFAZ. O `.env.example` traz `file`, que funciona. Não deixar `array`.


## 3. Conferir o ambiente do PHP

| Item | Por quê | Como checar |
|---|---|---|
| **OpenSSL com provider legacy** | o PFX A1 usa RC2-40-CBC; sem o legacy o `readPfx` falha com `error:0308010C` | `dfe:ingerir --dry-run` mostra `certificado ok` ou o erro |
| **`date.timezone = America/Sao_Paulo`** | o parser usa `DateTime`, mas log e `sysdate` dependem do fuso | `php -i \| grep date.timezone` |
| **`storage/logs` gravável** | `--debug` e `Log::debug` escrevem lá | — |

## 4. Validar sem consumir cota

Nesta ordem. Nenhum destes fala com a SEFAZ, exceto onde indicado.

```bash
# 1) o command existe e o banco responde (NÃO chama a SEFAZ)
php artisan dfe:monitorar

# 2) certificados carregam, empresas elegíveis (NÃO chama a SEFAZ)
php artisan dfe:ingerir --dry-run

# 3) o parser roda sobre o que já está gravado (NÃO chama a SEFAZ)
php artisan dfe:normalizar --dry-run
```

O `dfe:monitorar` é somente leitura e mostra backlog, validade de certificado e pendências. Ele sai com código diferente de zero quando há pontos de atenção — isso é normal, não é erro.

**Primeira chamada real**, quando houver decisão de fazê-la — uma só, empresa nomeada explicitamente:

```bash
php artisan dfe:ingerir --empresa=<N> --max-consultas=1 --debug
```

O `--debug` salva request e response em `storage/logs/dfe-ingerir/`. Confira o `<tpAmb>` da resposta para ter certeza de qual ambiente respondeu.

## 5. Ligar o agendamento

Só depois de 1 a 4 e **depois da decisão sobre a Qive**:

```
RUN_SCHEDULE=1
```

Cadência: `dfe:ingerir` a cada 15 min, `dfe:normalizar` a cada 10, `dfe:conciliar` a cada 30. A frequência do `dfe:ingerir` é folgada de propósito — o controle real é por empresa, via `dpc_dfe_cursor.dta_liberado_em`, então a maioria das execuções só confirma que ninguém está liberado e encerra.

`dfe:manifestar` **está agendado desde 24/09/2026** (minutos `7,37` para Ciência, `22` para Confirmação, ambos `--auto --confirmar`), mas isso não liga a manifestação sozinha: é ato fiscal com protocolo definitivo e sem desfazer, e por isso permanece atrás de trancas por empresa (`status_manifestar` + as flags de automação) que nascem fechadas em qualquer ambiente novo. Ligar de verdade é decisão humana, por empresa, depois de aplicar `04_01`/`04_02` — ver [06_operacao-comandos.md](06_operacao-comandos.md).

## 6. Monitorar depois de ligado

```bash
php artisan dfe:monitorar
```

O que vigiar, em ordem de gravidade:

| Sinal | Significado |
|---|---|
| `CONSUMO_INDEVIDO` em `dpc_dfe_execucao` | está havendo colisão — parar e investigar |
| bloqueios em 24h chegando a `dfe_max_bloqueios_dia` | o freio vai recusar consultar; é proteção, não defeito |
| documento com `status_process` em `P`/`A`/`E` há mais de 24h | bruto capturado e não interpretado — é o risco real do desenho em duas etapas: durabilidade sem visibilidade |
| certificado vencendo | o vencimento de 13/11/2025 passou 9 meses sem ninguém notar |

## Como desligar às pressas

Por ordem de abrangência:

```bash
# tudo
RUN_SCHEDULE=0

# uma empresa
update poseidon.dpc_dfe_empresa set status_sincronismo = 'P' where nro_empresa = :n;

# todas, mantendo o cadastro
update poseidon.dpc_dfe_empresa set status_sincronismo = 'P';
commit;
```

Parar **não perde dado**: o cursor fica onde está e a retomada continua de lá. O que não pode é mexer no `nro_ultimo_nsu` — ele é um token devolvido pela SEFAZ e só pode ser continuado; valor diferente resulta em `656` e bloqueia o certificado por 1 hora.

---

## Resumo em três linhas

1. Nada de composer nem migration; conferir tabelas, `CACHE_DRIVER` e OpenSSL.
2. `TIPO_AMBIENTE=2` não captura nada — capturar exige `1`, e `1` só depois do corte com a Qive.
3. **`RUN_SCHEDULE=1` com o código novo liga a captura sozinho.** Decidir isso antes do merge, não depois.

---

Referência de operação dos commands (opções, roteiros e armadilhas): [dfe-comandos.md](06_operacao-comandos.md)
