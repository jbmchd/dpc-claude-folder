# Catálogo de scripts do módulo DFe

> Onde cada script vive, o que faz e se já rodou. Todos os scripts do módulo
> moram no hub, e são todos `.sql` de DBeaver.
>
> **Atualizado em 09/09/2026**, quando os dois caminhos de instalação viraram um
> só e a pasta foi reorganizada em blocos.

## 1. Um caminho só, em três blocos

```
nfe_dfe/scripts/
├── levantamento-nfse-municipios.sql     diagnostico, nao instalacao
└── ddl/                                 o UNICO caminho de instalacao
    ├── 01_01_estrutura                  ┐
    ├── 01_02_estabelecimentos           │ BLOCO 01 - MOTOR
    ├── 01_03_parametros                 │ as 13 tabelas de captura
    ├── 01_04_validacao                  │
    ├── 01_99_rollback_motor             ┘
    ├── empresas/                        ┐ UM PAR POR EMPRESA trazida depois
    │   ├── 29_01_empresa_29             │ da carga geral. O numero do arquivo
    │   ├── 29_99_rollback_empresa_29    │ E o numero da empresa.
    │   ├── 30_01_empresa_30             │
    │   └── 30_99_rollback_empresa_30    ┘
    ├── 03_01_parametrizacao_telas       ┐ BLOCO 03 - permissao de acesso aos
    └── 03_99_rollback_telas             ┘ paineis e limiar de alerta
```

O primeiro número é o **bloco**, o segundo é a ordem **dentro** dele. O `_99` de
cada bloco é o rollback daquele bloco — quem desfaz mora ao lado de quem faz.

| | |
|---|---|
| **Instalar** | `01_01` → `01_02` → `01_03` → `01_04`, depois `03_01` e os pares de `empresas/` |
| **Desfazer** | os `_99` de `empresas/` → `03_99` → `01_99`, do mais específico para o motor |

**Só `.sql` para rodar no DBeaver.** Nenhum `README` dentro das pastas de
script: a explicação de cada grupo está em documento próprio do hub, e este
catálogo diz qual.

A DDL saiu do repositório da ApiNFE em 02/09/2026. Isso tem uma consequência que
precisa ficar registrada: **um deploy da ApiNFE não carrega mais o próprio
schema** — quem instala em ambiente novo tem de vir buscar os scripts aqui. O
`README.md` da ApiNFE aponta para cá.

### Por que os blocos são estes

O módulo tem duas naturezas, e elas não se misturam:

```
dfe  (modulo)
 |-- MOTOR   as 13 tabelas dpc_dfe_*. Captura documento na SEFAZ e no ADN.
 |           NAO tem conceito de usuario: e CLI e banco, sem sessao, sem login.
 |
 '-- TELAS   as 3 tabelas dpc_dfe_usuario_* e dpc_dfe_painel_alerta. Permissao
             de acesso aos paineis e o limiar que eles usam para pintar a linha.
```

Por isso o motor **não** leva rótulo no nome das tabelas e o bloco de telas
leva: o motor é o assunto próprio do módulo, e o que precisa de rótulo é o bloco
anexo. Qualquer tabela com `usuario` no nome, dentro do módulo, é
necessariamente de tela.

A **empresa 30** ganhou bloco próprio por um motivo material, e não por ser
especial: é o único estabelecimento que precisa de algo **fora** das tabelas do
módulo — o certificado, que mora em `poseidon.dpc_conta_certif_digital_emp`, do
ERP. É também por isso que ela tem rollback próprio: o `01_99` derruba as 13
tabelas `dpc_dfe_*` e **não alcança** o certificado.

### A regra que impede a divergência voltar

Não existe mais script de "alteração". O **`01_01_estrutura` é convergente**: a
seção 3 dele confere as 273 colunas uma a uma e acrescenta a que faltar, então o
mesmo arquivo serve a base vazia, parcial ou completa.

Isso substitui a regra antiga — "toda alteração está também no instalador
consolidado" —, que dependia de disciplina humana e falhou: em 09/09/2026 a base
de teste voltou 13 dias, as 13 tabelas estavam de pé e 11 colunas de
`DPC_DFE_NOTA` não, e recuperar exigiu escolher a dedo três scripts de alteração
na ordem certa. Um deles morria no meio, num *forward reference* que ninguém
tinha percebido.

Antes disso, foi a divergência entre o `install_dbeaver.sql` e os cinco alters
(`v2`–`v6`) que tornou aqueles scripts inservíveis para produção — o install
continuava criando objetos que um alter havia removido, e mantinha uma UK que
outro havia substituído. Essa UK, se recriada, transforma a proteção contra
duplicidade em **perda de documento**.

### E a regra do CRLF

Os `.sql` são **CRLF por `.gitattributes`** (`workspace/.claude/.gitattributes`).
Em LF o divisor de statements do DBeaver corta o bloco PL/SQL no `end if;` e
devolve `PLS-00103`. Aconteceu com o `v10`, e o instalador consolidado tinha o
mesmo defeito sem ninguém ter notado.

