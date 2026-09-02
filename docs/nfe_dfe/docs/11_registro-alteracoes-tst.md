# Registro de alterações no banco — teste ALL CARS

**Ambiente: `tst` (homologação) apenas.** Nada foi aplicado em produção.

Decisão que originou este registro: preservar o código da ApiNFE intocado e resolver tudo por dado no banco, revertendo no final. O repositório está idêntico ao PR #9.

## Alterações aplicadas

| # | Quando | Objeto | O que | Script | Revertido? |
|---|---|---|---|---|---|
| 1 | 10/08/2026 | `consinco.ge_empresa` | insert `nroempresa = 900` (ALL CARS) | `01_ge_empresa_tst.sql` | ☐ |
| 2 | 10/08/2026 | `consinco.ge_empresa` | update `seqcidade = 27081` na linha 900 | `01_ge_empresa_tst.sql` §1b | ☐ |
| 3 | 10/08/2026 | `poseidon.dpc_conta_certif_digital_emp` | insert `cod_certi_digital = 101`, `cod_empresa = 900` | `02_certificado_tst.sql` | ☐ |
| 4 | 10/08/2026 | `poseidon.dpc_dfe_empresa` | insert `nro_empresa = 900`, cursor 0 | `03_dfe_empresa_tst.sql` | ☐ |

Reverter com [99_rollback_tst.sql](../scripts/alteracoes/teste-all-cars/99_rollback_tst.sql).

## Validação — cadastro concluído em 10/08/2026

As 5 alterações estão aplicadas e o caminho até a SEFAZ está montado:

```
dev.cmd dfe:ingerir --empresa=900 --dry-run

  empresa 900 (CNPJ 45694407000102) | cursor=0 maximo=0 atraso=0
    [DRY-RUN] certificado ok (valido ate 11/03/2027 17:34:00), consultaria a partir do NSU 0
```

O que cada parte dessa saída prova:

| Evidência | Conclusão |
|---|---|
| a empresa apareceu como elegível | linha em `dpc_dfe_empresa` ok, status A, sem cooldown |
| `CNPJ 45694407000102` | `montacpfcnpj` devolvendo 14 dígitos — `ge_pessoa` resolveu |
| `certificado ok` | o PFX em base64 (NCLOB) foi lido e **a senha gravada por `dpcf_convertesenhas` está correta** |
| `valido ate 11/03/2027` | é o certificado da ALL CARS, não outro |
| `consultaria a partir do NSU 0` | cursor novo, como planejado |

Conferência do `montacpfcnpj` com a empresa 1 como controle:

| Empresa | CNPJ montado | Tamanho |
|---|---|---|
| 1 (controle) | 66471517000177 | 14 |
| 900 | 45694407000102 | 14 |

## Primeira chamada à SEFAZ — 10/08/2026 17:03, em HOMOLOGAÇÃO

```
dev.cmd dfe:ingerir --empresa=900 --max-consultas=1 --debug
  EM DIA. Nada novo (cStat 137). Proxima consulta em 60 min.
```

Resposta (`storage/logs/dfe-ingerir/20260810-170330-emp900-0-response.xml`):

```xml
<tpAmb>2</tpAmb><cStat>137</cStat><xMotivo>Nenhum documento localizado</xMotivo>
<ultNSU>000000000000000</ultNSU><maxNSU>000000000000000</maxNSU>
```

**O `maxNSU = 0` NÃO significa que a ALL CARS não tem movimento.** O `tpAmb 2` é homologação, e o Ambiente Nacional em homologação não tem documento de nenhum CNPJ. Comparação com a chamada da empresa 1 que trouxe documento real, no mesmo diretório de log:

| Arquivo | `tpAmb` | `cStat` |
|---|---|---|
| `20260806-191243-emp1-...` | **1** (produção) | 138 (documentos encontrados) |
| `20260810-170330-emp900-0` | **2** (homologação) | 137 (nada localizado) |

