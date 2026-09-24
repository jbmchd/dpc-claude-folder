# Instalar e alterar a base do módulo DFe

> Os scripts vivem em **`nfe_dfe/scripts/`** e aquela pasta
> contém **somente `.sql` para o DBeaver** — toda a explicação está aqui.
>
> Schema `POSEIDON`, tablespace `TSD_POSEIDON`. Rodar como `POSEIDON`, no
> DBeaver, **cada arquivo inteiro com `Alt+X`**, sem `/` para terminar bloco.
>
> Os arquivos são **CRLF por `.gitattributes`**. Em LF o divisor de statements do
> DBeaver corta o bloco PL/SQL no `end if;` e devolve `PLS-00103`. Foi assim que
> o `v10` falhou, e o instalador de produção tinha o mesmo problema.

---

## Um caminho só

Até 09/09/2026 havia dois, e escolher errado custava caro. Hoje é um: os
arquivos de **`scripts/ddl/`**, em três blocos.

| | |
|---|---|
| **Instalar** | `01_01` → `01_02` → `01_03` → `01_04`, depois `03_01` e os pares de `empresas/`, depois `04_01` → `04_02` |
| **Desfazer** | os `_99` de `empresas/` → `03_99` → `04_98` → `04_99` → `01_99`, do mais específico para o motor |

> **`04_01`/`04_02` não estavam nesta lista até 24/09/2026** — a manifestação
> nasceu depois deste documento e ficou fora do caminho de instalação por 1 dia.
> Sem eles, um ambiente novo sobe sem a fundação da manifestação (fila por
> evento, prazos, trancas) e sem a permissão de tela da Fase 4. As colunas de
> `dpc_dfe_empresa` que o `04_02` acrescenta também foram espelhadas no `01_01`
> como reforço (mesmo motivo do `04_01` — ver seu próprio cabeçalho), mas
> `dpc_dfe_usuario_permissao` (tabela nova, sem histórico de legado como
> `dpc_dfe_usuario_aba`) só nasce pelo `04_02` — rodar este bloco não é opcional.

O primeiro número é o bloco, o segundo é a ordem dentro dele. O `_99` de cada
bloco é o rollback daquele bloco.

O que eliminou a escolha foi a **seção 3 do `01_01`**: ela confere as 273
colunas uma a uma e acrescenta a que faltar. O `create table` da seção 2 é
pulado quando a tabela existe — era exatamente por isso que uma base parcial
precisava de um segundo conjunto de arquivos, que fazia por `ALTER` o que o
instalador fazia por `CREATE`.

> **Por que o `01_03` existe separado.** Ele carrega os 6 parâmetros em
> `POSEIDON.DPC_PARAMETRO`, que é tabela **compartilhada do ecossistema**: já
> existe, não pertence ao módulo, e por isso nunca entrou no `01_01`.
>
> Isso ficou por um dia como "seção 5 do arquivo de alterações, com um aviso
> dentro". Virou passo numerado da instalação porque **aviso dentro de um
> arquivo de 66 KB não é garantia** — e o custo de esquecer é o freio de consumo
> indevido cair para o default 5, ficar abaixo do ruído normal, e o motor se
> recusar a consultar a SEFAZ **em silêncio**. O quinto parâmetro tem um custo
> parecido e ainda mais discreto: sem `dfe_conexao_erp`, a conciliação lê o
> clone de homologação e conclui que **nenhuma** nota entrou no ERP.

## 1. Bloco 01 — o motor

| # | Arquivo | O que faz | Escreve? |
|---|---|---|---|
| 1 | `01_01_estrutura` | 13 tabelas, 13 sequences, 13 triggers, 54 constraints, 24 índices, 286 comentários — e a seção 3, que reconcilia as 273 colunas | sim (DDL) |
| 2 | `01_02_estabelecimentos` | 12 CNPJs e 48 fluxos, **todos pausados** | sim (DML) |
| 3 | `01_03_parametros` | os 6 parâmetros em `DPC_PARAMETRO`. **Antes do deploy do código** | sim (DML) |
| 4 | `01_04_validacao` | confere motor e telas; a seção 5 faz insert + `rollback` | praticamente não |
| — | `01_99_rollback_motor` | desfaz as 13 tabelas, as 13 sequences e os 6 parâmetros | sim |

