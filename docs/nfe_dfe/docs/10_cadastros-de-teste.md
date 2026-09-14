# Os CNPJs onde é possível testar

Nos 27 CNPJs da DPC **não** é possível drenar a SEFAZ enquanto a Qive estiver
ativa: duas aplicações consultando o mesmo CNPJ é causa documentada de `cStat
656`. Eram **dois** os que escapavam disso, e é de onde saiu toda a medição do
motor. Em **09/09/2026 virou três**: a Qive foi removida também da empresa 29.

| | **ALL CARS (900)** | **Empresa 30 — DPC MS** | **Empresa 29 — DPC DF** |
|---|---|---|---|
| CNPJ | `45.694.407/0001-02` | `66.471.517/0030-01` | `66.471.517/0029-78` |
| Raiz | `45694407` — **própria** | `66471517` — **a mesma da matriz** | `66471517` — **a mesma da matriz** |
| Certificado | próprio, exclusivo, válido até 11/03/2027 | **compartilhado** com 1, 3, 8 e 29 | **compartilhado** com 1, 3, 8 e 30 |
| Raio de um `656` | só ela | **o grupo inteiro por 1 hora** | **o grupo inteiro por 1 hora** |
| Qive atende? | não | não (confirmado 18/08/2026) | não (removida em 09/09/2026) |
| Serve para produção? | **não** — cadastro descartável de `tst` | sim, é filial real | sim, é filial real |
| Movimento | pouco (`ultNSU` 87, imóvel) | real: ~847 NF-e + ~375 CT-e/dia | a medir |
| Scripts | **removidos em 09/09/2026** — a ALL CARS saiu do repositório por ser descartável; o certificado dela vive em `itens/`, fora de versionamento. Recuperáveis no histórico do git | [`empresas/30_01`](../scripts/ddl/empresas/30_01_empresa_30_dbeaver.sql) e [`30_99`](../scripts/ddl/empresas/30_99_rollback_empresa_30_dbeaver.sql) | [`empresas/29_01`](../scripts/ddl/empresas/29_01_empresa_29_dbeaver.sql) e [`29_99`](../scripts/ddl/empresas/29_99_rollback_empresa_29_dbeaver.sql) |

O certificado compartilhado é a armadilha das duas filiais reais, e ela deixou
de ser teórica em **09/09/2026**: o fluxo NF-e da empresa 30 tomou `cStat 656`
ao drenar o acervo — 2.350 documentos em duas execuções — e o bloqueio de 1 hora
vale para o **certificado**, não para o CNPJ. Ativar as duas ao mesmo tempo é
disputar a mesma cota.

**O módulo vive só em `tst`, por decisão de 09/09/2026** — produção serve
apenas para o `dfe:conciliar` **ler** a Consinco. As tabelas `dpc_dfe_*`
*existem* em prd desde 25/08/2026, mas estão órfãs e defasadas; ver o
[07_ddl-instalacao.md](07_ddl-instalacao.md).

---

## ALL CARS ASSETS — cadastro descartável

Resolve o problema da Qive por dois motivos independentes: ela **não atende esse
CNPJ**, e a **raiz é outra**, então um `656` ali não pode bloquear o e-CNPJ da
matriz. O teste não tem como prejudicar o grupo — foi justamente por isso que
existiu.

### Ordem

Conectado em `tst`, como `POSEIDON`, cada script inteiro com `Alt+X`.

| # | Script | O que faz |
|---|---|---|
| 1 | `01_ge_empresa_tst.sql` | linha em `consinco.ge_empresa` — **hoje desnecessária** |
| 2 | ⚠️ `02_certificado_tst.sql` | o certificado — **não versionado**, ver "O segredo" abaixo |
| 3 | `03_dfe_empresa_tst.sql` | cadastro em `poseidon.dpc_dfe_empresa` |
| 4 | `04_ge_pessoa_tst.sql` | linha em `consinco.ge_pessoa` — **hoje desnecessária** |
| 5 | `05_preparar_producao_tst.sql` | preparo do ambiente |
| 6 | `06_reverter_consinco_all_cars_tst.sql` | desfaz **só** o que tocou a Consinco |
| 7 | `07_rebuild_indices_mfl_doctofiscal_tst.sql` | rebuild de índices |
| — | `99_rollback_tst.sql` | desfaz **tudo**, inclusive o acervo |

