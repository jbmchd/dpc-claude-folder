# Prompt — Tela de monitoramento do módulo DFe (captura de NF-e de entrada) no DPC

> Cole este arquivo inteiro como pedido de implementação. Ele já traz a arquitetura
> confirmada, o SQL validado contra o banco de teste e as armadilhas que custaram
> tempo antes. **Leia a seção "Erros já pagos" (§9) antes de escrever código.**

---

## 1. O que existe hoje, e por que a tela é necessária

A DPC construiu na **ApiNFE** um motor próprio de captura de documentos fiscais de
entrada (o "módulo DFe"), para substituir o serviço terceiro **Qive**. O motor roda
em dois estágios desacoplados:

| Estágio | Command | Fala com SEFAZ/ADN | Grava |
|---|---|---|---|
| 1 — ingestão | `dfe:ingerir` | **sim** | `dpc_dfe_documento` (XML bruto em BLOB gzip) e avança o cursor |
| 2 — normalização | `dfe:normalizar` | **nunca** | `dpc_dfe_nota`, `dpc_dfe_nota_item`, `dpc_dfe_evento`, `dpc_dfe_cte`, `dpc_dfe_nfse`, `dpc_dfe_emitente` |
.............................~;
x
.............................~;
xOs dois estão agendados no `Kernel.php` sob o guard .............................~;
x`RUN_SCHEDULE=1` e rodam por
.............................~;
xcron dentro do container. **Rodam sozinhos, sem ninguém olhando.**

E aí está o problema que esta tela resolve: **hoje a única forma de saber se o motor
está saudável é abrir o DBeaver e rodar nove consultas na mão.** Quatro camadas de
falha diferentes não têm nenhum canal de aviso:

1. **Documento em erro** — `DPC_DFE_DOCUMENTO.status_process = 'E'` com o motivo em
   `det_erro`. O agendador roda `dfe:normalizar --status=P`, ou seja, **nunca
   reprocessa um `E` automaticamente**. Um bug de parser deixa o documento parado
   para sempre e ninguém é avisado.
2. **Execução com erro** — `DPC_DFE_EXECUCAO.cod_resultado` em
   `ERRO_SEFAZ`, `ERRO_BD`, `CERT_INVALIDO`, `CURSOR_TRAVADO`, `CONSUMO_INDEVIDO`.
3. **Fluxo parado** — `DPC_DFE_CURSOR.status_sincronismo`. `B` (bloqueado) e `C`
   (cert. inválido) se autocuram quando a condição passa; **`P` (pausado) não se
   cura sozinho** — exige ação humana.
4. **Freio de consumo indevido** — o motor conta bloqueios `CONSUMO_INDEVIDO` das
   últimas 24h e, ao atingir `dfe_max_bloqueios_dia` (hoje 10, em `DPC_PARAMETRO` — era `DFE_MAX_BLOQUEIOS_DIA` no `.env` quando isto foi escrito), **para de
   consultar a SEFAZ**. Chegar a esse limite é uma parada total, silenciosa.

Fora do banco, e portanto **fora do alcance desta tela** (ver §8): o log do Lumen
(`storage/logs/lumen-YYYY-MM-DD.log`) e a saída do cron (`/var/log/myjob.log`).

**Objetivo:** uma tela no DPC que responda em cinco segundos "o motor está bem?" e,
quando não estiver, mostre exatamente o quê, desde quando e o que fazer.

---

## 2. Arquitetura obrigatória — por onde os dados chegam

**A ApiNFE não expõe nenhuma rota HTTP para o módulo DFe.** Conferido:
`grep -c dfe ApiNFE/routes/web.php` devolve **0**. O módulo é 100% CLI + banco.

O caminho já estabelecido para as telas SEFAZ do DPC é este, e a tela nova deve
seguir o mesmo:

```
DPC (Vue 2)  --HTTP-->  ApiDPC (Laravel 5.5 / PHP 7.2)  --SQL-->  Oracle poseidon.dpc_dfe_*
```

Referências vivas para copiar o estilo — **leia as três antes de começar**:

- `ApiDPC/app/Http/Controllers/SefazDocumentosFiscaisController.php`
- `ApiDPC/app/Repositories/SefazDocumentosFiscaisRepository.php` (SQL cru + `upperKeys`)
- `DPC/src/app/sefaz/documentos/nfe/components/Main.vue` (grid, filtros, export)

