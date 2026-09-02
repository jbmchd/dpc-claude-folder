# Catálogo de scripts do módulo DFe

> Onde cada script vive, o que faz e se já rodou. Desde 02/09/2026 **todos os
> scripts do módulo moram no hub**, e são todos `.sql` de DBeaver.

## 1. Tudo mora no hub

```
nfe_dfe/scripts/
├── 01_estrutura_dbeaver.sql       base nova, nesta ordem:
├── 02_carga_inicial_dbeaver.sql     01 → 02 → 03 → 04
├── 03_validacao_dbeaver.sql
├── 04_parametros_dbeaver.sql      ← os DOIS caminhos passam por ele
├── 99_rollback_dbeaver.sql          destrutivo
└── alteracoes/
    ├── atualizacao_v7_a_v10_dbeaver.sql   base ja instalada, e depois o 04
    ├── levantamento-nfse-municipios.sql
    ├── empresa-30-ms/                     cadastro do CNPJ de MS
    └── teste-all-cars/                    cadastro descartavel de teste
```

**Só `.sql` para rodar no DBeaver.** Nenhum `README` dentro das pastas de
script: a explicação de cada grupo está em documento próprio do hub, e este
catálogo diz qual.

A DDL saiu do repositório da ApiNFE em 02/09/2026. Isso tem uma consequência que
precisa ficar registrada: **um deploy da ApiNFE não carrega mais o próprio
schema** — quem instala em ambiente novo tem de vir buscar os scripts aqui. O
`README.md` da ApiNFE aponta para cá.

### A regra que impede a divergência voltar

**Toda alteração em `alteracoes/` está também no `01_estrutura` consolidado**, e
as duas definições saem do **mesmo gerador**.

Não é preciosismo: foi exatamente a divergência entre o `install_dbeaver.sql` e
os cinco alters (`v2`–`v6`) que tornou aqueles scripts inservíveis para
produção — o install continuava criando objetos que um alter havia removido, e
mantinha uma UK que outro havia substituído. Essa UK, se recriada, transforma a
proteção contra duplicidade em **perda de documento**.

### E a regra do CRLF

Os `.sql` são **CRLF por `.gitattributes`** (`workspace/.claude/.gitattributes`,
criado junto com a mudança). Em LF o divisor de statements do DBeaver corta o
bloco PL/SQL no `end if;` e devolve `PLS-00103`. Aconteceu com o `v10`, e o
instalador `01_estrutura` tinha o mesmo defeito sem ninguém ter notado.

## 2. DDL — instalacao e atualizacao

Como rodar, o que conferir antes, o que a instalação **não** liga e o alerta de
ordem do `v11`: **[07_ddl-instalacao.md](07_ddl-instalacao.md)**.

| Pasta | Arquivos | Para que |
|---|---|---|
| raiz de `scripts/` | `01_estrutura` · `02_carga_inicial` · `03_validacao` · **`04_parametros`** · `99_rollback` | base nova: `01` → `02` → `03` → `04` |
| `scripts/alteracoes/` | **um só**: `atualizacao_v7_a_v10_dbeaver.sql` | base já instalada, anterior ao v7 — e depois o `04_parametros` |

Os quatro scripts de estrutura `v7`–`v10` foram unificados em 02/09/2026 por
concatenação verbatim (559 linhas executáveis, conferidas linha a linha). O
antigo `v11` virou o `04_parametros` da raiz. Cada original segue no histórico do
git da ApiNFE.

⚠️ **O `04` é o único script que os DOIS caminhos rodam**, e a ordem dele
importa: **antes do deploy do código**. Ele carrega os 4 parâmetros em
`DPC_PARAMETRO` — tabela compartilhada do ecossistema, que por isso não vem no
`01`. Sem aquelas linhas o freio de consumo indevido cai para o default 5, fica
abaixo do ruído normal, e o motor se recusa a consultar **em silêncio**.

## 3. Scripts pontuais

📁 `scripts/`