São idempotentes: reexecutar não duplica nem sobrescreve.

### ⚠️ Reversão — dois escopos, e escolher errado apaga a massa de validação

| Script | Escopo | Quando |
|---|---|---|
| `06_reverter_consinco...` | só as duas linhas da **Consinco** (itens 1 e 4) | preserva certificado, cadastro e todo o acervo capturado |
| `99_rollback_tst.sql` | **tudo** | só quando o teste terminar de vez |

O `99` apaga também as **8 NF-e e 15 NFS-e** que são a única massa real de
validação do motor — a NFS-e **não tem outra fonte de teste**, porque a Qive não
atende a ALL CARS.

### Por que os itens 1 e 4 ficaram desnecessários

Nunca foram dado de negócio. Existiam para contornar duas dependências que o
motor tinha da Consinco — `GeEmpresa::showAll` (INNER JOIN com `ge_cidade`, daí o
`SEQCIDADE`) e `consinco.montacpfcnpj` (que consulta `ge_pessoa` e devolve NULL
em silêncio via `NO_DATA_FOUND`). O commit `39b172d` desacoplou o motor: a
identidade fiscal passou a vir de `poseidon.dpc_dfe_empresa`. Sumiu a
dependência, sumiram os contornos.

> Verificado no código, não presumido: o motor lê o PFX por
> `buscaConteudoCertificado`, que **não** faz join com `ge_empresa`. O único
> caminho que faz esse join é `DpcContaCertifDigitalEmp::showAll`, usado fora do
> módulo DFe. O `06` traz a prova operacional no fim: um `--dry-run` que lê o
> certificado sem consumir cota.

### Não pule a conferência do script 1

`DIGCGC` é `NUMBER(2)` e o dígito é `02`. Se `poseidon.montacpfcnpj` não
completar com zero à esquerda, o CNPJ sai com **13 dígitos**. O `select` no fim
do script mostra o valor montado: tem de dar `45694407000102`, tamanho `14`. Se
der 13, **pare** — não vale consultar a SEFAZ com CNPJ malformado.

### 🔐 O segredo: o script 02 existe no disco, mas nunca no git

`02_certificado_tst.sql` contém **a senha do certificado e o PFX inteiro em
base64** — 12.180 caracteres, gravados em sete chamadas de `dbms_lob` porque
passam do limite de literal do SQL.

Ele fica na pasta do cadastro, porque **o cadastro não roda sem ele**, e está no
`.gitignore` do repositório `.claude`. É o mesmo tratamento de um `.env`: existe
no disco de quem tem o workspace, e o git se recusa a vê-lo. Conferido de três
formas: `git check-ignore`, `git status --untracked-files=all` e um `git add -A`
em modo simulação.

O conteúdo do certificado tem duas outras cópias, então perder este arquivo não
perde o certificado:

| Cópia | Onde |
|---|---|
| o `.pfx` original | `itens/ALL CARS ASSETS LTDA45694407000102.pfx`, fora de repositório. Hash conferido byte a byte contra o base64 do script |
| a linha já gravada | `poseidon.dpc_conta_certif_digital_emp`, empresa 900 |

### Limitações

**As linhas desaparecem no próximo refresh do clone.** Homologação é clone de
produção e `consinco.ge_empresa` vem de lá. Quando acontecer, é só rodar os
scripts de novo — mas a captura em `dpc_dfe_*` também vai embora, porque aquelas
tabelas não existem em produção.

**Não serve para produção.** Se a ALL CARS tiver que rodar de verdade, aí entra a
decisão de cadastro próprio em `dpc_dfe_empresa` ou cadastro no ERP.

**Não resolve o bloqueio de negócio.** As 27 empresas DPC continuam dependendo do
corte com a Qive — ver [01_decisao-qive.md](01_decisao-qive.md).

**Manifestação desligada** (`status_manifestar = 'N'`). É PJ distinta, e
manifestar é ato fiscal com protocolo definitivo, sem desfazer.

---

## Empresa 30 — DPC Mato Grosso do Sul

O ERP já estava pronto: `ge_empresa` existe, ativa, `SEQCIDADE 40207`, IE
`500041350`, MS. Faltavam **certificado** e **cursor** — era uma das 15 empresas
"cegas".

