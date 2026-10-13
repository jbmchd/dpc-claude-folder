# Instalar e alterar a base do módulo DFe

> Os scripts vivem em **`nfe_dfe/scripts/`** e aquela pasta contém **somente `.sql` para o DBeaver** — toda a explicação está aqui e no [catálogo](09_catalogo-scripts.md).
>
> Schema `POSEIDON`, tablespace `TSD_POSEIDON`. Rodar como `POSEIDON`, no DBeaver, **cada arquivo inteiro com `Alt+X`**, sem `/` para terminar bloco, com o **DBMS_OUTPUT ligado**.
>
> Os arquivos são **CRLF por `.gitattributes`**. Em LF o divisor de statements do DBeaver corta o bloco PL/SQL no `end if;` e devolve `PLS-00103`. Dentro de um bloco PL/SQL **não pode haver linha em branco** (o DBeaver a trata como fim de statement).

---

## Um caminho só, com três arquivos

Reescrito em **13/10/2026**: o que eram 17 arquivos acumulados (14 blocos, de 02/09 a 07/10) virou **um instalador convergente por assunto**. Cada um serve a base **vazia, parcial ou completa**, e rodar duas vezes dá o mesmo resultado da primeira.

| # | Arquivo (`scripts/ddl/`) | O que entrega |
|---|---|---|
| 1 | `01_estrutura_motor_dbeaver.sql` | **17 tabelas** do motor: `empresa`, `cursor`, `emitente`, `execucao`, `documento`, `nota` (+ `item`, `total`, `transporte`, `cobranca`), `cte` (+ `cte_nfe`, `cte_evento`), `nfse`, `evento`, `manifestacao`, `manif_pedido` — com sequences, triggers, constraints, índices e comentários |
| 2 | `02_estrutura_telas_dbeaver.sql` | **6 tabelas** de tela: `usuario_empresa`, `usuario_aba`, `usuario_permissao`, `usuario_coluna`, `usuario_modelo`, `painel_alerta` |
| 3 | `03_parametros_dbeaver.sql` | os **11** parâmetros `dfe_*` de `DPC_PARAMETRO` (só insere o que falta; nunca atualiza) |
| — | `04_validacao_dbeaver.sql` | somente leitura; compare com o ESPERADO de cada seção (a seção 5 faz um insert que termina em `rollback`) |
| — | `rollback/01_99`, `02_99`, `03_99` | **um rollback para cada DDL** (derruba o motor / as telas / remove os parâmetros) |

**Instalar:** `01` → `02` → `03`; depois `04`. **Desfazer:** `02_99` → `01_99` → `03_99`.

Dado e valor que só existem na base de **teste** (estabelecimentos, as empresas 20/29/30 com o certificado, `dfe_conexao_erp` e `dfe_replicacao_prd`) ficam em **`scripts/homolog/`**; operação recorrente (pausar e retomar empresas) em **`scripts/operacao/`**. Nada disso entra numa instalação de produção, onde os dados vêm da replicação (`dfe:replicar`). A ordem para um ambiente novo, e o que foi feito na produção em 13/10/2026, estão em [`scripts/producao/LEIA_instalar_em_producao.md`](../scripts/producao/LEIA_instalar_em_producao.md).

### Como o arquivo é convergente

Cada seção dos instaladores 1 e 2 é uma lista de blocos guardados por consulta ao dicionário:

| Seção | O que faz | Se já existe |
|---|---|---|
| 1 Sequences · 2 Tabelas | cria | pula |
| **3 Colunas** | confere cada coluna **uma a uma** e acrescenta a que faltar | no-op |
| **4 Constraints** | PK e FK: cria se faltar. **UK e CHECK: derrubam e recriam se a definição difere** (uma UK que ganhou coluna, uma CHECK que aceitou valor novo) | no-op |
| 5 Índices | cria se faltar | pula |
| 6 Triggers · 7 Comentários | `create or replace` / `comment on` | reescreve igual |
| 8 Conferência | invariantes e contagem por tabela | só leitura |

Coluna nova do módulo entra em **dois lugares** do mesmo arquivo: no `create table` (seção 2) e na lista da seção 3. **Nunca** se acrescenta um script de "alteração" separado — foi essa divergência entre instalador e alters que, em 09/09/2026, voltou a base de teste 13 dias e inutilizou os alters antigos para produção.