| Pasta | O que é | Explicação |
|---|---|---|
| `empresa-30-ms/` | cadastro da **empresa 30** (DPC MS, `66.471.517/0030-01`) — um dos dois CNPJs livres da Qive, e onde o volume real foi medido | [10_cadastros-de-teste.md](10_cadastros-de-teste.md) |
| `teste-all-cars/` | cadastro **descartável** de ALL CARS (`45.694.407/0001-02`, empresa 900) — o outro CNPJ livre | [10_cadastros-de-teste.md](10_cadastros-de-teste.md) |
| `levantamento-nfse-municipios.sql` | cobertura de NFS-e por município | — |

Os dois cadastros são **somente `tst`**. Cada pasta tem o seu `99_rollback_*`.

⚠️ **Dois cuidados que valem ler antes de rodar qualquer coisa em
`teste-all-cars/`:**

1. O `02_certificado_tst.sql` carrega **o PFX inteiro em base64 e a senha**. Ele
   fica na pasta, porque o cadastro não roda sem ele, mas está no `.gitignore`
   do repositório `.claude` — existe no disco e **nunca** e versionado, do mesmo
   jeito que um `.env`. Conferido: `git add -A` não o pega.
2. `06_reverter_consinco...` e `99_rollback_tst` têm escopos **muito** diferentes.
   O `99` apaga as 8 NF-e e 15 NFS-e que são a única massa real de validação do
   motor — e a NFS-e não tem outra fonte.

O que foi tocado na Consinco de teste, com o desfazer de cada item:
[11_registro-alteracoes-tst.md](11_registro-alteracoes-tst.md).

## 4. O que foi apagado, e onde recuperar

A pasta `historico/` foi removida em 02/09/2026 — nada nela descrevia o sistema
atual. O que era:

| Item | Onde está agora |
|---|---|
| `plano-estrutural-v2.md` — o plano de desacoplar do Consinco e criar cursor por tipo | implementado no `39b172d`; o desenho vigente está em [03_conhecimento-motor.md](03_conhecimento-motor.md) |
| `ddl-por-objeto-superada/` — a primeira DDL, um arquivo por objeto | substituída pelo `scripts/01_estrutura_dbeaver.sql` consolidado |

Recuperação, se algum dia for preciso:

| O que | De onde |
|---|---|
| `install_dbeaver.sql`, `rollback_dbeaver.sql`, `validacao_dbeaver.sql` antigos | git da **ApiNFE**, commit `0646efd` |
| `v7` a `v11` como arquivos separados | git da ApiNFE: `1bdc4a7`, `ede36cc`, `77771bc`, `3c20e65` |
| os arquivos por objeto (`dpc_*`, `dpcs_*`, `dpct_*`, `dpci_*`) | **não há.** Nunca estiveram em repositório nenhum |

### ⚠️ Por que a DDL antiga era perigosa, e não só velha

Ela **divergiu** do sistema real: o `install` continuava criando objetos que um
`alter` posterior havia removido, e mantinha uma UK que outro havia substituído.
Essa UK, se recriada, transforma a **proteção contra duplicidade** em **perda de
documento** — o upsert por `(cod_dfe_cursor, nro_nsu)` deixa de valer.

Foi essa divergência que inutilizou os alters `v2`–`v6` para produção, e é por
isso que hoje as duas definições saem do **mesmo gerador**.

## 5. O que não é versionado, nunca

| Item | Onde está | Tratamento |
|---|---|---|
| `scripts/teste-all-cars/02_certificado_tst.sql` | **no hub**, junto do cadastro | no `.gitignore`: fica no disco, fora do git. Carrega o PFX em base64 e a senha |
| `ALL CARS ...45694407000102.pfx` | `itens/` | fora de qualquer repositório. É a origem do base64 do script acima — hash conferido, byte a byte |
| `DPC DISTRIBUIDOR ...66471517000177.pfx` | `itens/` | idem, e **nenhum script depende dele**: o cadastro da empresa 30 copia a linha do certificado dentro do banco |

O `.gitignore` do `.claude` também barra `*.pfx`, `*.p12`, `*.pem` e `*.key`, para
o caso de alguem copiar um certificado para dentro do hub sem pensar.

O motor **não** usa esses arquivos: ele lê o certificado de
`poseidon.dpc_conta_certif_digital_emp`, com a senha descriptografada pelo
`CertificadoDigitalRepository`. Os `.pfx` no disco são cópias de investigação.

---

Voltar ao [índice](readme.md)
