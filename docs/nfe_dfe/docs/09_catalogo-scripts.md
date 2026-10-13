# Catálogo de scripts do módulo DFe

> Onde cada script vive, o que faz e se já rodou. Todos os scripts do módulo moram no hub, e são todos `.sql` de DBeaver.
>
> **Reescrito em 13/10/2026**: os 17 arquivos de `ddl/` (14 blocos acumulados), os 13 rollbacks por bloco, os pares de rollback por empresa e os 13 ajustes únicos viraram **16 arquivos**. O instalador convergente é o mesmo princípio de 09/09/2026, agora para tudo.

---

## 1. O layout

```
nfe_dfe/scripts/
├── ddl/                                  o UNICO caminho de instalacao (convergente, CRLF)
│   ├── 01_estrutura_motor_dbeaver.sql    17 tabelas do motor
│   ├── 02_estrutura_telas_dbeaver.sql    6 tabelas de tela
│   ├── 03_parametros_dbeaver.sql         os 11 dfe_* de DPC_PARAMETRO
│   ├── 04_validacao_dbeaver.sql          somente leitura (secao 5: insert + rollback)
│   └── rollback/                         UM por DDL
│       ├── 01_99_rollback_estrutura_motor_dbeaver.sql
│       ├── 02_99_rollback_estrutura_telas_dbeaver.sql
│       └── 03_99_rollback_parametros_dbeaver.sql
├── homolog/                              dado e valor que so existem na base de TESTE
│   ├── 01_estabelecimentos_dbeaver.sql   12 CNPJs e 48 fluxos, pausados
│   ├── 02_parametros_homolog_dbeaver.sql dfe_conexao_erp e dfe_replicacao_prd
│   └── empresas/ 20_01, 29_01, 30_01     identidade, fluxos pausados e copia do certificado
├── operacao/                             o que se repete: pausar e retomar empresas
│   ├── pausa_empresas_dbeaver.sql
│   └── retomada_empresas_dbeaver.sql
├── producao/LEIA_instalar_em_producao.md ordem num ambiente novo + registro de 13/10/2026
└── levantamento-nfse-municipios.sql      diagnostico (roda em prd, so SELECT, tem 3 marcadores <<< AJUSTAR)
```

**Só `.sql` para rodar no DBeaver.** Nenhum `README` dentro das pastas de script: a explicação de cada grupo está em documento próprio do hub, e este catálogo diz qual. A DDL saiu do repositório da ApiNFE em 02/09/2026, então **um deploy da ApiNFE não carrega mais o próprio schema**: quem instala em ambiente novo vem buscar os scripts aqui.

### A regra que impede a divergência voltar

Não existe script de "alteração". Os instaladores `01` e `02` são **convergentes**: conferem as colunas uma a uma, acrescentam a que faltar e redefinem CHECK e UNIQUE cuja definição mudou. Coluna ou tabela nova entra **no próprio instalador** (no `create table` e na lista de colunas), e a contagem por tabela do `04_validacao` muda na mesma edição.

Isso substitui a regra antiga — "toda alteração está também no instalador consolidado" —, que dependia de disciplina humana e falhou: em 09/09/2026 a base de teste voltou 13 dias, as 13 tabelas estavam de pé e 11 colunas de `DPC_DFE_NOTA` não. Antes, foi a divergência entre `install_dbeaver.sql` e os alters `v2`–`v6` que os tornou inservíveis para produção: o install continuava criando objetos que um alter havia removido e mantinha uma UK que outro havia substituído. Essa UK, se recriada, transforma a proteção contra duplicidade em **perda de documento**.

### E a regra do CRLF

Os `.sql` são **CRLF por `.gitattributes`** (`workspace/.claude/.gitattributes`). Em LF o divisor de statements do DBeaver corta o bloco PL/SQL no `end if;` e devolve `PLS-00103`. E **linha em branco dentro de bloco PL/SQL** também corta (o DBeaver a trata como fim de statement).

---

## 2. `ddl/` — os instaladores