O que o instalador **não** faz: não altera tipo nem tamanho de coluna existente (`MODIFY` pode falhar por causa do dado e não cabe em script automático — a divergência aparece no `04_validacao` e no `dfe:replicar --estrutura`) e coluna `NOT NULL` sem `DEFAULT` acrescentada a tabela **com linhas** falha com `ORA-01758` (é o certo; o `DBMS_OUTPUT` diz qual coluna exige decisão humana).

### Prova de que o arquivo novo equivale ao antigo (13/10/2026)

Os instaladores foram gerados do **dicionário da homolog** e provados numa cópia descartável (`DPC_DFE_` → `ZZP_DFE_`, mesma largura) em quatro partidas, todas com **0 erros do Oracle** e estrutura **idêntica** à da homolog (23 tabelas, 466 colunas, 83 constraints, 66 índices, 13 triggers, 13 sequences):

| Partida | Resultado |
|---|---|
| base **vazia** | instala tudo; a 2ª passada é no-op |
| por cima do **estado antigo** (os 14 arquivos anteriores) | no-op |
| por cima de **só o `01_01` antigo** (parcial) | acrescenta as 60 colunas que faltavam e converge |
| CHECK da aba sem `PROPRIAS`, UK da manifestação sem a sequência e uma coluna removida | redefine as duas constraints e re-acrescenta a coluna; a passada seguinte é no-op |

Única diferença para a homolog: **28 colunas que estavam sem comentário** (as três tabelas satélite da NF-e, `manif_pedido`, `usuario_coluna` e `usuario_modelo`) ganharam o seu. É só `COMMENT ON`; sai na primeira vez que o arquivo rodar em cada ambiente.

---

## Antes de rodar

**Tablespace.** A seção 0 mostra se `TSD_POSEIDON` existe e está `ONLINE`. Se em produção o nome for outro, troque no arquivo antes — é o único lugar.

**Espaço.** O XML fica em BLOB comprimido em gzip: **~2,3 GB por ano** para o corpus de NF-e completo. A guarda legal é de **11 anos** (Ajuste SINIEF 2/2025), então dimensione para **~25 GB**, não para o primeiro ano. Em 13/10/2026 os dados DFe da homolog somavam **~1,9 GB** (tabelas, índices e LOBs).

### O que a instalação **não** liga

**Nada consulta nada depois de rodar estes scripts.** A estrutura sozinha não cadastra empresa nem cria fluxo; os fluxos que a homolog tem nascem **pausados**.

Não é cautela genérica. A posição de leitura (o NSU) é **uma por CNPJ e compartilhada entre quem consulta**, e hoje quem consulta os CNPJs da DPC é a **Qive**. Dois consumidores no mesmo CNPJ é causa documentada de `cStat 656`, que bloqueia **aquele CNPJ** por 1 hora (NT 2014.002 item 3.11.4.1). Ativar um fluxo exige antes saber **a data e hora em que a Qive para de consultar aquele CNPJ**.

Falta, além dos fluxos, `RUN_SCHEDULE=1` no `.env` (o agendamento já está no `Kernel`) e os certificados — cadastro, não código. Cadastrar o fluxo **mesmo sem certificado** é o certo: quem reporta validade é o `dfe:monitorar`, e ele só vê o que está cadastrado; fluxo ausente não gera alerta (um vencimento passou **9 meses** assim).

### Como conferir que ficou igual ao testado

O jeito certo é o comando, que lê as duas bases e compara pelo dicionário (colunas com tipo e tamanho, constraints **com a condição das CHECK**, índices com colunas e direção, triggers com o corpo, sequences, comentários):

```
cd ApiNFE
dev.cmd dfe:replicar --estrutura        # homolog (origem) x o destino configurado
```

**Zero diferenças = pronto.** Sem o comando, a seção 6 do `04_validacao` produz a impressão digital para rodar nos dois ambientes e comparar à mão. Contagem por si não basta: não pega coluna com tamanho diferente nem CHECK divergente.