Depois do bloco 01 vêm os outros dois, cada um com o seu rollback:

| Bloco | Arquivo | O que faz |
|---|---|---|
| `empresas/` | `20_01_empresa_20` · `29_01_empresa_29` · `30_01_empresa_30` | um par por estabelecimento trazido depois da carga geral: identidade, 4 fluxos pausados e a cópia do certificado da empresa 1. O número do arquivo é o número da empresa. A **17** não tem par: veio na carga geral e já tinha certificado próprio no ERP — só precisa ser ativada |
| 03 | `03_01_parametrizacao_telas` | `dpc_dfe_usuario_empresa`, `dpc_dfe_usuario_aba` e `dpc_dfe_painel_alerta` |
| 04 | `04_01_manifestacao` | fundação da manifestação (23/09/2026): 6 colunas novas em `dpc_dfe_manifestacao`, UK com sequência, 2 trancas de automação em `dpc_dfe_empresa`, 4 parâmetros. Rollback: `04_99` |
| 04 | `04_02_manifestacao_fases_2a4` | Fases 2-4 (24/09/2026): corte de data da Confirmação automática (`dta_inicio_manif_auto_conf`) e a tabela `dpc_dfe_usuario_permissao` (permissão da tela manual). Rollback: `04_98` |

Todos são **reexecutáveis**: objeto criado só se ainda não existir, linha
inserida só se ainda não existir, coluna acrescentada só se faltar. Falha no
meio se resolve corrigindo e rodando de novo.

### Por que não há um único `alter` aqui

A estrutura de homologação foi construída por um `install_dbeaver.sql` mais cinco
alters (`v2`–`v6`). **Aqueles arquivos foram removidos do repositório** em
20/08/2026 — seguem no histórico do git — porque não serviam para instalar em
produção, e não era questão de estilo:

| O que o script antigo faria | Por que é errado |
|---|---|
| criaria `DPC_DFE_EMPRESA_CK1` e `_IX1` | são sobre `status_sincronismo`, `dta_liberado_em` e outras colunas de cursor que **saíram** daquela tabela no `v2`. Recriar é ressuscitar objeto sobre coluna inexistente |
| manteria `DPC_DFE_DOCUMENTO_UK1 (empresa, nsu)` | foi **substituída** pela `UK2 (cursor, nsu)`. O NSU é sequencial **por fluxo**: o NSU 100 da NF-e e o NSU 100 do CT-e são documentos diferentes e colidiriam. A unique que protege contra duplicidade viraria **perda de documento** |

Os arquivos de hoje são o **estado final**, com os deltas já aplicados.

### Antes de rodar — uma decisão e duas conferências

**A decisão: quais CNPJs entram.** O `02` cadastra 13 — as 12 filiais de
homologação mais a empresa 30 (MS). A **ALL CARS (900) não entra**: é cadastro de
teste e o certificado dela não existe em produção. Se a lista estiver errada,
ajuste as linhas da seção 1 do `02` antes de rodar; cada uma é um `insert`
independente e guardado.

**Conferência 1 — o tablespace.** A seção 0 do `01` mostra se `TSD_POSEIDON`
existe e está `ONLINE`. Se em produção o nome for outro, troque no arquivo antes
— é o único lugar.

**Conferência 2 — espaço.** O XML fica em BLOB comprimido em gzip: **~2,3 GB por
ano** para o corpus de NF-e completo. A guarda legal é de **11 anos** (Ajuste
SINIEF 2/2025, que ampliou de 5), então dimensione para **~25 GB**, não para o
primeiro ano.

### O que a instalação **não** liga