## 2. O bloco 01 — motor

Como rodar, o que conferir antes e o que a instalação **não** liga:
**[07_ddl-instalacao.md](07_ddl-instalacao.md)**.

| # | Arquivo | O que faz | Destrutivo |
|---|---|---|---|
| 1 | `01_01_estrutura` | 13 tabelas, 13 sequences, 13 triggers, 54 constraints, 24 índices, 286 comentários — e a **seção 3**, que reconcilia as 273 colunas | não |
| 2 | `01_02_estabelecimentos` | 12 CNPJs e 48 fluxos, **todos pausados** | sim (DML) |
| 3 | `01_03_parametros` | os **5** parâmetros em `DPC_PARAMETRO`. **Antes do deploy do código** | sim (DML) |
| 4 | `01_04_validacao` | confere motor e telas; a seção 5 faz insert + `rollback` | praticamente não |
| — | `01_99_rollback_motor` | desfaz as 13 tabelas, as 13 sequences e os 5 parâmetros | sim |

⚠️ **O `01_03` tem ordem obrigatória: antes do deploy do código.** Ele carrega os
5 parâmetros em `DPC_PARAMETRO` — tabela compartilhada do ecossistema, que por
isso não vem no `01_01`. Dois desses defaults **mudam comportamento em
silêncio** se a linha faltar: o freio de consumo indevido cai para 5, fica
abaixo do ruído normal do sistema e o motor se recusa a consultar; e o
`dfe_conexao_erp` volta para "a conexão corrente", o que em homologação faz
**toda** nota parecer não lançada.

### Sem contagem global escrita à mão

A seção 1 do `01_04` conta **coluna por tabela** — 16 números, um por tabela — e
a seção 2 checa **invariantes** que não citam quantidade nenhuma: coluna sem
comentário, tabela sem comentário, tabela sem PK, tabela sem PK automática,
sequence sem tabela, objeto inválido. Todos devem dar zero.

O motivo é concreto: até 09/09/2026 a conferência do instalador comparava contra
oito números globais, e eles estavam **defasados** — esperavam 12 tabelas e 242
colunas comentadas, de antes das colunas de etapa no ERP. Quem instalasse numa
base limpa leria "esperado 12, achado 13" e concluiria que a instalação falhou.
Número global escrito à mão envelhece sozinho, e em silêncio.

## 3. O bloco 02 — empresa 30

Cadastro da **empresa 30** (DPC MS, `66.471.517/0030-01`): identidade, os 4
fluxos pausados e a cópia do certificado da empresa 1. É um dos dois CNPJs
livres da Qive, e onde o volume real foi medido —
[10_cadastros-de-teste.md](10_cadastros-de-teste.md).

O `30_99_rollback_empresa_30` apaga o que o `30_01` criou, filtrando por
`created_by = 'CADASTRO DFE'`. Esse filtro só passou a funcionar em 09/09/2026:
antes a empresa 30 nascia na carga inicial com `'CARGA INICIAL'` e o rollback
procurava `'CADASTRO DFE'` — não apagava nada, e a conferência acusava sem
explicar por quê. Com a empresa nascendo em **um** lugar só, o filtro sempre
casa.

## 4. O bloco 03 — telas

As três tabelas que os painéis usam:

| Tabela | O que guarda |
|---|---|
| `dpc_dfe_usuario_empresa` | quais filiais cada usuário vê |
| `dpc_dfe_usuario_aba` | quais categorias cada usuário vê |
| `dpc_dfe_painel_alerta` | o limiar de dias por filial, e as cores |

Renomeadas de `dpc_sefaz_*` em 09/09/2026, quando o módulo passou a ter prefixo
único. O `03_01` é convergente do mesmo jeito que o `01_01`: renomeia se achar o
nome antigo, cria se não existir, ajusta os nomes de constraint e de índice, e
escreve os 23 comentários.

⚠️ **O `03_99` apaga permissão, e o que se perde ali não volta rodando o
`03_01`.** Aquele arquivo recria a estrutura; quem preenche as linhas é uma
pessoa, na tela *Sefaz → Parâmetros*, uma por uma. E a perda é silenciosa do
outro lado: usuário sem linha em `dpc_dfe_usuario_empresa` não vê nada nas
telas e **não recebe erro** — o repositório curto-circuita e devolve HTTP 200
com lista vazia, indistinguível de "não há nota no período". Por isso a seção 0
do `03_99` gera o script de volta: rode, copie e guarde antes de seguir.

Essas três nasceram no card #3235, pelo lado do front, e ficaram **fora de
qualquer script** até 09/09/2026 — foram criadas à mão em 25/08/2026, e nenhum
`.sql` do workspace as criava. Sobreviveram ao refresh da base de teste por
sorte: o snapshot restaurado era de 27/08, dois dias depois de elas existirem.

## 5. Scripts pontuais

