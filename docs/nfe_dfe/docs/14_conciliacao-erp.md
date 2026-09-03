# Conciliação com o ERP — a outra metade da feature

> **Frente em andamento, aberta em 02/09/2026.** Documento separado de propósito
> enquanto o desenho não assenta. Quando fechar, o que for conhecimento
> permanente migra para [03_conhecimento-motor.md](03_conhecimento-motor.md) e
> este arquivo vira registro.
>
> Marcas de confiança, como nos documentos vivos: 🟢 normativo · 🔵 medido ·
> 🟡 hipótese · 🔴 derrubado.

---

## 1. O problema

O motor captura da SEFAZ e sabe dizer o que existe. Não sabe dizer **o que já
entrou no nosso ERP** — então toda nota aparece como se tivesse vindo só da
SEFAZ, mesmo depois de lançada.

O ERP é a **Consinco**, sistema terceiro. **Não temos API**: as tabelas do
schema `consinco` são a única fonte.

## 2. A etapa não está num campo — está em qual tabela a nota aparece

🔵 Este é o achado que define todo o resto. Os campos de status das três
famílias são **degenerados** nas nossas notas: `mlf.statusnf` = `V` nas 444,
`mlf.statusnfe` **nulo** em todas, `rf.codsitdoc` = `0` em todas. Não há o que
ler deles.

| Onde a nota está | Significa | Tabelas |
|---|---|---|
| em nenhuma | ainda não digitada | — |
| digitada, **não** liberada | em recebimento | `mlf_auxnotafiscal` + `mlf_auxnfitem` |
| recebimento finalizado | liberada | `mlf_notafiscal` + `mlf_nfitem` |
| escriturada | fiscal | `rf_notamestre` + `rf_notaitem` |

## 3. O cenário real

🔵 815 notas capturadas, cruzadas com a Consinco de **produção** em 02/09/2026:

| Estado | Qtd | % |
|---|---|---|
| `ESCRITURADA` | 738 | 90,6% |
| `AGUARDANDO_XML` (resumo, sem XML completo) | 47 | 5,8% |
| `AGUARDANDO_ENTRADA` | 29 | 3,6% |
| `EM_DIGITACAO` | 1 | 0,1% |
| `RECEBIDA` | **0** | — |

**`RECEBIDA` não aparece isolada.** Toda nota em `mlf_notafiscal` já está em
`rf_notamestre` — a janela entre receber e escriturar é curta demais para um
snapshot pegar. O estado fica assim mesmo, porque custa nada e captura o
transiente, mas não esperar volume nele.

🔵 **Atraso de lançamento** (emissão → escrituração), 738 notas: mediana **1
dia**, média 1,8, máximo 74.

## 4. Os dois defeitos que existem hoje, e são independentes

| Onde | Defeito | Tamanho |
|---|---|---|
| Tela — `SefazDocumentosFiscaisRepository::casStatus()` | o `CASE` não tem ramo para "lançada **e** classificada". O caso mais comum não casa com nenhum `WHEN` e cai no `ELSE`, que devolve `AGUARDANDO_ENTRADA` | 🔵 **445 de 768** (58%) rotuladas errado. `EM_RECEBIMENTO` e `CLASSIFICACAO_PENDENTE` nunca dispararam |
| Motor — `dfe:conciliar` | a janela `--dias=90` é sobre `dta_emissao`: nota que entra no ERP depois de 90 dias da emissão fica `N` **para sempre** | 🔵 61 falsos negativos, 60 deles fora da janela |

Prova do primeiro, em notas reais lançadas em 25/07:

```
nro_nf=201984  emissão 24/07  lançada 25/07  seqnota=27671999  cfop=2152
   tela: AGUARDANDO ENTRADA        motor: S (já conciliada)
```

Os dois respondem a mesma pergunta de formas diferentes e discordam — o motor lê
só `mlf_notafiscal`, a tela lê as três.

## 5. 🔴 O print que abriu a frente não mostrava o bug