| # | Script | O que faz |
|---|---|---|
| 1 | `01_certificado_emp30.sql` | copia o certificado da empresa 1 (`INSERT ... SELECT`) |
| 2 | `02_dfe_empresa_emp30.sql` | cria a linha do cursor, **pausada** |
| — | `99_rollback_emp30.sql` | desfaz |

O certificado é o **e-CNPJ A1 da matriz**, que vale para toda filial de raiz
`66471517`. Não precisa de arquivo nem de senha: copiar a linha da empresa 1 leva
o base64 e a senha já convertida, idênticos ao que hoje funciona. **É por isso
que este script não carrega segredo** e pode ficar no repositório, ao contrário
do `02` da ALL CARS.

### Por que nasce pausada

O consumo da SEFAZ é contado por **certificado**, não por CNPJ. Ativar a empresa
30 com a Qive no ar não arrisca só a empresa 30 — arrisca as empresas 1, 3 e 8,
que hoje funcionam. E bloqueios consecutivos podem escalar para bloqueio
**permanente**.

Foi por ter certificado próprio que a ALL CARS pôde ser testada sem risco. Aqui
essa proteção não existe.

### Resultado da ativação — 18/08/2026

A Qive não atende este CNPJ, então a empresa foi ativada.

```
php artisan dfe:ingerir --empresa=30 --max-consultas=1 --debug
  NSU 0..4155 | cStat 138 | 50 docs (novos 50, repetidos 0)
```

Envelope: `tpAmb 1`, `cStat 138`, `ultNSU 4155`, **`maxNSU 16525`** — backlog de
12.370 NSU. Normalização: `Lidos: 50 | Eventos: 50 (orfaos 50) | Erros: 0`.

> ## 🔴 RETRATAÇÃO — a leitura que este teste produziu estava errada
>
> Na época, o `138` limpo usando o e-CNPJ da matriz foi lido como evidência de
> que **o bloqueio é contabilizado por CNPJ, e não por certificado** — e a
> conclusão registrada foi que "a migração não precisa ser corte seco; dá para
> migrar CNPJ por CNPJ".
>
> **Isso não se sustentou.** A ressalva escrita na hora — "é *uma* chamada, e
> pode ser que a Qive estivesse inativa naquele minuto" — era o ponto certo.
> Medições de 01/09/2026 estabeleceram o contrário:
>
> - a empresa 8 tomou `656` na **primeira** consulta dela, minutos depois do
>   bloqueio da matriz — mesmo certificado;
> - a empresa 900 passou 7 minutos depois de uma rajada de 11 chamadas da
>   empresa 30 — **certificados diferentes**, zero interferência.
>
> **Revisto em 12/09/2026:** a cota é do **CNPJ de 14 dígitos** (NT 2014.002
> item 3.11.4.1), e não do certificado — a observação acima é compatível com as
> duas leituras e não discrimina. O corte com a Qive continua sendo seco, mas
> pelo motivo certo: dois consumidores na mesma sequência de NSU do mesmo CNPJ.
> Consolidado atual: [02_conhecimento-sefaz.md §5](02_conhecimento-sefaz.md).

### O que este CNPJ fechou de verdade

1. **Volume real medido** — ~847 NF-e e ~375 CT-e por dia. É o único CNPJ onde
   isso foi possível, e é a base do teste de rajada.
2. **Variedade real de fornecedor da DPC**, que nenhum ambiente de teste tinha.

### Evento órfão: um padrão que a mensagem do monitor descreve mal

Os 50 primeiros eventos têm chave começando em `50 2605 66471517003001` — UF 50
(MS) e o CNPJ **da própria empresa 30**. São eventos de notas que ela **emitiu**,
que vivem no ERP e não aqui. Mesmo padrão dos 50 eventos da empresa 1.

Isso torna a mensagem do `dfe:monitorar` — "Eventos aguardando a nota chegar: 100
(serao religados automaticamente)" — enganosa: **nenhum desses 100 vai religar**.

---

Registro do que foi tocado na Consinco de teste:
[11_registro-alteracoes-tst.md](11_registro-alteracoes-tst.md) ·
catálogo: [09_catalogo-scripts.md](09_catalogo-scripts.md) ·
voltar ao [índice](readme.md)