Como rodar, o que conferir antes e o que a instalação **não** liga: **[07_ddl-instalacao.md](07_ddl-instalacao.md)**.

| Arquivo | Tabelas | Absorveu |
|---|---|---|
| `01_estrutura_motor` | `empresa`, `cursor`, `emitente`, `execucao`, `documento`, `nota`, `nota_item`, `nota_total`, `nota_transporte`, `nota_cobranca`, `cte`, `cte_nfe`, `cte_evento`, `nfse`, `evento`, `manif_pedido`, `manifestacao` | o antigo `01_01` e os blocos `04_01`, `07_01`, `08_01`, `08_02`, `09_01`, `12_01`, `13_01` |
| `02_estrutura_telas` | `usuario_empresa`, `usuario_aba` (CHECK com `PROPRIAS`), `usuario_permissao`, `usuario_coluna` (CHECK com as variantes `_REL`), `usuario_modelo`, `painel_alerta` | `03_01` e os blocos `04_02`, `06_01`, `10_01`, `11_01`, `14_01` |
| `03_parametros` | — (`DPC_PARAMETRO`) | `01_03`, os parâmetros do `04_01`, `ajustes_unicos/2026-10-07_parametros_fila_manifestacao` e `producao/P1_02` |
| `04_validacao` | — | `01_04`, adaptado: a seção de dados do motor (CNPJs de teste) saiu |

⚠️ **O `03_parametros` tem ordem obrigatória: antes do deploy do código.** `DPC_PARAMETRO` é tabela compartilhada do ecossistema, por isso não vem nos instaladores de estrutura. Dois defaults **mudam comportamento em silêncio** se a linha faltar: o freio de consumo indevido cai para 5, fica abaixo do ruído normal do sistema e o motor se recusa a consultar; e `dfe_conexao_erp` (só na homolog) volta para "a conexão corrente", o que em homologação faz **toda** nota parecer não lançada.

### Sem contagem global escrita à mão

A seção 1 do `04_validacao` conta **coluna por tabela** (23 números, um por tabela) e a seção 2 checa **invariantes** que não citam quantidade: coluna sem comentário, tabela sem comentário, tabela sem PK, tabela sem PK automática (fora as 1:1 cuja PK é a FK da nota), sequence sem tabela, objeto inválido. Todos devem dar zero. Número global escrito à mão envelhece sozinho, e em silêncio: até 09/09/2026 a conferência esperava 12 tabelas e 242 colunas comentadas, de antes das colunas de etapa no ERP.

### Os rollbacks

Um para cada DDL, cada um com foto do que será perdido, trava de instância e conferência no fim:

| Rollback | Faz | Atenção |
|---|---|---|
| `01_99_rollback_estrutura_motor` | derruba as 17 tabelas e as 13 sequences | **apaga todo documento capturado**; a posição de leitura (`nro_ultimo_nsu`) só existe aqui. Para só parar a captura, use `operacao/pausa_empresas` |
| `02_99_rollback_estrutura_telas` | derruba as 6 tabelas de tela | apaga permissão: usuário sem linha **não vê nada e não recebe erro** (HTTP 200 com lista vazia) |
| `03_99_rollback_parametros` | remove os 11 `dfe_*` | sem eles o código cai nos defaults internos |

Os pares de rollback **por empresa** (`empresas/*_99`) saíram: as empresas vêm da replicação em produção e, na homolog, o cadastro é refeito pelo `_01`.

---

## 3. `homolog/` — o que só existe na base de teste

| Arquivo | O que é |
|---|---|
| `01_estabelecimentos` | 12 CNPJs e 48 fluxos, **todos pausados** (a ALL CARS, 900, fica de fora: cadastro de teste de outra raiz de CNPJ) |
| `02_parametros_homolog` | `dfe_conexao_erp` (aponta para a conexão de produção, porque o clone da homolog é congelado) e `dfe_replicacao_prd` (liga o `dfe:replicar`, nasce `N`). **Na produção `dfe_conexao_erp` não pode existir** |
| `empresas/20_01`, `29_01`, `30_01` | identidade fiscal, 4 fluxos pausados e a cópia do certificado da empresa 1 (que mora em `poseidon.dpc_conta_certif_digital_emp`, tabela do ERP). **O número do arquivo é o número da empresa.** A 17 não tem arquivo: veio na carga geral e já tinha certificado próprio |