A imagem mostrava a empresa 30, período 01–10/08, com **0 registradas no ERP** e
61 pendentes. A leitura natural — "a tela está quebrada" — está errada.

Rastreei a chave `50260818332251000309550010000106761065350514`:

| Onde | Resultado |
|---|---|
| Consinco de **homologação** | não existe, em nenhuma das três, nem por chave nem por número |
| Consinco de **produção** | `mlf_notafiscal` seqnf 43457077 · `rf_notamestre` seqnota 28004974, `E`, lançada **27/08/2026** |

🔵 O clone de homologação tem lançamento da empresa 30 só até **25/07/2026**,
enquanto a captura vai até 02/09. Em homolog, "Aguardando Entrada" para uma nota
de agosto é **aritmeticamente correto** — falta o dado, não a lógica.

O bug do `ELSE` é real e independente: aparece se você filtrar julho.

## 6. ⚠️ As tabelas do ERP que valem ficam em PRODUÇÃO, sempre

Consequência de arquitetura, e é o requisito que decide o desenho:

> **A tela não pode cruzar com o ERP em SQL.** O `OUTER APPLY` contra
> `consinco.*` só alcança o schema da **mesma conexão**. Com as `dpc_dfe_*` em
> homolog e a verdade em prd, o cruzamento tem de ser feito **em código, com
> duas conexões**, e o resultado **materializado**.

O `dfe:conciliar` já é capaz disso sem saber: o `buscaNoErp()` traz um mapa e
casa em PHP, em vez de fazer join. Em produção as duas pontas ficam no mesmo
banco e nada muda; a conexão do ERP é parametrizável.

**Alerta operacional:** um job de 30 em 30 minutos rodando de homologação gera
leitura recorrente no banco de **produção**. Desenho conservador: lista de
chaves em lote sobre a coluna indexada `NFECHAVEACESSO`, teto por execução.

## 7. 🔵 434 de 443 chaves aparecem como entrada **e** como saída

Transferência entre filiais: a mesma NF-e é saída numa empresa nossa e entrada
em outra. Por isso o casamento **precisa** filtrar `entradasaida = 'E'` **e**
`nroempresa`. Sem os dois, a entrada casa com a linha de saída da filial
vizinha.

Medido: casar só por chave nunca divergiu de casar por chave+empresa nesta base
(0 casos) — mas isso é sorte da amostra, não garantia.

## 8. O desenho

### Por que materializar, e não corrigir a tela

| | Corrigir só a tela | Materializar no motor |
|---|---|---|
| Corrige as 445 | sim | sim |
| Funciona com ERP em outro banco | **não** | sim |
| Detecta regressão | **não** — cálculo ao vivo só enxerga o agora | sim |
| Custo por acesso | `OUTER APPLY` em `rf_notaitem`→`map_produto`→`max_comprador` a cada carga | leitura de coluna |
| Fontes da verdade | continuam duas | uma |

### Os quatro estados, e a regressão

Avaliado **de baixo para cima**, porque 443 notas estão em `mlf` **e** `rf` ao
mesmo tempo:

| Ordinal | Estado | Detecção |
|---|---|---|
| 3 | `ESCRITURADA` | `rf_notamestre`, `entradasaida='E'`, `codsitdoc` válido |
| 2 | `RECEBIDA` | `mlf_notafiscal` |
| 1 | `EM_DIGITACAO` | `mlf_auxnotafiscal` |
| 0 | `AGUARDANDO_ENTRADA` | nenhuma das três |

**Regressão** = o atual ficou **abaixo** do maior já atingido. Guardado em duas
colunas, sem tabela de histórico:

```
num_estado_erp  <  num_estado_erp_max     ->  regrediu, e de onde
```

Uma nota aqui significa que uma etapa foi **desfeita** no ERP — digitação
excluída antes de liberar, ou escrituração cancelada. Não é erro nosso: é
informação.

### A janela

Sai o `--dias=90`. Passa a reconsultar toda nota que ainda não chegou em
`ESCRITURADA`, **sem limite de idade** — decisão do negócio: pendente para
sempre.