Falso positivo que vale conhecer: `DPCI_DFE_EXECUCAO_CURSOR` aparece no dicionário como `(cod_dfe_cursor, SYS_NC00016$ desc)`. Não é divergência: é como o Oracle guarda índice descendente (coluna virtual oculta; o índice é `FUNCTION-BASED` com a expressão `"DTA_INICIO"`).

---

## De onde veio o que está nos instaladores

| Antes (até 13/10/2026) | Hoje |
|---|---|
| `01_01_estrutura` | `01_estrutura_motor` |
| `04_01`, `07_01`, `08_01`, `08_02`, `09_01`, `12_01`, `13_01` | `01_estrutura_motor` (as colunas e tabelas do estado final) |
| `03_01_parametrizacao_telas`, `04_02`, `06_01`, `10_01`, `11_01`, `14_01` | `02_estrutura_telas` (a lógica de rename `dpc_sefaz_* → dpc_dfe_*` saiu: todos os ambientes já migraram) |
| `01_03_parametros`, parâmetros do `04_01`, `ajustes_unicos/2026-10-07_parametros_fila_manifestacao`, `producao/P1_02` | `03_parametros` (e `dfe_conexao_erp` foi para `homolog/02_parametros_homolog`) |
| `01_04_validacao` | `04_validacao` |
| 13 rollbacks por bloco | 3 rollbacks, um por DDL |
| `01_02_estabelecimentos`, `empresas/*_01` | `homolog/` (os `_99` saíram) |
| `ajustes_unicos/` (13) | removidos; histórico em [09 §6](09_catalogo-scripts.md); a pausa virou `operacao/` |

Tudo continua no git do `.claude` (último commit com a estrutura antiga: `64f6a7a`).

---

### Depois de rodar, se quiser popular os itens do acervo

```sql
update poseidon.dpc_dfe_documento
   set status_process = 'P', qtd_tentativa = 0
 where dsc_tipo_doc = 'procNF';
commit;
```

```
dev.cmd dfe:normalizar --limit=5 --dry-run    -- confere primeiro
dev.cmd dfe:normalizar
```

Em homologação isso produz **833 itens** de 19 notas completas — número medido
pelo parser antes de a tabela existir.

Reprocessar `procNF` é seguro: a nota é atualizada pela UK `(empresa, chave)`, o
emitente pela UK do CNPJ, e os itens são **substituídos** por nota. Nada
duplica.

A conferência que vale está na seção 1 do próprio arquivo — compara a soma dos
`<det>` com o total que veio do `ICMSTot`. São dois caminhos independentes do
mesmo XML, e divergência ali aponta extração incompleta.

## Duas colunas que merecem atenção de quem for consultar

**`DPC_DFE_CURSOR.NRO_ULTIMO_NSU` é o dado mais sensível do módulo.** É um token
que a fonte devolve e que só pode ser **continuado**; nem a SEFAZ nem o ADN
guardam a posição de leitura — ela existe somente aqui. Valor arbitrário retorna
`cStat 656` e bloqueia o certificado por 1 hora. **Não ofereça edição disso em
tela**: reposicionar é operação de linha de comando, com guarda que recusa valor
não recebido.

**`DPC_DFE_CURSOR.NRO_MAXIMO_NSU` pode ser 0 legitimamente.** A SEFAZ informa o
total; o **ADN não informa**. Nesse caso o atraso é **desconhecido, não zero** —
nunca calcule `maximo - ultimo` sem checar `maximo >= ultimo`, senão o painel
exibe atraso negativo e o total de backlog encolhe.

## Uma assimetria da estrutura que vale saber antes de instalar

A **`DPC_DFE_NFSE` não tem colunas de conciliação com o ERP**, ao contrário da
`DPC_DFE_NOTA`. Foi verificado no banco que a DPC **não registra NFS-e recebida
em lugar nenhum do Consinco**. Para nota de serviço aquela tabela passa a **ser**
o registro — e é a única das três famílias em que um erro nosso não tem segunda
fonte para aparecer.

---

O papel de cada tabela: [04_dados-tabelas.md](04_dados-tabelas.md) ·
catálogo de todos os scripts: [09_catalogo-scripts.md](09_catalogo-scripts.md) ·
voltar ao [índice](readme.md)