Tudo grava `created_by = 'CADASTRO DFE'`, o marcador que identifica a origem. Antes de 09/09/2026 o cadastro nascia com `'CARGA INICIAL'` e o rollback procurava `'CADASTRO DFE'`: não apagava nada e a conferência acusava sem explicar por quê.

## 4. `operacao/` — o que se repete

| Arquivo | O que faz |
|---|---|
| `pausa_empresas` | **pausa completa**: os 4 cursores de cada empresa em `P` e manifestação, Ciência e Confirmação automáticas em `N`. Troque a lista de empresas nos pontos marcados `EDITE`; o carimbo `PAUSA COMPLETA AAAA-MM-DD` entra em `updated_by` |
| `retomada_empresas` | devolve cursores `A`, manifestação `S`, Ciência `S`, Confirmação `N` **só onde o carimbo da pausa ainda vale** |

O `P` resiste a uma execução que já estava drenando: o `DfeCursorRepository` mantém `P` como `P` ao registrar consulta. Prazo que corre durante a pausa: Ciência = 10 dias da **autorização** (NT 2020.001); nota que só tem resumo e passa da janela fica sem XML completo (`cStat 596`). A captura aguenta: a SEFAZ segura 90 dias.

## 5. `producao/`

[`LEIA_instalar_em_producao.md`](../scripts/producao/LEIA_instalar_em_producao.md): a ordem para um ambiente novo (os 3 instaladores) e o registro do que foi aplicado em 13/10/2026.

---

## 6. Os ajustes únicos — removidos em 13/10/2026

`scripts/ajustes_unicos/` existiu de 30/09 a 13/10/2026 para **consertar linha** (DML) da homolog sem entrar em instalação nenhuma. Foram todos aplicados e a pasta saiu: o dado corrigido chega à produção pela replicação, e o que era configuração de ambiente foi para os instaladores. Cada um tinha rollback. **Recuperar:** git do `.claude`, commit `64f6a7a` (`scripts/ajustes_unicos/`).

