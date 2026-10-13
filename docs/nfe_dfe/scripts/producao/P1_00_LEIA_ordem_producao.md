# Estrutura de banco do módulo DFe em PRODUÇÃO — ordem de execução

> **Escopo:** só a **estrutura** (Parte 1). Os dados chegam depois, pela carga inicial do `dfe:replicar` (Parte 2).
> **Banco:** Oracle de produção (RAC: `dpcdb1` ou `dpcdb2`), schema `poseidon`, conectado como POSEIDON no DBeaver.
> **Provado em 07/10/2026:** instalação do zero com os scripts reais (renomeados `ZZP_`, numa cópia descartável da homolog) terminou com **0 erros do Oracle e estrutura idêntica à da homolog** (23 tabelas, 466 colunas, 83 constraints, 66 índices, 13 triggers, 13 sequences, comentários).

## 0. Rode a pasta `rodar_em_ordem/`

Os arquivos da tabela abaixo estão copiados, **numerados na ordem de execução**, em [`rodar_em_ordem/`](rodar_em_ordem/): é só abrir do `00` ao `16` no DBeaver.

| Arquivo da pasta | Banco | Origem (a fonte da verdade) |
|---|---|---|
| `00_HOMOLOG_param_replicacao_prd` | **homolog** | `ajustes_unicos/2026-10-07_param_replicacao_prd` |
| `01_drop_orfas_prd` | produção | `producao/P1_01` |
| `02_estrutura_motor` | produção | `ddl/01_01` |
| `03_telas_parametrizacao` | produção | `ddl/03_01` |
| `04_manifestacao` | produção | `ddl/04_01` |
| `05_manifestacao_fases_2a4` | produção | `ddl/04_02` |
| `06_colunas_usuario` | produção | `ddl/06_01` |
| `07_nfse_tipo_emissao` | produção | `ddl/07_01` |
| `08_nfe_satelites` | produção | `ddl/08_01` |
| `09_nfe_volume_listas` | produção | `ddl/08_02` |
| `10_cte_conferencia_mensal` ⚠️ única | produção | `ddl/09_01` |
| `11_relatorio_colunas` | produção | `ddl/10_01` |
| `12_modelos_usuario` ⚠️ única | produção | `ddl/11_01` |
| `13_nota_cfop_xml` ⚠️ única | produção | `ddl/12_01` |
| `14_manifestacao_pedido` ⚠️ única | produção | `ddl/13_01` |
| `15_usuario_aba_propria` | produção | `ddl/14_01` |
| `16_parametros_prd` | produção | `producao/P1_02` |

**Não edite a pasta.** `ddl/` segue sendo o único caminho de instalação (os rollbacks e o hub citam os nomes `01_01`, `04_02`…). A pasta é gerada por `python gera_ordem_producao.py`; `--confere` diz se está em dia. O número do arquivo **não** é o número do bloco: o `10_cte_…` da pasta é o `09_01` do `ddl/`.

## 1. Ordem

| # | Arquivo | O que faz | Observação |
|---|---|---|---|
| 1 | `producao/P1_01_drop_orfas_prd_dbeaver.sql` | apaga as 12 tabelas órfãs (estrutura velha, de 25/08/2026) e as 12 sequences | **tem trava**: a seção 1 precisa dar `dpcdb1` ou `dpcdb2` e zero dependências. Sem rollback de dado: eram 13 empresas e 52 cursores que a carga inicial refaz |
| 2 | `ddl/01_01_estrutura_dbeaver.sql` | o motor: tabelas, índices, triggers, sequences | o cabeçalho confere schema e `TSD_POSEIDON` antes de criar |
| 3 | `ddl/03_01_parametrizacao_telas_dbeaver.sql` | `usuario_empresa`, `usuario_aba`, `painel_alerta` | só estrutura (0 `insert`) |
| 4 | `ddl/04_01_manifestacao_dbeaver.sql` | fundação da manifestação | cria 4 parâmetros `dfe_manifest_*` (com guarda) |
| 5 | `ddl/04_02_manifestacao_fases_2a4_dbeaver.sql` | `usuario_permissao` + corte da Confirmação automática | |
| 6 | `ddl/06_01_colunas_usuario_dbeaver.sql` | `usuario_coluna` | |
| 7 | `ddl/07_01_nfse_tipo_emissao_dbeaver.sql` | 12 colunas em `nfse` | |
| 8 | `ddl/08_01_nfe_satelites_dbeaver.sql` | 3 satélites da NF-e + 31 colunas em `nota` | |
| 9 | `ddl/08_02_nfe_volume_listas_dbeaver.sql` | listas de volume 400 → 1000 | numa base nova não há linha nem carga rodando: sem risco de lock |
| 10 | `ddl/09_01_cte_conferencia_mensal_dbeaver.sql` | 15 colunas em `cte` | ⚠️ **execução única** (ver §3) |
| 11 | `ddl/10_01_relatorio_colunas_dbeaver.sql` | amplia a CHECK de `usuario_coluna` | reexecutável |
| 12 | `ddl/11_01_modelos_usuario_dbeaver.sql` | `usuario_modelo` | ⚠️ **execução única** |
| 13 | `ddl/12_01_nota_cfop_xml_dbeaver.sql` | coluna `cod_cfop_xml` | ⚠️ **execução única** |
| 14 | `ddl/13_01_manifestacao_pedido_dbeaver.sql` | `manif_pedido` + coluna/FK/índice em `manifestacao` | ⚠️ **execução única** |
| 15 | `ddl/14_01_usuario_aba_propria_dbeaver.sql` | CHECK da aba aceita `PROPRIAS` | reexecutável |
| 16 | `producao/P1_02_parametros_prd_dbeaver.sql` | os 11 parâmetros `dfe_*` da homolog | só insere o que falta; **sem** `dfe_conexao_erp` |