| Arquivo | O que é | Explicação |
|---|---|---|
| `levantamento-nfse-municipios.sql` | cobertura de NFS-e por município, para decidir se vale construir a captura pelo ADN | roda em **prd**, só `SELECT`. Tem três marcadores `<<< AJUSTAR` que exigem edição humana — não é script de instalação |

## 6. O que foi apagado, e onde recuperar

### Em 09/09/2026, quando os dois caminhos viraram um

| Item | Por que saiu | Onde recuperar |
|---|---|---|
| `01_estrutura` · `02_carga_inicial` · `03_validacao` · `04_parametros` · `99_rollback` da raiz | absorvidos pelo `ddl/`, com os defeitos corrigidos | git do `.claude`, branch `main` |
| `alteracoes/atualizacao_v7_a_v10` · `v12` · `v13` | os objetos dos três estão no `01_01`, e o raciocínio deles foi para os comentários de coluna | idem |
| `alteracoes/empresa-30-ms/` | fundido no par `empresas/30_01` e `30_99` | idem |
| `alteracoes/teste-all-cars/` (7 arquivos) | a ALL CARS é cadastro **descartável**, e ficou deliberadamente fora do `ddl/` | idem |
| `alteracoes/teste-all-cars/02_certificado_tst.sql` | **movido**, não apagado: foi para `itens/02_certificado_all_cars_tst.sql`, ao lado do `.pfx` de onde ele sai | está no disco; **não** tem cópia no git, e é o único lugar onde a senha daquele certificado existe |

Três defeitos que a reorganização corrigiu, todos verificados contra o banco:

1. **`ALL_TABLESPACES` não existe no Oracle** — a view era usada duas vezes no
   primeiro statement do instalador, que morria com `ORA-00942`. A família é
   `USER_`/`DBA_` apenas.
2. **A conferência do instalador estava defasada** (12 tabelas, 242 colunas).
3. **O rollback não tocava em `DPC_PARAMETRO`** — "apagar e recriar" deixava as
   5 linhas vivas, e o script de parâmetros nunca as corrige, porque é
   `where not exists` de propósito.

E um índice que faltava: a FK `DPC_DFE_DOCUMENTO_FK1 (cod_dfe_empresa)` não era
a primeira coluna de nenhum índice. FK sem índice faz **lock de tabela no
filho** quando se apaga linha do pai — e esse filho é o que guarda os BLOB.
Achado pelo assert "FK sem índice" da própria validação, que acusava 1 numa base
tida por completa.

### Em 02/09/2026

A pasta `historico/` foi removida — nada nela descrevia o sistema atual:

| Item | Onde está agora |
|---|---|
| `plano-estrutural-v2.md` — o plano de desacoplar do Consinco e criar cursor por tipo | implementado no `39b172d`; o desenho vigente está em [03_conhecimento-motor.md](03_conhecimento-motor.md) |
| `ddl-por-objeto-superada/` — a primeira DDL, um arquivo por objeto | substituída pelo instalador consolidado, hoje `ddl/01_01_estrutura` |

| O que | De onde recuperar |
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
isso que hoje existe **um arquivo só**, convergente, em vez de um instalador
mais uma pilha de alterações.

## 7. O que não é versionado, nunca

| Item | Onde está | Tratamento |
|---|---|---|
| `02_certificado_all_cars_tst.sql` | `itens/` | carrega o PFX em base64 e a senha. Fora do git |
| `ALL CARS ...45694407000102.pfx` | `itens/` | é a origem do base64 do script acima — hash conferido, byte a byte |
| `DPC DISTRIBUIDOR ...66471517000177.pfx` | `itens/` | **nenhum script depende dele**: o cadastro da empresa 30 copia a linha do certificado dentro do banco |

Desde 09/09/2026 a regra do `.gitignore` é a **pasta inteira** (`docs/nfe_dfe/itens/`),
e não o nome de cada arquivo. O motivo: a regra por nome exato foi burlada
**duas vezes**, sempre em silêncio — primeiro quando a pasta foi reorganizada e o
caminho ancorado deixou de casar, depois quando o arquivo ganhou `all_cars` no
nome ao ser movido. Nome exato protege um arquivo; a pasta protege o propósito.

O `.gitignore` do `.claude` também barra `*.pfx`, `*.p12`, `*.pem` e `*.key`,
para o caso de alguém copiar um certificado para dentro do hub sem pensar. Para
conferir que nada com segredo escapou, antes de commitar:

```sh
git add -An . | sed "s/^add '//; s/'$//" \
  | while read f; do grep -lE "[A-Za-z0-9+/]{200,}" "$f"; done
```

A saída tem que ser vazia.

O motor **não** usa esses arquivos: ele lê o certificado de
`poseidon.dpc_conta_certif_digital_emp`, com a senha descriptografada pelo
`CertificadoDigitalRepository`. Os `.pfx` no disco são cópias de investigação.

---

Voltar ao [índice](readme.md)