**Não** criar rota na ApiNFE. **Não** fazer o DPC falar direto com o banco. **Não**
criar tabela nova: tudo que a tela mostra já está gravado.

---

## 3. As tabelas que a tela lê (todas em `poseidon`)

| Tabela | Papel na tela |
|---|---|
| `DPC_DFE_EMPRESA` | CNPJs monitorados (`nro_empresa`, `num_cnpj`) |
| `DPC_DFE_CURSOR` | **uma linha por (empresa × tipo de documento)** — cursor de NSU, estado, backoff |
| `DPC_DFE_DOCUMENTO` | a fila do bruto: `status_process`, `det_erro`, `qtd_tentativa` |
| `DPC_DFE_EXECUCAO` | trilha de cada ciclo: resultado, contadores, NSU inicial/final |
| `DPC_DFE_NOTA` | notas normalizadas (`sig_papel_empresa`, `vlr_nota`, `chave_nf`) |
| `DPC_DFE_NOTA_ITEM` | itens da NF-e (conferência de total) |
| `DPC_DFE_EVENTO` / `DPC_DFE_CTE` / `DPC_DFE_NFSE` | volumetria por família |

Dicionário completo de colunas: **`ApiNFE/docs/dfe-tabelas.md`**. Comandos e flags:
**`ApiNFE/docs/dfe-comandos.md`**. Leia os dois — evita inventar nome de coluna.

### Domínios que a tela precisa traduzir para o usuário

`DPC_DFE_DOCUMENTO.status_process`
`P` pendente · `A` em andamento · `C` concluído · `E` **ERRO** · `I` ignorado (tipo sem parser)

`DPC_DFE_CURSOR.status_sincronismo`
`A` ativo · `P` pausado (**não autocura**) · `B` bloqueado (autocura) · `C` certificado inválido (autocura)

`DPC_DFE_EXECUCAO.cod_resultado`
`EM_DIA` · `ORCAMENTO` · `AGUARDANDO` · `CURSOR_TRAVADO` · `CONSUMO_INDEVIDO` · `ERRO_SEFAZ` · `ERRO_BD` · `CERT_INVALIDO`
(os cinco últimos são falha; `EM_DIA` / `ORCAMENTO` / `AGUARDANDO` são normais)

`DPC_DFE_NOTA.sig_papel_empresa`
`DEST` recebida · `EMIT` emitida · `TRANSP` transporte · `AUTXML` citada ·
`OUTRO` nenhum papel casou · `INDEF` ainda não dá para determinar (só o resumo chegou)

---

## 4. Backend — ApiDPC

### 4.1 Arquivos novos

```
app/Http/Controllers/SefazMonitorDfeController.php
app/Repositories/SefazMonitorDfeRepository.php
```

Alterado: `routes/api.php`, dentro do grupo `['prefix' => 'sefaz']` que já existe
(por volta da linha 2968), acrescentando um subgrupo `monitor-dfe`.

### 4.2 Contrato dos endpoints

Todos `GET`, todos dentro do grupo autenticado, resposta no formato já usado pelo
`SefazDocumentosFiscaisController`:

```php
return response()->json(['error' => 0, 'data' => $dados]);
// em falha: ['error' => 1, 'message' => 'Erro ao ...']
```

| Rota | Método | Devolve |
|---|---|---|
| `sefaz/monitor-dfe/painel` | `painel` | KPIs + alertas ativos (é o que a tela carrega primeiro) |
| `sefaz/monitor-dfe/fluxos` | `fluxos` | uma linha por cursor: atraso, %, estado, quando libera |
| `sefaz/monitor-dfe/fila` | `fila` | contagem por `status_process` × `dsc_tipo_doc`, com "parados 24h" |
| `sefaz/monitor-dfe/erros` | `erros` | documentos em `E` com `det_erro`, paginado |
| `sefaz/monitor-dfe/execucoes` | `execucoes` | trilha das últimas N horas, filtrável por resultado |
| `sefaz/monitor-dfe/volumetria` | `volumetria` | quanto foi capturado, por dia e por família |
| `sefaz/monitor-dfe/conferencia` | `conferencia` | notas cuja soma de itens não fecha com o total |

Parâmetros aceitos onde fizer sentido: `nro_empresa` (csv ou array), `cod_tipo_dfe`,
`horas` (default 24), `de` / `ate`, mais `page` / `per_page` nos paginados.