⚠️ **Não escala como está.** Hoje são 815 notas; com 13 CNPJs a ~850 NF-e/dia
serão ~11 mil/dia. Reconsultar todas as não-finalizadas para sempre cresce sem
teto. Proposta: cadência decrescente — nota nova a cada ciclo, nota com mais de
30 dias uma vez por dia.

### Devolução

Confirmado com o usuário: **é o cliente que emite**. Então ela chega para nós
pelo DistDFe como entrada, **está no escopo**, e é justamente ela que deve
aparecer em `mlf_auxnotafiscal` — dando vida ao `EM_DIGITACAO`, que hoje tem 1
ocorrência.

## 9. Onde está

| Item | Estado |
|---|---|
| `v12_estado_erp_dbeaver.sql` — 6 colunas + 2 constraints | ✅ **executado no DBeaver** em tst · prd: as tabelas do módulo não existem lá ainda |
| `v13_categoria_comprador_erp_dbeaver.sql` — 4 colunas + 1 índice | ✅ **executado no DBeaver** em tst · prd: idem |
| Parâmetro `dfe_conexao_erp` = `oracle` (produção) | ✅ tst |
| `DfeConciliacaoRepository` — três famílias, conexão parametrizável, cadência | ✅ |
| `dfe:conciliar` — quatro estados e regressão | ✅ rodado: **784 escrituradas, 30 aguardando, 1 em digitação, 0 regressões** |
| `dfe:monitorar` — seção 6 pela escada, alerta de regressão | ✅ |
| Tela (ApiDPC) — status e KPI da coluna materializada | ✅ KPI passou de **0** para **784 registradas no ERP** |
| Tela (DPC) — rótulos e badges dos estados novos | ✅ `Main.vue` e `ModalVisualizarNota.vue` |
| `01_estrutura` + `estrutura_final.json` | ⏸ **a pedido: refletir depois de validado** |

### Os dois scripts passaram pelo `Alt+X`

Confirmado com o usuário em 03/09/2026: **ele executou os dois no DBeaver**, e não
apenas os pedacos que eu apliquei à mão para testar o SQL.

Isso prova mais do que a validez do SQL: prova que os arquivos atravessam o
**divisor de statements** do DBeaver. Era risco concreto, não teórico — foi
exatamente ali que o `v10` falhou com `PLS-00103`, por estar em LF. Como pista de
que rodaram inteiros, os 10 comentários de coluna estão no dicionário com o texto
idêntico ao dos scripts, e eu nunca executei aqueles `comment on column`.

Verificado no banco: 6+4 colunas, `CK4`/`CK5` **ENABLED**,
`DPCI_DFE_NOTA_COMPRADOR` **VALID** com as duas colunas na ordem certa. E a
`CK4` testada na prática — gravar `ESCRITURADA` com ordinal 0 foi barrado com
`ORA-02290`, sem deixar rastro.

### O que a validação provou

```
dfe:conciliar --dry-run --limit=15 --debug     (ERP na conexao: oracle)
   ESCRITURADA         NF 55/211408 | empresa 30 | emissao 2026-09-01
   AGUARDANDO_ENTRADA  NF  5/761086 | empresa 30 | emissao 2026-09-02
```

Notas emitidas **ontem e hoje** classificadas corretamente lendo produção a
partir de homologação — exatamente o que não funcionava.

### Nomes de constraint: `CK4` e `CK5`, não `CK3`

O `CK3` já existe em `DPC_DFE_NOTA` — é o do `sig_papel_empresa`. Descoberto ao
testar o script contra o banco, não por leitura. Nome de constraint colide em
silêncio até a hora do `alter`.

### As colunas nascem NULAS de propósito

`NULO` significa "ainda não conciliada", e é diferente de `AGUARDANDO_ENTRADA`,
que significa "conferido, e o ERP não tem". Preencher no `alter` seria afirmar
algo que não foi medido. A tela mostra `NAO_CONCILIADA` para esse caso.

## 10. A tela parou de ler o ERP por completo

