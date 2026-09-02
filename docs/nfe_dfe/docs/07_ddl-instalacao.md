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

## Qual caminho usar

| Situação | Onde ir |
|---|---|
| **Base nova**, nada instalado | os cinco da raiz de `scripts/` — `01` → `02` → `03` → `04` |
| **Base já instalada**, anterior ao v7 | `scripts/alteracoes/atualizacao_v7_a_v10_dbeaver.sql` e depois **`scripts/04_parametros`** |

Os dois caminhos **convergem para a mesma estrutura** e terminam no **mesmo
`04`**. Não são sequenciais: o `01` cria por `CREATE` o que o arquivo de
alterações faz por `ALTER`. Rodar os dois não quebra — tudo é idempotente — mas
o segundo não faz nada.

> **Por que o `04` existe separado.** Ele carrega os 4 parâmetros em
> `POSEIDON.DPC_PARAMETRO`, que é tabela **compartilhada do ecossistema**: já
> existe, não pertence ao módulo, e por isso nunca entrou no `01`.
>
> Isso ficou por um dia como "seção 5 do arquivo de alterações, com um aviso
> dentro". Virou passo numerado da instalação porque **aviso dentro de um
> arquivo de 66 KB não é garantia** — e o custo de esquecer é o freio de consumo
> indevido cair para o default 5, ficar abaixo do ruído normal, e o motor se
> recusar a consultar a SEFAZ **em silêncio**.

## 1. Base nova — os cinco da raiz de `scripts/`

| # | Arquivo | O que faz | Escreve? |
|---|---|---|---|
| 1 | `01_estrutura_dbeaver.sql` | sequences, tabelas, constraints, índices, triggers e comentários das **13 tabelas** | sim (DDL) |
| 2 | `02_carga_inicial_dbeaver.sql` | 13 estabelecimentos e 52 fluxos, **todos pausados** | sim (DML) |
| 3 | `03_validacao_dbeaver.sql` | confere tudo; a seção 5 faz insert + `rollback` | praticamente não |
| 4 | `04_parametros_dbeaver.sql` | os 4 parâmetros em `DPC_PARAMETRO`. **Antes do deploy do código** | sim (DML) |
| — | `99_rollback_dbeaver.sql` | desfaz as 13 tabelas e as 13 sequences. **Destrutivo** | sim |

Os dois primeiros são **reexecutáveis**: cada objeto é criado só se ainda não
existir. Falha no meio se resolve corrigindo e rodando de novo.

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
bloqueia por 1 hora — e o consumo é contado por **certificado e IP**, então o
bloqueio atinge todas as filiais que compartilham o e-CNPJ da matriz.

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

## 2. Base já instalada — um único arquivo

📄 `scripts/alteracoes/atualizacao_v7_a_v10_dbeaver.sql`, e depois o
`scripts/04_parametros_dbeaver.sql`.

Os quatro scripts de estrutura (`v7` a `v10`) foram **unificados em 02/09/2026**.
Cada um segue recuperável no histórico do git da ApiNFE:

| Seção | O que acrescenta | vinha de | commit |
|---|---|---|---|
| 1 | `DPC_DFE_NOTA_ITEM` — os itens da NF-e | `v7` | `1bdc4a7` |
| 2 | `NOTA.SIG_PAPEL_EMPRESA` — o papel da empresa na nota | `v8` | `ede36cc` |
| 3 | `NOTA.VLR_TOTAL_PRODUTO` — o `vProd` do `ICMSTot`, para a conferência comparar grandezas iguais | `v9` | `1bdc4a7` |
| 4 | `DPC_DFE_CTE_EVENTO` — trouxe 2.853 eventos, o comprovante de entrega e **20 CT-e cancelados** (R$ 26.796,56) que passavam por válidos | `v10` | `77771bc` |

O antigo `v11` **não está aqui**: virou [`04_parametros_dbeaver.sql`](#qual-caminho-usar),
porque os dois caminhos de instalação precisam dele.

Tudo já aplicado em **tst**; em **prd** nada disto rodou (as tabelas `dpc_dfe_*`
não existem lá).

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