| Arquivo | O que fez | Resultado medido |
|---|---|---|
| `2026-09-30_cancelamento_nfe` | `cod_situacao = 3` nas notas com evento `110111` que seguiam AUTORIZADA | **133 CANCELADA, 0 AUTORIZADA**, 51 ajustadas |
| `2026-10-01_papel_resumo` | `sig_papel_empresa = 'DEST'` nas notas `INDEF` que só tinham resumo. Base: NT 2014.002 v.1.40 | **INDEF zerado**, 96 viraram DEST |
| `2026-10-02_pausa_completa` | pausa completa das empresas 17, 20, 29 e 30: os 16 cursores em `P` e manifestação, Ciência e Confirmação automáticas em `N`. O `_rollback` é a **retomada**, com a foto de antes no cabeçalho | **aplicado** — 16 cursores pausados, 0 ativos na base |
| `2026-10-08_pausa_completa` | **homolog, aplicado em 08/10/2026 a pedido.** Mesma pausa completa de 02/10 nas empresas 17, 20, 29 e 30 (16 cursores em `P`; manifestacao, Ciencia e Confirmacao automaticas em `N`), carimbo `PAUSA COMPLETA 2026-10-08`. Deixa 0 cursores ativos na base. Rollback devolve A / S,S,N so onde o carimbo ainda vale |
| `2026-10-02_nfe_reprocessa_xml` | recoloca na fila os **9.397 `procNF`** para o parser novo preencher os campos do XML (DDL 08_01). Só o completo: o resumo não tem esses blocos. Refaz de carona itens, emitente e papel; a situação é protegida pela guarda anti-rebaixamento | **aplicado 02/10/2026** — 9.397 linhas em cada satélite e 9.397 com natureza da operação; itens (175.603) e canceladas (133) inalterados; **ICMS da nota conferido contra a soma dos itens nas 9.397: zero divergências**. Uma nota falhou por lista de volumes acima de 400 e foi refeita após o `08_02` |
| `2026-10-03_cte_reprocessa_09_01` | recoloca na fila os **54.213 `procCTe`** para o parser preencher as 15 colunas do bloco 09_01. Refaz de carona as NF-e transportadas (upsert idempotente) e o papel da empresa. ⚠️ **Exigiu um fix antes**: o CT-e era a única das três famílias sem anti-rebaixamento de situação, e a recarga teria devolvido os **518 cancelados** para AUTORIZADO — o protocolo dentro do `procCTe` é o de autorização, com `cStat 100` sempre | **aplicado 03/10/2026** — 54.794 `procCTe` em `C`, **0 em erro**. Nada caiu: cancelados 518 → 521, NF-e transportadas 61.530 → 62.213 e eventos 37.695 → 38.080 só **subiram** (a captura foi religada no meio da recarga e trouxe documento novo). Preenchimento: remetente e destinatário 99,96%, CST e autorização 100%, expedidor 26,4%, recebedor 25,5%, **valor de ICMS 18,3%** (a amostra de 250 dizia 23,2% — superestimou o ICMS00), `toma4` 9,36%, reforma 84,7%, complementado 2,31%. As **5 regras de coerência deram zero**. Os 20 sem nome de remetente não têm o bloco `rem` no XML (falta também o CNPJ) — característica do documento, não do parser |
| `2026-10-03_nfse_chave_documento` | devolve os **50 caracteres** à chave das NFS-e em `dpc_dfe_documento.chave_nf`, que o código da ingestão cortava em 44. `MERGE` a partir de `dpc_dfe_nfse.chave_nfse`, ligando por `(cod_dfe_empresa, nro_nsu)` — sem reprocessar XML —, travado para só trocar o que era exatamente o prefixo de 44. Roda **depois** do código corrigido (ApiNFE `e74673d`). Rollback corta de volta em 44, e só faz sentido revertendo o código junto | **aplicado 03/10/2026** — 10.428 trocadas em 0,4 s; 10.428 com 50, 0 com 44, todas iguais à chave da NFS-e |
| `2026-10-06_nota_cfop_xml` | preenche `dpc_dfe_nota.cod_cfop_xml` das notas que já existiam quando a coluna nasceu (`12_01`): o CFOP do item de **maior `vlr_item`**, empate pelo menor `cod_dfe_nota_item` — a mesma regra do `DfeNotaItemRepository::substitui`, que grava as notas novas. `MERGE` com `USE_HASH`, só onde a coluna é nula, carimbo `AJUSTE 2026-10-06 CFOP XML` em `updated_by` (é o que o rollback usa). Roda **depois** do `12_01`. **Provado numa cópia:** 9.582 preenchidas = as 9.582 notas com item, **0 divergências** contra a regra reimplementada em PHP, 2ª rodada toca 0 linhas, rollback zera tudo | **pendente de aplicar** (homolog) |
| `2026-10-07_parametros_fila_manifestacao` | cria dois parâmetros em `dpc_parametro`: `dfe_manifest_fila_max_ciclo` = **200** (notas por ciclo da fila; o ciclo roda a cada 10 min, ~1.200/h) e `dfe_manifest_fila_max_pedido` = **5000**. A vazão é parâmetro de propósito: não se sabe se o RecepcaoEvento tolera mais sem 656, então sobe-se aos poucos medindo os bloqueios, **sem deploy**. Só insere o que ainda não existe. Roda **depois** do `13_01` | **aplicado 07/10/2026** (homolog) |
| `2026-10-07_aba_propria_usuarios` | dá a categoria `PROPRIAS` a quem já tem `SEM_CLASSIFICACAO` em `dpc_dfe_usuario_aba` (6 usuários em 07/10/2026), com o carimbo `AJUSTE 2026-10-07 ABA PROPRIA` em `created_by`, que o rollback usa para achar as linhas — permissão dada depois pela tela não leva o carimbo e fica. Só insere para quem ainda não tem (reexecutável). Roda **depois** do `14_01`. **Provado em cópia** (6 = 6, 2ª rodada insere 0, rollback preserva a permissão da tela) | **pendente de aplicar** (homolog) |
| `2026-10-13_aba_propria_usuarios_prd` | **roda na PRODUCAO** (versao do anterior para a producao, onde a aba vem pela estrutura renomeada de `dpc_sefaz_usuario_aba`). Deu `PROPRIAS` aos 4 usuarios com `SEM_CLASSIFICACAO` (DOUGLAS, LEONARDO, SERGIOSANTOS, WARLITON), carimbo `AJUSTE 2026-10-13 ABA PROPRIA PRD`. Sem isso, depois do deploy da ApiDPC as notas proprias somem das outras abas e ninguem ve a aba nova | 16 → 20 permissoes de aba |
| `2026-10-07_param_replicacao_prd` | **roda na HOMOLOG.** Cria `dfe_replicacao_prd = 'N'` em `dpc_parametro`: o agendamento do `dfe:replicar` só age com `'S'`. Nasce desligado; ligar é decisão acompanhada, depois da carga inicial. Parar sem deploy: `update … set valor = 'N'`. Reexecutável (só insere se faltar). Rollback: `rollback/2026-10-07_param_replicacao_prd_rollback` — sem o parâmetro o agendamento entende "desligado" |
| `2026-10-02_nfse_reprocessa` | recoloca na fila os 107 `adnEvento` e, **depois**, as 10.400 `adnNFSe`, para o parser corrigido regravar situação e colunas do `07_01`. Carimbo em `det_erro`. Base: Anexos I e II do gov.br/nfse | **aplicado 02/10/2026** — 102 canceladas (todas com data, 27 com substituta), 10.298 autorizadas, 0 sem situação; as 5 substitutas (cStat 101) voltaram a autorizadas |