Depois do 16: rodar o **comparador de estrutura** (§4) e me avisar.

## 2. O que fica de fora da produção — e por quê

| Arquivo | Por quê |
|---|---|
| `ddl/01_02_estabelecimentos` | insere os CNPJs de homologação. Na produção as empresas chegam pela carga inicial |
| `ddl/01_03_parametros` | traz `dfe_conexao_erp = oracle`, que na produção **quebra a lógica**: o ERP é a própria base e o código já usa a conexão corrente. O `P1_02` o substitui |
| `ddl/01_04_validacao` | teste com contagens esperadas da homolog |
| `ddl/empresas/*` | cadastro por empresa, com cópia de certificado de homolog |
| `ajustes_unicos/*` | correções de dado da homolog. O que serve à produção (parâmetros da fila, aba própria) já está no `P1_02` e na carga inicial |
| `*/rollback/*` | só para desfazer |

## 3. Blocos de execução única (correção de uma afirmação antiga)

O doc `07` dizia que **todos** os blocos eram reexecutáveis. **Não são.** Medido na reexecução completa de 07/10/2026: `09_01`, `11_01`, `12_01` e `13_01` dão erro Oracle na segunda vez (coluna/tabela/FK já existe). É proposital em alguns (o `09_01` diz no cabeçalho que não é idempotente), e nenhum estraga dado — o erro só avisa que já rodou.

**Regra para a produção:** rodar cada um **uma vez**. Se parar no meio, **não repita o arquivo inteiro**: o `select` do cabeçalho de cada um diz o que já existe; conserte e rode só a parte que faltou. Os demais (`01_01`, `03_01`, `04_01`, `04_02`, `06_01`, `07_01`, `08_01`, `08_02`, `10_01`, `14_01`, `P1_02`) podem repetir.

## 4. Comparador de estrutura (aceite da Parte 1)

Só leitura, pelo dicionário do Oracle. Confronta homolog × produção: tabelas, colunas (tipo, tamanho, nulidade, default), constraints (com a condição das CHECK), índices (colunas e ordem), triggers, sequences e comentários.

- **Zero diferenças** = estrutura pronta para a carga de dados.
- Antes de qualquer script o comparador acusa a diferença esperada (produção só com as 12 órfãs velhas): 23×12 tabelas, 466×242 colunas. Rodei como teste de sanidade em 07/10/2026 e ele pegou, entre outras, a UK velha da manifestação (sem `nro_seq_evento`).
- Quem roda: eu, assim que você disser que aplicou o item 16.

## 5. Antes de aplicar

1. VPN/rede da empresa e conferir a instância: `select sys_context('userenv','instance_name') from dual` → **`dpcdb1` ou `dpcdb2`** (a produção é um RAC: o nó muda conforme a conexão; qualquer outro nome, como `homolog`, é a base errada).
2. Ninguém usa o módulo em produção: não há deploy de tela nem de API lá ainda (fora do escopo desta etapa).
3. Cada arquivo é DBeaver (CRLF, sem `/`): rodar **seção por seção** com Ctrl+Enter, ou o arquivo todo com Alt+X nos que não têm bloco PL/SQL.