### 4.3 SQL — já validado contra o banco de teste

As consultas abaixo **rodaram sem erro** no Oracle de teste. Use-as como base; mudar
a forma é risco desnecessário. Bind parameter em tudo que vem do request.

**Painel — volumetria consolidada:**
```sql
select 'notas' as objeto, count(*) as qtd from poseidon.dpc_dfe_nota
union all select 'itens de nota',     count(*) from poseidon.dpc_dfe_nota_item
union all select 'eventos',           count(*) from poseidon.dpc_dfe_evento
union all select 'CT-e',              count(*) from poseidon.dpc_dfe_cte
union all select 'NFS-e',             count(*) from poseidon.dpc_dfe_nfse
union all select 'fornecedores',      count(*) from poseidon.dpc_dfe_emitente
union all select 'documentos brutos', count(*) from poseidon.dpc_dfe_documento
order by 2 desc
```

**Fluxos — progresso e estado de cada cursor:**
```sql
select e.nro_empresa, e.num_cnpj, c.cod_tipo_dfe as tipo,
       c.status_sincronismo as st,
       c.nro_ultimo_nsu     as cursor_atual,
       c.nro_maximo_nsu     as maximo,
       case when nvl(c.nro_maximo_nsu,0) >= c.nro_ultimo_nsu
            then c.nro_maximo_nsu - c.nro_ultimo_nsu end as qtd_atraso,
       case when nvl(c.nro_maximo_nsu,0) > 0
            then round(100 * c.nro_ultimo_nsu / c.nro_maximo_nsu) end as pct,
       c.dta_ultima_consulta,
       case when c.dta_liberado_em is null or systimestamp >= c.dta_liberado_em
            then 'liberado'
            else to_char(c.dta_liberado_em,'dd/mm hh24:mi') end as pode_consultar,
       c.cod_ultimo_status, c.dsc_ultimo_motivo
  from poseidon.dpc_dfe_cursor  c
  join poseidon.dpc_dfe_empresa e on e.cod_dfe_empresa = c.cod_dfe_empresa
 order by 7 desc nulls last
```

> O `case` no cálculo de `qtd_atraso` **não é enfeite**: quando o cursor está à
> frente do máximo conhecido (acontece — a fonte informa `maxNSU` só às vezes), a
> subtração crua dá **número negativo**, que já apareceu no `dfe:monitorar` como
> `atraso = -16` e foi somado ao total. Nulo é a resposta certa para "não sei".
> O `nulls last` na ordenação existe pelo mesmo motivo.

**Fila — saúde e o que está parado:**
```sql
select d.status_process as st,
       case d.status_process
            when 'P' then 'pendente'   when 'A' then 'em andamento'
            when 'C' then 'concluido'  when 'E' then 'ERRO'
            when 'I' then 'ignorado (tipo sem parser)' end as situacao,
       d.dsc_tipo_doc as tipo,
       count(*)       as qtd,
       sum(case when d.dta_recebimento < systimestamp - interval '1' day
                then 1 else 0 end) as parados_24h
  from poseidon.dpc_dfe_documento d
 group by d.status_process, d.dsc_tipo_doc
 order by decode(d.status_process,'E',1,'P',2,'A',3,'I',4,'C',5), 4 desc
```

**Erros — o que ninguém vê hoje:**
```sql
select d.cod_dfe_documento, e.nro_empresa, d.nro_nsu, d.dsc_tipo_doc,
       d.dsc_schema, d.chave_nf, d.qtd_tentativa,
       d.dta_recebimento, substr(d.det_erro, 1, 500) as det_erro
  from poseidon.dpc_dfe_documento d
  join poseidon.dpc_dfe_empresa   e on e.cod_dfe_empresa = d.cod_dfe_empresa
 where d.status_process = 'E'
 order by d.dta_recebimento desc
```

**Execuções — a trilha:**
```sql
select e.nro_empresa,
       (select c.cod_tipo_dfe from poseidon.dpc_dfe_cursor c
         where c.cod_dfe_cursor = x.cod_dfe_cursor) as tipo,
       x.dta_inicio, x.dta_fim,
       nvl(x.cod_resultado,'(aberta/rodando)') as resultado,
       x.nro_nsu_inicial, x.nro_nsu_final,
       x.qtd_consulta, x.qtd_documento, x.qtd_nota, x.qtd_evento, x.qtd_erro,
       substr(x.dsc_resultado,1,400) as detalhe
  from poseidon.dpc_dfe_execucao x
  join poseidon.dpc_dfe_empresa  e on e.cod_dfe_empresa = x.cod_dfe_empresa
 where x.dta_inicio > systimestamp - numtodsinterval(:horas, 'hour')
 order by x.dta_inicio desc
```