O que a chamada **provou**, ainda assim: TLS e SOAP fecham com o certificado da ALL CARS (segundo certificado que o motor usa), o `distDFeInt` é aceito sem rejeição de schema, o `retDistDFeInt` é parseado e a máquina de estados classifica `EM_DIA` corretamente. Nenhum `656` — cursor 0 em CNPJ virgem é leitura legítima.

### Regra aprendida: o cursor é específico do ambiente

Um `ultNSU` obtido em produção não tem significado em homologação, e vice-versa. Se a homologação tivesse devolvido documentos e avançado o cursor, ao trocar de ambiente o cursor estaria contaminado — e reposicionar cursor é a causa conhecida do `656`.

Como veio `ultNSU 0`, o cursor continua em 0 e a troca é segura. **Nunca drenar o mesmo cursor em dois ambientes.**

## Alterações 6 e 7 — preparação para produção

| # | Quando | Objeto | O que | Onde | Revertido? |
|---|---|---|---|---|---|
| 6 | 10/08/2026 | `ApiNFE/.env` | `TIPO_AMBIENTE` de `2` para `1` | arquivo, não banco | ☐ |
| 7 | 10/08/2026 | `poseidon.dpc_dfe_empresa` | pausa (`status P`) em todas menos a 900, e limpa o cooldown da 900 | `05_preparar_producao_tst.sql` | ☐ |

O item 7 é tranca de segurança: com `TIPO_AMBIENTE=1`, um `dfe:ingerir` **sem** `--empresa` consultaria os CNPJs da DPC na SEFAZ de produção — o que não pode ocorrer enquanto a Qive estiver ativa. Pausar as linhas da DPC faz o esquecimento de uma flag deixar de ser incidente.

O item 6 é arquivo local (`.env` é gitignored), reverter é trocar `1` por `2`.

---

# RESULTADO DO TESTE — 10/08/2026 17:12

## Captura (`dfe:ingerir --empresa=900 --max-consultas=1 --debug`)

```
NSU 0..81 | cStat 138 | 16 docs (novos 16, repetidos 0)
EM DIA. Cursor alcancou o maximo (NSU 81).
```

Envelope: `tpAmb 1` (produção), `cStat 138 Documento(s) localizado(s)`, `ultNSU 81`, `maxNSU 81`.

A ALL CARS tem movimento **pequeno mas real**: 81 NSU no total, 16 documentos na janela de retenção. Uma única chamada esgotou o backlog.

Tipos recebidos — **os dois são nota, não evento**:

| `@schema` | Qtde |
|---|---|
| `resNFe_v1.01.xsd` | 8 |
| `procNFe_v4.00.xsd` | 8 |

## Normalização (`dfe:normalizar --empresa=900`)

```
Lidos: 16 | Notas: 16 (promovidas 8) | Eventos: 0 | Ignorados: 0 | Erros: 0
```

**Isto fecha a lacuna declarada no PR #9.** O caminho da nota nunca havia sido exercitado com documento real — os 50 documentos anteriores eram todos eventos.

O que ficou provado, cada item com evidência:

| Comportamento | Evidência |
|---|---|
| parser de `resNFe` | 8 notas INSERIDAS a partir do resumo |
| parser de `procNFe` | 8 notas PROMOVIDAS para `dsc_tipo_doc = 'procNF'` |
| **promoção resumo → completo** | a mesma chave entra como resumo (NSU 66) e é atualizada pelo completo (NSU 67) — a rotina antiga deixava a nota eternamente com dados do resumo |
| dedup de emitente por CNPJ | **7 emitentes para 8 notas**: as notas 55513 e 55514 são do mesmo fornecedor e reusaram `cod_dfe_emitente = 6` |
| tradução de situação | 8 de 8 com `cod_situacao = 1 / AUTORIZADA` |
| campos fiscais | modelo, série, número, valor, emissão, recibo e protocolo preenchidos em todas |
| 0 erros de interpretação | `Erros: 0` |

Variedade que o lote trouxe, e que o parser absorveu sem falha:

- série `890` com NF `52507961` (numeração fora do padrão pequeno)
- `tipo_nf = 0` numa das notas (as outras 7 são `1`)
- emitente MEI (`12.355.096 CLAYSON DOS REIS PEREIRA`)
- valores de `R$ 17,80` a `R$ 1.752,00`

## O que este teste NÃO cobre

- **Volume.** 16 documentos de 7 fornecedores de um ramo só (veículos/combustível/oficina). A DPC tem milhares de fornecedores em vários estados; variedade de layout de fornecedor só aparece com volume de verdade.
- **`resEve`/`procEv`** não vieram neste lote — o caminho de evento segue validado apenas pelos 50 documentos anteriores da empresa 1.
- **Manifestação** continua sem nunca ter sido enviada (por decisão).
- **O bloqueio de negócio.** As 27 empresas DPC seguem dependendo do corte com a Qive.

## Acervo permanente

Os 16 brutos estão em `dpc_dfe_documento` e podem ser renormalizados à vontade, sem SEFAZ:

```
dev.cmd dfe:normalizar --empresa=900              # reprocessa (idempotente)
dev.cmd dfe:normalizar --empresa=900 --status=E   # após corrigir algum parser
```

É o ganho central do desenho em duas etapas: os 90 dias de retenção deixaram de ser ameaça para esses documentos.

| 5 | 10/08/2026 | `consinco.ge_pessoa` | insert de PJ `456944070001 / 2`, `fisicajuridica = 'J'` | `04_ge_pessoa_tst.sql` | ☐ |

Verificado antes de escrever o item 5: **não existe** pessoa com esse CNPJ em `ge_pessoa`, em nenhum formato (busca por `nrocgccpf`, `nrocgccpf_bkp` e `nomerazao` — retorno vazio).

## Por que o item 5 foi necessário

`poseidon.montacpfcnpj` não formata CNPJ: ela consulta `consinco.ge_pessoa` para descobrir se é física ou jurídica. Sem pessoa cadastrada ela levanta `NO_DATA_FOUND`, que o Oracle converte em `NULL` quando a function é chamada de dentro de um `SELECT` — e o CNPJ nulo reprova na validação do `config.json` do sped-nfe.

### CORRIGIDO em 20/08/2026 — a ressalva abaixo estava errada

O que vem a seguir foi escrito a partir do **nome** das triggers, não do que elas
fazem. Medido no banco (`tst`, pessoa de teste `seqpessoa 312896`):

| O que eu afirmei | O que o banco diz |
|---|---|
| ~10 triggers de log/replicação gravaram no insert | a maioria é **UPDATE-only** e nunca disparou — inclusive `TAU_GE_PESSOA_EFDLOG_REG0175`, o log fiscal EFD/SPED, que era o item mais preocupante |
| `TAIU_GE_PESSOACADASTROLOG` e `TAD_RF_REINF_R2040_PESSOA` gravaram | **não existem** nesta tabela; foram listadas por suposição |
| o delete não desfaz o que as triggers escreveram | `TBD_GE_PESSOA` **limpa** 6 tabelas de log por `SEQPESSOA` |
| fica resíduo em log e replicação | resíduo real = **1 linha** em `ge_pessoacadastro`, e a FK dela (`SYS_C00172785`) é **ON DELETE CASCADE** — sai junto |
| `GE_LOGEXCLUIPESSOA` guarda registro da exclusão | só `IF :OLD.FISICAJURIDICA = 'F'`; a ALL CARS é `J`, então nem isso |

**A reversão é limpa.** Não há pressa criada por acúmulo de log — a razão para
reverter é apenas que as duas linhas não servem mais.

Risco que permanece, e que não foi possível descartar: **148 FKs** apontam para
`GE_PESSOA` com `delete_rule = NO ACTION` (contra 20 em `CASCADE`). Qualquer uma
com linha para a pessoa 312896 bloquearia o delete. Varrer as 148 excedeu o tempo
de consulta. Se vier **ORA-02292**, a mensagem nomeia a constraint — é por ela que
se descobre o que sobrou, e basta não commitar.