Os dois são o mesmo encadeamento visto de dois ângulos: nota cancelada nunca é
manifestada → o `procNF` nunca chega → **a situação ficava errada (o primeiro)
e o papel ficava indefinido (o segundo)**. Quem investigar um deve ler o outro.

### Duas lições que valem para o próximo

**O rollback tem validade curta, por desenho.** Assim que o motor roda, o
código corrigido recarimba as mesmas linhas com `updated_by = 'DFE NORMALIZAR'`
e elas saem do alcance do rollback. Já aconteceu: o carimbo `SCRIPT 05_01`
caiu de 51 para 6 linhas em um dia. Está certo assim — a partir dali o
resultado veio do fluxo, não do acerto pontual. O rollback serve para a janela
entre aplicar e confiar.

**Correção de dado sem correção de causa é conserto que expira.** Sem a
mudança de código que foi junto (ApiNFE `07b486e`), o próximo reprocessamento
de um `procNF` desfaria o acerto nota a nota — foi exatamente esse mecanismo
que produziu as 51. Todo arquivo daqui deveria vir acompanhado do commit que
impede o problema de voltar.

Convenção que valeu enquanto a pasta existiu: nome por **data** (o dado útil de um script que roda uma vez é *quando* rodou), rollback em pasta própria, carimbo único em `updated_by` para o rollback separar o que o script mudou do que o fluxo normal mudaria, e cabeçalho que registra o que foi medido. ⚠️ **Renomear o arquivo não renomeia o carimbo**: o `SCRIPT 05_01` e o `SCRIPT 05_02` ficaram em linha no banco com os nomes antigos.

---

## 7. O que foi apagado antes, e onde recuperar

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
| `ddl-por-objeto-superada/` — a primeira DDL, um arquivo por objeto | substituída pelo instalador consolidado, hoje `ddl/01_estrutura_motor` |

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

## 8. O que não é versionado, nunca

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