**O freio — o alerta mais importante da tela:**
```sql
select count(*) as bloqueios_24h
  from poseidon.dpc_dfe_execucao
 where cod_resultado = 'CONSUMO_INDEVIDO'
   and dta_inicio > systimestamp - interval '24' hour
```
> **Superado em 02/09/2026.** O limite saiu do `.env` e vive em `POSEIDON.DPC_PARAMETRO` (`dfe_max_bloqueios_dia` = 10), lido pelos dois projetos. O parágrafo abaixo descreve o problema que motivou a mudança — e que de fato ocorreu.

O limite (`DFE_MAX_BLOQUEIOS_DIA`, default **5**) vive no `.env` da ApiNFE, que a
ApiDPC não lê. **Deixe o limite configurável na ApiDPC** (constante no repositório
ou `.env` próprio, default 5) e mostre sempre como `usado / limite`.

**Conferência — soma dos itens versus total DE PRODUTOS:**
```sql
select e.nro_empresa, n.nro_nf, n.chave_nf, n.vlr_total_produto,
       (select count(*) from poseidon.dpc_dfe_nota_item i
         where i.cod_dfe_nota = n.cod_dfe_nota) as qtd_itens,
       (select round(sum(i.vlr_produto),2) from poseidon.dpc_dfe_nota_item i
         where i.cod_dfe_nota = n.cod_dfe_nota
           and nvl(i.status_compoe_total,'1') = '1') as soma_itens
  from poseidon.dpc_dfe_nota    n
  join poseidon.dpc_dfe_empresa e on e.cod_dfe_empresa = n.cod_dfe_empresa
 where n.dsc_tipo_doc = 'procNF'
   and n.vlr_total_produto is not null
   and abs(n.vlr_total_produto
         - nvl((select round(sum(i.vlr_produto),2) from poseidon.dpc_dfe_nota_item i
                 where i.cod_dfe_nota = n.cod_dfe_nota
                   and nvl(i.status_compoe_total,'1') = '1'), 0)) > 0.02
 order by e.nro_empresa, n.nro_nf
```
> ⚠️ **Não compare contra `vlr_nota`.** Esta consulta fazia isso até 01/09/2026 e
> estava errada: são grandezas diferentes por definição do layout —
> `vNF = vProd - vDesc + vFrete + vSeg + vOutro + vST + vIPI + …`. Toda nota com
> desconto ou frete aparecia como divergente (medido: 9 notas acusadas, 3 delas
> divergindo em exatamente 5,00% — desconto comercial). A coluna
> `vlr_total_produto` guarda o `vProd` do `ICMSTot` justamente para isso.
>
> `is not null` importa: o resumo (`resNFe`) não traz `ICMSTot`, e nota sem o
> valor não é divergente — é **não-conferível**. Nulo não é zero.
>
> `status_compoe_total` filtra de propósito: o layout admite item que **não
> compõe** o total (`indTot = 0`), e o emitente também não o soma no `vProd` —
> o filtro tem que valer dos dois lados.

**Notas por papel:**
```sql
select e.nro_empresa, n.sig_papel_empresa as papel,
       count(*) as notas, round(sum(nvl(n.vlr_nota,0)), 2) as valor
  from poseidon.dpc_dfe_nota    n
  join poseidon.dpc_dfe_empresa e on e.cod_dfe_empresa = n.cod_dfe_empresa
 group by e.nro_empresa, n.sig_papel_empresa
 order by e.nro_empresa, 4 desc
```

---

## 5. As ações da tela (escrita) — e como não fazer besteira

Monitorar sem poder agir obriga o usuário a abrir o DBeaver de novo, o que anula
metade do ganho. Duas ações são seguras e valem a pena. **Ambas escrevem no banco:
implemente como `POST`, com confirmação na tela e registro de quem fez.**

### 5.1 `POST sefaz/monitor-dfe/reprocessar` — devolver documentos em erro para a fila