**Nada consulta nada depois de rodar estes scripts.** Os 52 fluxos nascem com
`status_sincronismo = 'P'`.

Não é cautela genérica. A posição de leitura (o NSU) é **uma por CNPJ e
compartilhada entre quem consulta**, e hoje quem consulta os CNPJs da DPC é a
**Qive**. Dois consumidores no mesmo CNPJ é causa documentada de `cStat 656`, que
bloqueia **aquele CNPJ** por 1 hora (NT 2014.002 item 3.11.4.1). O corte com a
Qive continua tendo de ser seco: o problema é a sequência de NSU disputada, não
o certificado.

Ativar um fluxo exige antes saber **a data e hora em que a Qive para de consultar
aquele CNPJ**. As duas exceções conhecidas são a empresa **900** (que não vai
para produção) e a empresa **30**.

Além dos fluxos, falta:

- **`RUN_SCHEDULE=1`** no `.env`. O agendamento já está no `Kernel`; com `0`,
  nada dispara;
- **certificados.** O levantamento de 06/08/2026 achou, dos 27 CNPJs ativos,
  apenas **3** com certificado utilizável (empresas 1, 3 e 8): 7 expiraram em
  13/11/2025 e 2 têm senha errada gravada. É cadastro, não código — a seção 3 do
  `02` lista a situação de cada um.

> Cadastrar o fluxo **mesmo sem certificado** é o certo: quem reporta validade é
> o `dfe:monitorar`, e ele só vê o que está cadastrado. Fluxo ausente não gera
> alerta — foi assim que um vencimento passou **9 meses** sem ninguém notar.

### Como conferir que ficou igual ao testado

A seção 6 do `03` produz uma **impressão digital** da estrutura: colunas com tipo
e tamanho, constraints com condição, índices com colunas e direção. Rode **nos
dois ambientes** e compare.

Contagem por si não basta — não pega coluna com tamanho diferente nem check
divergente, que é exatamente o erro que só aparece em produção.

**Duas diferenças são conhecidas e aceitas:**

1. As sequences `DPCS_DFE_CURSOR`, `_CTE`, `_CTE_NFE` e `_NFSE` estão `NOCACHE`
   em homologação e `CACHE 20` na instalação nova. Uniformizado de propósito.
2. **Comentários de coluna: 263 na instalação nova, 135 em homologação.**
   Medido em 02/09/2026. Homologação não foi construída pelo `01_estrutura` — foi
   pelo `install` antigo mais os alters — e aquele `install` nunca comentou todas
   as colunas. As duas tabelas criadas pelos alters estão completas
   (`NOTA_ITEM` 51/51, `CTE_EVENTO` 20/20); as do instalador antigo, não. A
   instalação nova é **mais** completa, e a diferença aparece só nessa contagem.

Qualquer outra diferença merece investigação.

#### O ESPERADO da seção 1, hoje

| Objeto | Esperado |
|---|---|
| tabelas · sequences · triggers | **13** cada |
| constraints (fora `SYS_%`) | **52** |
| índices (`all_indexes` de `DPC_DFE%`, inclui os de PK/UK) | **47** |
| colunas | **263** |
| comentários de tabela | **13** |
| comentários de coluna | **263** (homologação mostra 135 — ver acima) |

Esses números **deixaram de ser digitados à mão** em 02/09/2026: o gerador os
deriva da estrutura e tem uma autoverificação que o faz **parar** se o script
emitido discordar. A razão está registrada na seção 2, em "o que a unificação
consertou".

#### O que essa comparação já achou

Os arquivos foram gerados a partir dos scripts e depois comparados com a
estrutura real de homologação, objeto por objeto:

| Comparação | Resultado |
|---|---|
| 11 tabelas, 190 colunas — tipo, tamanho, nulabilidade, default | **zero divergência** |
| `DPC_DFE_NOTA_ITEM` (51 colunas) | acrescentada depois; parser validado em **833 itens reais**, 0 erro |
| 43 constraints — conjunto de nomes | **idênticos** |
| 9 `CHECK` — condição literal | **todas iguais** |
| 17 índices próprios — colunas e direção | **todos iguais** |
| 21 índices restantes | todos de PK/UK; nenhum órfão |

Achou **um erro real**: `'EMIT'` estava escrito como valor aceito em
`DPC_DFE_CTE_CK1`, e esse valor **não existe** — o parser só devolve `REM`,
`EXPED`, `RECEB`, `DEST`, `TOMA` ou `OUTRO`. Corrigido, com a explicação junto da
constraint no `01`.

E um falso positivo que vale conhecer: `DPCI_DFE_EXECUCAO_CURSOR` aparece no
dicionário como `(cod_dfe_cursor, SYS_NC00016$ desc)`. Não é divergência — é como
o Oracle armazena índice descendente, criando coluna virtual oculta. O índice é
`FUNCTION-BASED` com expressão `"DTA_INICIO"`, exatamente o que `dta_inicio desc`
produz.

## 2. De onde veio o que está no `01_01`

Esta seção é **história**, e não um caminho a rodar. Os arquivos citados aqui
foram removidos em 09/09/2026, quando o `01_01` passou a servir a qualquer base
— seguem no git do `.claude` e no da ApiNFE.

Os quatro scripts de estrutura (`v7` a `v10`) foram unificados em 02/09/2026, e
absorvidos pelo instalador em 09/09. Cada um segue recuperável no histórico do
git da ApiNFE:

| Seção | O que acrescenta | vinha de | commit |
|---|---|---|---|
| 1 | `DPC_DFE_NOTA_ITEM` — os itens da NF-e | `v7` | `1bdc4a7` |
| 2 | `NOTA.SIG_PAPEL_EMPRESA` — o papel da empresa na nota | `v8` | `ede36cc` |
| 3 | `NOTA.VLR_TOTAL_PRODUTO` — o `vProd` do `ICMSTot`, para a conferência comparar grandezas iguais | `v9` | `1bdc4a7` |
| 4 | `DPC_DFE_CTE_EVENTO` — trouxe 2.853 eventos, o comprovante de entrega e **20 CT-e cancelados** (R$ 26.796,56) que passavam por válidos | `v10` | `77771bc` |

O antigo `v11` virou o **`01_03_parametros`**, e o `v12` e o `v13` — a escada de
estado no ERP e a categoria com o comprador — foram absorvidos pelo `01_01`
junto com estes quatro.

> **Duas correções de 09/09/2026, feitas ao reinstalar em tst depois de a base
> de teste ser refeita — no arquivo que depois foi absorvido pelo `01_01`.**
>
> A seção 1 tinha uma **cópia da conferência da seção 3**, e ela lia
> `VLR_TOTAL_PRODUTO` — coluna que a seção 3 cria ~300 linhas adiante. Numa base
> que ainda não tinha a coluna, o script morria com
> `ORA-00904: "N"."VLR_TOTAL_PRODUTO": invalid identifier`. Era o único forward
> reference do arquivo. A cópia saiu (a da seção 3 é melhor: filtra pela
> tolerância de 0,02 e devolve só as divergências), e o comentário que mandava
> rodar `v9_total_produto_nota_dbeaver.sql` antes saiu com ela — aquele arquivo
> não existe mais desde a unificação, virou a própria seção 3.
>
> E o `04` ganhou um **quinto parâmetro**, o `dfe_conexao_erp`. Ele é de outra
> natureza: os quatro primeiros calibram o motor e o default do código serve;
> este responde **onde está o ERP**, e o default é "a conexão corrente" — que em
> homologação é a errada. Tinha sido criado à mão em 03/09 e nenhum script o
> registrava, então quando a base foi refeita ele sumiu sem deixar rastro e não
> havia de onde recriá-lo.