Depois da v12 o **status** vinha da coluna, mas **categoria** e **comprador**
continuavam em `OUTER APPLY`. Isso mantinha o problema inteiro para eles: nao
atravessam conexao, entao vinham vazios — e vazio parecia dado (nota sem CFOP
cai em `SEM_CLASSIFICACAO`, que nao parece falha).

A **v13** materializa os dois, e os cinco `OUTER APPLY` sairam. O repositorio da
tela passou de 35.947 para 29.740 bytes e **nao le mais nada do Consinco**.

### Grava os insumos, nao a categoria

| Coluna | O que e |
|---|---|
| `cod_cfop_erp` | CFOP do item de maior valor |
| `dsc_ocorr_dev_erp` | `mlf.ocorrenciadev` — nao nulo vence o CFOP |
| `seq_comprador_erp` | o que a tela **filtra** |
| `dsc_comprador_erp` | nome, para exibicao |

A classificacao **nao** e gravada de proposito: as listas de CFOP sao regra de
negocio e mudam. Gravando os insumos, o `CASE` fica num lugar so e mudanca de
regra reclassifica tudo na hora, sem reprocessar acervo.

🔵 Backfill: **784 com CFOP, 783 com comprador** (1 legitimamente sem — a familia
do item nao tem divisao 1), 23 com `ocorrenciadev`. CFOP predominante: 2152 em
761 notas.

⚠️ **O CFOP 1411 esta nas listas de `DEVOLUCAO` e de `COMPRAS`.** A ordem
resolve (devolucao e testada primeiro), mas a ambiguidade e da regra, nao do
codigo. 22 notas nesse caso.

### O ultimo vinculo com o ERP tambem caiu

O filtro que exclui nota emitida por nos lia `consinco.ge_empresa.NROCGC`. Nao
precisava: o mesmo CNPJ esta em `dpc_dfe_empresa.num_cnpj`, que **e** a fonte
unica de identidade do modulo desde o `39b172d`.

### `--todas` passou a incluir as escrituradas

A v13 nasceu com as colunas nulas, e nota escriturada **sai da fila** da
conciliacao — nunca receberia CFOP. `--todas` derruba tambem esse filtro, e nao
so a cadencia. E o que permite as duas coisas que precisam do acervo inteiro:
preencher campo novo, e varrer regressao de proposito.

## 11. Os dois eixos, separados

`AGUARDANDO_XML` vencia tudo e **escondia a etapa no ERP**: 🔵 **46 notas
ESCRITURADAS** apareciam como "Aguardando XML" — verdade sobre a nossa captura,
irrelevante para quem cobra o lancamento.

| Pergunta | Onde aparece |
|---|---|
| onde esta no ERP? | coluna **Status** |
| temos o XML completo? | **icone ao lado da chave** |

Quem cuida de recebimento olha o status; quem cuida de captura olha o icone. Uma
coluna que responde duas coisas acerta uma.

## 12. O que a tela mostra agora

| | Antes | Agora |
|---|---|---|
| Registradas no ERP | **0** (no print) | **784** |
| Pendentes | 61 de 61 | **31** |
| Rotulo da linha | `AGUARDANDO_ENTRADA` em 445 de 768 | a etapa real |
| Pendencias por comprador | "Sem dados" | LUIZA MARIA RODRIGUES, 263 notas |
| Leituras no Consinco por carga de pagina | 5 `OUTER APPLY`, um deles com 4 joins | **zero** |

## 13. Aberto

| Questão | Situação |
|---|---|
| Cadência decrescente do re-check | proposta, não decidida |
| A tela precisa distinguir `RECEBIDA` de `ESCRITURADA`? | o negócio pediu os quatro estados; medido que `RECEBIDA` fica em 0 |
| Validação end-to-end | homologação **não consegue**: o ERP daqui para em 25/07 e a captura vai até 02/09. Dá para validar a lógica contra abril–julho; o comportamento com nota recém-entrada só se vê em produção |

---

Voltar ao [índice](readme.md) · motor: [03_conhecimento-motor.md](03_conhecimento-motor.md)