<details>
<summary>Texto original, preservado porque explica o raciocínio que levou ao erro</summary>

### Ressalva: `ge_pessoa` não é uma linha só

A tabela tem **~10 triggers** de insert/update, entre elas:

| Trigger | O que faz (pelo nome) |
|---|---|
| `TBIU_GE_PESSOA`, `TBIUD_GE_PESSOA`, `TAIUD_GE_PESSOA` | regras de negócio antes/depois |
| `TAIU_GE_PESSOALOG`, `TAIU_GE_PESSOACADASTROLOG` | gravam log em outras tabelas |
| `TAUD_AFV_GE_PESSOA` | replicação para a força de vendas |
| `TAU_GE_PESSOA_EFDLOG_REG0175` | log fiscal (EFD) |
| `TAD_RF_REINF_R2040_PESSOA` | REINF |

Consequência para o plano de reverter: **o `delete` da linha não desfaz o que as triggers escreveram em tabelas de log e de replicação** — e o próprio `delete` dispara mais triggers. Em homologação isso é tolerável, mas o "reverter no final" não fica 100% limpo nesse item, diferente dos itens 1 a 4.

Não há sequence aparente para `ge_pessoa.seqpessoa` (nenhum `S_GE_PESSOA`), então falta confirmar se alguma trigger preenche a PK ou se ela precisa ser informada.

</details>

### Detalhe que precisa se manter

`NROCGCCPF` foi gravado como `'456944070001'`, **igual** a `ge_empresa.nrocgc`. A function compara as duas strings sem normalizar (`VARCHAR2(13)` contra `VARCHAR2(15)`), então um zero à esquerda a mais em qualquer um dos lados quebra a busca mesmo com a pessoa existindo.

## Ordem de execução dos scripts

| Ordem | Script |
|---|---|
| 1 | `01_ge_empresa_tst.sql` |
| 2 | `02_certificado_tst.sql` |
| 3 | `03_dfe_empresa_tst.sql` |
| 4 | `04_ge_pessoa_tst.sql` |
| — | `99_rollback_tst.sql` (reverter tudo) |

## Histórico de obstáculos

Vale guardar, porque explica por que foram 5 alterações e não 3, e serve de argumento se a ALL CARS um dia precisar rodar em produção:

| Obstáculo | Sintoma | Causa |
|---|---|---|
| `SEQCIDADE` nulo | `Empresa 900 nao encontrada em consinco.ge_empresa`, com a linha existindo | `GeEmpresa::showAll` faz INNER JOIN com `ge_cidade` |
| CNPJ nulo | `[cnpj] Does not match the regex pattern ^[A-Z0-9]{11,14}` | `montacpfcnpj` consulta `ge_pessoa` e devolve NULL via `NO_DATA_FOUND` |

Os dois têm a mesma raiz: a rotina reaproveita um cadastro que pressupõe dado no formato do ERP, e a ALL CARS não é empresa do ERP. A alternativa (1 `if` em `DfeIngerir::montaSefaz` usando `dpc_dfe_empresa.num_cnpj`) resolveria os dois sem tocar em `consinco`, e foi descartada de propósito para preservar o código.

---

## Atualizacao 20/08/2026 — dois destes itens ficaram desnecessarios

O motor foi desacoplado da `consinco`: a identidade fiscal usada para montar o
`configJson` do sped passou a vir de `poseidon.dpc_dfe_empresa` (razao social, UF,
inscricao estadual, CNPJ), e nao mais de `consinco.ge_empresa` + `montacpfcnpj`.
Verificado por grep: nenhum arquivo do modulo `Dfe*` referencia `consinco.`,
`montacpfcnpj` ou `EmpresaRepository` — a unica excecao deliberada e o
`DfeConciliacaoRepository`, que existe **para** comparar com o ERP.

Consequencia direta para a reversao:

| Item | Script | Ainda necessario? |
|---|---|---|
| 1 | `01_ge_empresa_tst.sql` (`consinco.ge_empresa`) | **nao** — pode reverter |
| 2 | `02_certificado_tst.sql` (cofre de certificados) | **sim** — o PFX e lido dali |
| 3 | `03_dfe_empresa_tst.sql` (`poseidon.dpc_dfe_empresa`) | **sim** — passou a ser a fonte da identidade |
| 4 | `04_ge_pessoa_tst.sql` (`consinco.ge_pessoa`) | **nao** — pode reverter |

**Script para isso: `06_reverter_consinco_all_cars_tst.sql`** — estreito de
proposito. NAO use o `99_rollback_tst.sql`, que apaga tambem o certificado, o
cadastro em `dpc_dfe_empresa` e todo o acervo capturado (as 8 NF-e e as 15 NFS-e
que hoje sao a unica massa real de validacao do motor).

> O `99` tambem estava **defasado**: escrito antes do `alter_v2`, nao apagava
> `dpc_dfe_cursor`, `dpc_dfe_cte`, `dpc_dfe_cte_nfe` nem `dpc_dfe_nfse`. Como
> `DPC_DFE_CURSOR_FK1` aponta para `dpc_dfe_empresa` e `DPC_DFE_DOCUMENTO_FK2`
> aponta para o cursor, rodar a versao antiga hoje falharia com ORA-02292 no meio
> da transacao. Corrigido em 20/08/2026, junto com a nota de que
> `status_sincronismo` mudou de tabela no `alter_v2`.

Os itens 1 e 4 eram exatamente os dois que existiam para contornar
`SEQCIDADE` nulo e `montacpfcnpj` devolvendo NULL. Some a dependencia, somem os
dois contornos — e com eles o unico item cuja reversao nao era limpa (o `delete`
em `ge_pessoa` dispara ~10 triggers e nao desfaz o que elas gravaram em log e
replicacao). Reverter agora, enquanto o volume de log e pequeno, e melhor que
reverter depois.