Tudo já aplicado em **tst**. Em **prd** nada disto rodou — mas a afirmação que
estava aqui, de que as tabelas não existem em produção, **era falsa desde
25/08/2026**: alguém rodou o instalador e a carga inicial lá naquele dia.

Medido em 09/09/2026: prd tem 12 tabelas (falta a `DPC_DFE_CTE_EVENTO`),
`DPC_DFE_NOTA` com **26 colunas** contra 37 em tst — nenhuma da v12/v13 —, os 13
estabelecimentos, os 52 fluxos pausados, 0 documento e **0 parâmetro**. É o mesmo
estado de 27/08 em que homologação foi encontrada naquele dia.

Por decisão de 09/09/2026, **o motor vive só na base de teste**, e produção serve
exclusivamente para o `dfe:conciliar` **ler** a Consinco. Aquelas 12 tabelas,
portanto, não são usadas por ninguém. Removê-las é o
`01_99_rollback_motor_dbeaver.sql` rodado em prd — ele é guardado por existência,
lida com a 13ª ausente, e **não toca** nas três tabelas de tela, que em prd
guardam 45 e 16 linhas de permissão de usuário.

**A ordem interna não pode ser mexida**: a seção 3 usa na conferência a coluna
que a 1 introduz.

**As seções "popular o acervo" são comentário, não statement.** Rodar o arquivo
**não** reprocessa nada. Quem quiser reinterpretar o acervo já capturado
descomenta e roda à mão — e isso não custa nenhuma chamada à SEFAZ, porque os
XML estão guardados em `DPC_DFE_DOCUMENTO`.

### A unificação não mudou uma linha de SQL

Foi concatenação verbatim, com banner de comentário entre as seções. Conferido
por comparação linha a linha do conteúdo executável: **559 linhas** nos quatro
originais, 559 no arquivo único, idênticas e na mesma ordem. O `04` idem: **51
linhas**, iguais às do antigo `v11`.

### O que a unificação consertou

Juntar os arquivos obrigou a olhar o conjunto, e apareceram dois defeitos que
estavam calados:

| Defeito | Consequência |
|---|---|
| O `03_validacao` esperava **12 tabelas** | passava por "ok" sem nunca conferir a 13ª (`DPC_DFE_CTE_EVENTO`), criada pelo `v10` |
| O `99_rollback` dropava **12 tabelas** | **rollback incompleto que se apresenta como completo** — deixava `DPC_DFE_CTE_EVENTO` de pé, com sequence e trigger |

A causa dos dois era a mesma: as contagens eram literais digitados no gerador, e
envelheceram quando a estrutura cresceu. Agora derivam de `estrutura_final.json`
e o gerador **para** se o script emitido discordar da estrutura.

### A regra que impede a divergência voltar

**Toda alteração está também no `01_estrutura` consolidado**, e as duas
definições saem do **mesmo gerador**, de propósito.

Não é preciosismo: foi a divergência entre o `install` e os cinco alters
anteriores (`v2`–`v6`) que tornou aqueles scripts inservíveis para produção — o
install continuava criando objetos que um alter havia removido, e mantinha a UK
que outro havia substituído. Essa UK, se recriada, transforma a proteção contra
duplicidade em **perda de documento**.

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

## 3. Duas colunas que merecem atenção de quem for consultar

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

## 4. Uma assimetria da estrutura que vale saber antes de instalar

A **`DPC_DFE_NFSE` não tem colunas de conciliação com o ERP**, ao contrário da
`DPC_DFE_NOTA`. Foi verificado no banco que a DPC **não registra NFS-e recebida
em lugar nenhum do Consinco**. Para nota de serviço aquela tabela passa a **ser**
o registro — e é a única das três famílias em que um erro nosso não tem segunda
fonte para aparecer.

---

O papel de cada tabela: [04_dados-tabelas.md](04_dados-tabelas.md) ·
catálogo de todos os scripts: [09_catalogo-scripts.md](09_catalogo-scripts.md) ·
voltar ao [índice](readme.md)