```sql
update poseidon.dpc_dfe_documento
   set status_process = 'P', qtd_tentativa = 0, det_erro = null
 where cod_dfe_documento in (:lista)
   and status_process = 'E'
```

Por que é seguro: **não consome nenhuma chamada à SEFAZ.** O XML já está guardado em
BLOB; `dfe:normalizar` reinterpreta o que está no banco. Esse é exatamente o ganho
central do desenho em dois estágios.

Regras obrigatórias:
- `and status_process = 'E'` no WHERE — nunca reprocessar por id solto, para não
  puxar de volta um documento já concluído.
- Aceitar lista de ids **ou** um filtro (empresa + tipo + período), mas **exigir
  critério**: um `POST` sem filtro não pode virar "reprocessa tudo".
- Limite de segurança no lote (ex.: 5.000 por chamada).
- A normalização só acontece quando o agendador rodar (a cada 10 min). A tela deve
  dizer isso: *"N documentos devolvidos à fila; serão reprocessados no próximo
  ciclo."* **Não** prometa efeito imediato.

### 5.2 `POST sefaz/monitor-dfe/fluxo-status` — pausar / reativar um fluxo

```sql
update poseidon.dpc_dfe_cursor
   set status_sincronismo = :novo_status
 where cod_dfe_cursor = :cod
```

Só permitir as transições `A → P` (pausar) e `P → A` (reativar). **Bloquear qualquer
escrita sobre `B` e `C`** — esses estados são geridos pelo motor e se autocuram;
mexer neles à mão atropela o backoff e pode gerar bloqueio de certificado.

### 5.3 Nunca, em nenhuma hipótese

- **Não** escrever em `nro_ultimo_nsu`. O NSU é um token que a SEFAZ só aceita
  continuar. Valor arbitrário → `cStat 656` → **CNPJ bloqueado por 1 hora**; e
  consultar dentro dessa hora **zera o tempo e reinicia**. Reposicionar cursor é
  operação de CLI (`dfe:ingerir --reposicionar-cursor`), supervisionada, nunca de
  tela — e a própria rejeição 656 devolve o `ultNSU` correto, então quase nunca é
  preciso adivinhar o número.
- **Não** criar botão que dispare `dfe:ingerir` ou qualquer chamada à SEFAZ. O
  consumo é limitado e medido: **~11 chamadas `distNSU` consecutivas já disparam
  656** (medido em produção em 28/08/2026), e `consChNFe` tem cota de 20/hora
  compartilhada com o `download-danfe` da tela de documentos.
- **Não** apagar documento, nota ou item.

---

## 6. Frontend — DPC

### 6.1 Arquivos novos

```
DPC/src/app/sefaz/monitor/routes.js
DPC/src/app/sefaz/monitor/components/Main.vue
DPC/src/app/sefaz/monitor/components/painel/CartaoKpi.vue
DPC/src/app/sefaz/monitor/components/painel/PainelAlertas.vue
DPC/src/app/sefaz/monitor/components/aba/AbaFluxos.vue
DPC/src/app/sefaz/monitor/components/aba/AbaFila.vue
DPC/src/app/sefaz/monitor/components/aba/AbaErros.vue
DPC/src/app/sefaz/monitor/components/aba/AbaExecucoes.vue
DPC/src/app/sefaz/monitor/components/modal/ModalDetalheErro.vue
```

Alterado: `DPC/src/app/sefaz/routes.js` — acrescentar
`import monitor from "./monitor/routes"` e o spread na lista. É só isso; o agregador
já é carregado.

`routes.js` segue o padrão exato de `parametros/routes.js`:
```js
import SefazMonitorDfe from "./components/Main.vue";

export default [
    {
        path: "/sefaz/monitor-dfe",
        name: "SefazMonitorDfe",
        component: SefazMonitorDfe
    }
];
```

### 6.2 Padrões do projeto (não negociáveis)

- HTTP via `import * as dpcAxios from "@/dpcAxios"` — nunca axios direto.
- `Box` e `Navegacao` de `@/components/...`, como em `documentos/nfe/Main.vue`.
- **Loading em toda requisição.** Na listagem, usar a prop `:loading` da
  `vue-good-table` (é a exceção da regra). Em ação pontual (reprocessar, exportar),
  `bus.$emit("open-blackmodal")` / `close-blackmodal`, com o `close` em **todos** os
  caminhos, inclusive o `catch`.