> A alternativa registrada acima ("1 `if` em `DfeIngerir::montaSefaz` usando
> `dpc_dfe_empresa.num_cnpj` resolveria os dois sem tocar em `consinco`, e foi
> descartada de proposito") **deixou de ser alternativa**: foi o caminho adotado,
> por decisao de nao permitir leitura da `consinco` no motor. O paragrafo fica
> como registro do que se sabia antes.

## Alteracoes de DDL do proprio modulo

Nao entram na tabela acima porque nao sao dado de teste: sao a estrutura do
modulo, versionada em `workspace/.claude/docs/nfe_dfe/scripts/` com
`rollback_dbeaver.sql` proprio.

| Script | Rodado em | O que fez |
|---|---|---|
| `install_dbeaver.sql` | 06/08/2026 | 7 tabelas iniciais |
| `alter_v2` a `alter_v4` | 19/08/2026 | cursor por tipo, conciliacao, `seq_nf_erp`/`dta_entrada_erp` |
| `alter_v5_cte` | 19/08/2026 | `dpc_dfe_cte` + `dpc_dfe_cte_nfe` |
| `alter_v6_nfse` | **20/08/2026** | `dpc_dfe_nfse`; `NFSE` no check do cursor; `chave_nf` de 44 -> 50; 14 cursores `NFSE` pausados |

---

## Execução da reversão — 20/08/2026

| Item | Script | Resultado |
|---|---|---|
| 1 — `consinco.ge_empresa` (900) | `06` | **revertido** |
| 4 — `consinco.ge_pessoa` | `06` | **bloqueado** — ver abaixo |
| 2 — certificado | — | mantido (intencional) |
| 3 — `poseidon.dpc_dfe_empresa` | — | mantido (intencional) |

Conferido: certificado, cadastro, 31 documentos, 15 NFS-e, 8 notas e 4 cursores da
empresa 900 **intactos**; empresa 30 não tocada.

### O bloqueio não é FK, é índice inutilizável

```
ORA-01502: index 'CONSINCO.XPKMFL_DOCTOFISCAL' is in unusable state
```

Obtido rodando o delete em transação com `ROLLBACK`, só para capturar a mensagem.

- Os **25 índices** de `consinco.MFL_DOCTOFISCAL` estão `UNUSABLE` — e 25 é o total
  da tabela. Assinatura de `ALTER TABLE ... MOVE` ou carga direct-path sem rebuild.
- Três FKs apontam de `MFL_DOCTOFISCAL` para `GE_PESSOA` (`SEQPESSOA`,
  `SEQPAGADOR`, `SEQTRANSPORTADOR`), todas `NO ACTION`. Apagar a pessoa exige que o
  Oracle **verifique** que nenhum documento fiscal a referencia, e a verificação
  precisa de um índice que está quebrado.
- A pessoa de teste tem **0** linhas em `MFL_DOCTOFISCAL` (contado com hint de full
  scan). O delete é logicamente válido — está barrado por infraestrutura.
- **Produção está sã:** os mesmos 25 índices estão `VALID`, e o schema `CONSINCO`
  inteiro tem zero índice inutilizável em prd. É exclusivo de homologação.

### Causa raiz — a primeira hipótese estava errada

Escrevi acima "manutenção no clone de homologação", pela coincidência com a queda de
rede do `tst`. **A equipe confirmou que o banco não está em manutenção**, e a
apuração mostrou outra coisa:

`consinco.MFL_DOCTOFISCAL` é **particionada** (51 partições mensais) e **todos os
seus 25 índices são GLOBAIS**. Índice global fica `UNUSABLE` quando se executa DDL
de partição **sem `UPDATE GLOBAL INDEXES`** — é a única causa que explica os 25 de
uma só vez.

> Eu tinha lido `particionado=NO` no índice e descartado essa linha de investigação.
> Aquele `NO` é o atributo do **índice** (global = não particionado), não da tabela.
> A tabela é particionada, e é justamente essa combinação que produz o problema.

O que a evidência **descarta**:

| Hipótese | Evidência contra |
|---|---|
| `DROP PARTITION` | tst e prd têm as **mesmas 51 partições**, mesmos nomes, nenhuma faltando |
| `TRUNCATE` / perda de dado | tst tem **19.590.775 linhas reais** (full scan); a estatística de prd aponta 19.662.804 — diferença compatível com o movimento desde o clone |
| manutenção em curso | confirmado pela equipe que não há |
| problema em produção | prd tem os 25 `VALID` e zero índice inutilizável no schema inteiro |

O que sobra: **operação de partição que preserva conteúdo** — tipicamente
`ALTER TABLE ... MOVE PARTITION` (reorganização ou troca de tablespace) — ou alguém
ter marcado os índices `UNUSABLE` de propósito para acelerar uma carga e não ter
feito o rebuild.

**Não foi possível determinar quando.** O `last_ddl_time` dos índices está espalhado
entre 2022 e 2026 porque registra a última criação/rebuild de cada um, não a mudança
de status. Datar o evento exige alert log ou trilha de auditoria — acesso de DBA.

### O que importa mais que o rebuild

Toda DDL de partição nessa tabela precisa de **`UPDATE GLOBAL INDEXES`**. Sem isso os
25 quebram de novo, e do mesmo modo silencioso: nada falha na hora da operação, só a
próxima gravação — que pode ser semanas depois, como foi aqui.

### Encaminhamento

1. `07_rebuild_indices_mfl_doctofiscal_tst.sql` — rebuild dos 25 índices, únicos
   primeiro. Tarefa de DBA.
2. Reexecutar a seção 3 do `06`.

Sem pressa: a linha remanescente é inofensiva, porque o motor não lê mais a
`consinco` para identidade fiscal.

> **Alcance maior que esta reversão:** enquanto os índices estiverem `UNUSABLE`,
> **qualquer** `insert`/`update`/`delete` em `consinco.MFL_DOCTOFISCAL` falha em
> homologação. Quem estiver testando módulo fiscal por lá vai bater no mesmo erro.