- Vue 2 + Vuex. Nada de Composition API, nada de Vue 3.
- Nome de variável descritivo: `codigo_documento`, não `documento`, quando guarda um
  código. Chave que vem de coluna do banco mantém o nome da coluna.

### 6.3 Layout proposto

```
+-- Monitor DFe - captura de documentos fiscais ------------------------+
|  [empresa v] [tipo v] [ultimas 24h v]      atualizado 14:07  [refresh]|
+-----------------------------------------------------------------------+
|  ! ALERTAS ATIVOS                                                     |
|  - Freio de consumo: 3 de 5 bloqueios nas ultimas 24h                 |
|  - 22 documentos ignorados (tipo sem parser)                          |
+-----------------------------------------------------------------------+
|  +- ERROS -+ +- PARADOS +- FLUXOS -+ +- ATRASO -+ +- CAPTURADO 24h -+ |
|  |    0    | |    22    |  1 / 52  | |  41.203  | |  500 documentos | |
|  | em 'E'  | |  > 24h   |  ativos  | |    NSU   | |   80 notas      | |
|  +---------+ +----------+----------+ +----------+ +-----------------+ |
+-----------------------------------------------------------------------+
|  [ Fluxos ] [ Fila ] [ Erros ] [ Execucoes ] [ Conferencia ]          |
|  -------------------------------------------------------------------  |
|  grid da aba selecionada                                              |
+-----------------------------------------------------------------------+
```

**Semáforo dos KPIs** — a cor é o produto; um número cinza não avisa nada:

| Indicador | verde | amarelo | vermelho |
|---|---|---|---|
| Documentos em `E` | 0 | 1–9 | ≥ 10 |
| Pendentes parados > 24h | 0 | 1–99 | ≥ 100 |
| Bloqueios 24h | 0 | 1 até limite−1 | ≥ limite (**motor parado**) |
| Execuções com erro 24h | 0 | 1–4 | ≥ 5 |
| Fluxo em `P` (pausado) | — | qualquer | — (informativo: pode ser intencional) |

**Auto-refresh:** intervalo de 60s no `painel`, com toggle e `clearInterval` no
`beforeDestroy`. Não colocar auto-refresh nas abas de grid.

### 6.4 A aba Fluxos precisa de um filtro que não é óbvio

Hoje, no ambiente de teste, **51 das 52 linhas de cursor estão fora do estado `A`** —
e quase todas de propósito: os 12 CNPJs atendidos pela Qive estão pausados até a
migração, e a `dsc_ultimo_motivo` desses registros começa com `fluxo criado`. Se a
tela mostrar tudo como problema, o alerta perde o sentido no primeiro dia.

Regra: separar **"pausado deliberadamente"** (motivo `like 'fluxo criado%'`) de
**"parou por falha"**. Default da aba = só os que pararam por falha, com um switch
"mostrar pausados" desligado.

### 6.5 Export

Se houver export para Excel, atenção: o DPC usa **xlsx 0.9.13**, API antiga — **não
existe** `json_to_sheet` / `book_new`, e `writeFile` não baixa no browser. O caminho
que funciona é `aoa_to_sheet` + montar o workbook na mão + `XLSX.write` com
`type: "binary"` + `Blob`. Copie de `documentos/nfe/Main.vue`, que já resolveu isso.

---

## 7. Menu

**Não criar nem alterar menu na mão** (SQL ou HTTP direto). Use o comando
`/criar-menu-dinamico`.

Dois pontos que já quebraram antes:
- O campo `acessar` é o **`name` da rota**, não o path — o sidebar faz
  `router.push({ name: item.acessar })`. Path errado = clique não faz nada, sem erro
  no console. Aqui, `acessar = "SefazMonitorDfe"`.
- O menu é lido do **Postgres, schema `menu`** — não do Oracle.

Posição sugerida: junto das telas SEFAZ existentes (Documentos Fiscais, Documentos
NF-e, Parâmetros).

---

## 8. Limite honesto: os dois logs que esta tela não alcança

| Fonte | Onde | Por que fica fora |
|---|---|---|
| Log do Lumen | `ApiNFE/storage/logs/lumen-YYYY-MM-DD.log` | arquivo no container da ApiNFE; a ApiDPC não tem acesso ao filesystem dela |
| Saída do cron | `/var/log/myjob.log` no container | idem — **e é o único lugar onde aparece falha antes do motor subir** (erro de bootstrap, cron não iniciado, `.env` quebrado) |

Consequência prática: **se o cron não estiver rodando, esta tela mostra tudo verde.**
Nada de errado é gravado no banco quando nada executa.

Mitigação dentro do escopo, e ela importa: um KPI **"última execução há X"** lido de
`max(dta_inicio)` em `DPC_DFE_EXECUCAO`. Sem execução nos últimos 60 minutos
existindo fluxo ativo = **alerta vermelho "motor possivelmente parado"**. É o
indicador que detecta ausência, e ausência é o modo de falha que os outros não pegam.

```sql
select round((sysdate - cast(max(x.dta_inicio) as date)) * 24 * 60) as min_desde_ultima
  from poseidon.dpc_dfe_execucao x
```

Se depois quiserem os arquivos de log na tela, isso exige **endpoint novo na ApiNFE**
— decisão separada, não faça agora.

---

## 9. Erros já pagos — leia antes de codar

| Armadilha | O que acontece |
|---|---|
| **ApiDPC é PHP 7.2**, mas o `php` do PATH é 8.2 | `php -l` aprova `fn()`, `??=`, `?->`, `match()` e a rota **morre em runtime**. Varra a sintaxe na mão. |
| **ApiDPC exige `vendor` instalado com Composer 1** | Composer 2 gera `Undefined index: name` no PackageManifest e a API não sobe. |
| **ApiDPC local precisa do túnel SSH** (`ssh -N tunnel-dpc`) | Sem ele, toda rota autenticada quebra com `SQLSTATE[08006]` na porta 15432. No front parece CORS, mas é preflight 200 + 500 de ~630 kB. |
| **Palavra reservada do Oracle em alias** | `as real`, `as trigger` geram `ORA-00923: FROM keyword not found`. Já custou dois diagnósticos. Prefixe alias com `qtd_` / `dsc_`. |
| **SCSS do DPC compila com node-sass/LibSass** | `min()` / `max()` do CSS quebram o build com "Incompatible units". Valide com o node-sass do projeto em Node 14 — dart-sass passa e esconde o erro. |
| **Bootstrap do DPC é customizado** | altura base de controle é **37px** (font 15px / padding 7px), não 34px. Para barra uniforme, não declare `height`: remova as classes `-sm`. |
| **Subtração crua de NSU dá negativo** | ver o `case` em §4.3. |
| **CLOB no oci8 lê direto** | não use `DBMS_LOB.SUBSTR` no SELECT: trunca em 4000 bytes. |

---

## 10. Critérios de aceite

1. A tela abre e o painel responde em < 3s com o volume atual (~5k documentos).
2. Com `status_process = 'E'` existindo, o KPI fica vermelho e a aba Erros mostra
   `det_erro` legível, com empresa, NSU e tipo.
3. Reprocessar um documento em `E` devolve ele para `P`, e o ciclo seguinte do
   `dfe:normalizar` o processa — **sem nenhuma chamada à SEFAZ**.
4. A aba Fluxos, no default, **não** lista os 12 CNPJs pausados de propósito.
5. `qtd_atraso` nunca aparece negativo; quando o máximo é desconhecido, aparece
   vazio, e não entra na soma do KPI.
6. O KPI de bloqueios mostra `usado / limite` e fica vermelho ao atingir o limite.
7. Parar o cron e recarregar a tela produz o alerta "motor possivelmente parado".
8. Nenhum endpoint escreve em `nro_ultimo_nsu`, e nenhum botão chama a SEFAZ.
9. Filtro por empresa e por tipo funciona em todas as abas.

---

## 11. Estado medido do ambiente de teste (baseline de conferência)

Aferido em **28/08/2026**:

| Medida | Valor |
|---|---|
| Documentos em `E` | 0 |
| Documentos em `I` (ignorado) | 22 — `procEvCTe` 20 + `adnEvento` 2 |
| Execuções com erro em 24h | 0 |
| Bloqueios `CONSUMO_INDEVIDO` em 24h | 3 (limite 5) |
| Notas | 80 |
| Itens de nota | 3.832 |
| Eventos | 945 |
| CT-e | 30 |
| NFS-e | 37 |
| Linhas de cursor | 52, sendo 51 fora de `A` (quase todas pausadas de propósito) |
| Divergências de total (> R$ 0,02) | 0 |

Se a tela mostrar número diferente desses para o mesmo instante, a query está errada
— não o banco.
