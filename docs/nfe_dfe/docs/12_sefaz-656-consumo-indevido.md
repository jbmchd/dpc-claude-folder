# NFeDistribuicaoDFe — cStat 656 na captura de NF-e de entrada

Registro técnico da implantação da captura própria de NF-e de entrada na ApiNFE.

> ## ⚠️ Conclusão principal
>
> **Não é possível rodar a captura própria em paralelo com a Qive.**
>
> As duas consultam o mesmo `NFeDistribuicaoDFe` dos mesmos CNPJs, cada uma com seu próprio cursor. Para a SEFAZ isso é **consumo indevido** — é uma das causas documentadas do `cStat 656`: *"múltiplas aplicações do mesmo ator consultando o mesmo CNPJ fora de ordem"*.
>
> Isso invalida o plano de transição, que previa operar os dois em paralelo e reconciliar antes do corte. **A migração precisa ser um corte seco.**

**Situação:** **três** causas identificadas, atuando em conjunto:

| | Causa | Estado |
|---|---|---|
| §1–3 | violação da regra do `ultNSU` — nossa | **corrigida** |
| §4 | coexistência com a Qive | estrutural, decisão de negócio: corte seco |
| §7 | **NF-e no fim da fila** — 656 na consulta sem documento novo, independente do intervalo. Atinge QUALQUER CNPJ, e o CT-e não sofre disso | **contornado em parte, decisão em aberto para a virada** |

Em 01/09/2026 foram corrigidos ainda dois defeitos nossos que produziam 656 e
não eram nenhuma das três causas acima: o cooldown que nunca segurava consulta
(fuso da sessão Oracle contra coluna `TIMESTAMP` sem fuso) e a rajada entre
fluxos do mesmo certificado no mesmo ciclo. Ambos em `feature/dfe-trava-execucao-manual`.

**Data:** 08/08/2026 · **Ambiente:** produção (`tpAmb = 1`)
**Serviço:** `NFeDistribuicaoDFe`, Ambiente Nacional · `distDFeInt` 1.01 / `NFe` 4.00
**Biblioteca:** `nfephp-org/sped-nfe` ^5.0 (PHP 8.2)

---

## 1. A regra, em uma frase

> **O `ultNSU` não é um número que o integrador escolhe. É um token que a SEFAZ devolve e que só pode ser continuado.**

Enviar qualquer outro valor — `0` depois de já ter recebido um `ultNSU`, ou um NSU real obtido por `consChNFe` — é tratado como **consumo indevido** e bloqueia o certificado por 1 hora.

A própria SEFAZ diz isso no retorno, e nós demoramos a ler:

```
cStat   656
xMotivo Rejeicao: Consumo Indevido (Deve ser utilizado o ultNSU nas
        solicitacoes subsequentes. Tente apos 1 hora)
```

---

## 2. Cronologia que levou ao diagnóstico

Todas as chamadas foram manuais, uma a uma, sem laço automático.

| # | Data/hora | CNPJ | `ultNSU` enviado | Resultado |
|---|---|---|---|---|
| 0 | 06/08 19:12 | 0001-77 | `consChNFe` | **138** — documento localizado (NSU 10.882.953) |
| 1 | 06/08 15:21 | 0001-77 | **0** *(primeira consulta)* | **138** — 50 docs, devolveu `ultNSU=10258514` |
| 2 | 06/08 15:24 | 0001-77 | **0** ❌ | **656** |
| 3 | 07/08 11:21 | 0008-43 | **0** ❌ | **656** |
| 4 | 07/08 17:09 | 0003-39 | **0** ❌ | **656** |
| 5 | 08/08 09:14 | 0001-77 | **10882953** ❌ | **656** |
| 6 | 08/08 10:20 | 0001-77 | **10258514** ✅ | **138** — 50 docs, cursor → 10.277.494 |

A chamada #6 usou o `ultNSU` correto e funcionou de primeira, após 4 rejeições.

### Por que cada uma falhou

- **#2** — o cursor tinha sido reposicionado manualmente para `0`, numa tentativa de recuperar documentos de um lote que falhou ao gravar no banco local (bug nosso, `ORA-01465`, já corrigido). O valor correto era `10258514`.
- **#3 e #4** — consultas com `ultNSU=0` naqueles CNPJs. Rejeitadas. Ver a retratação logo abaixo: a leitura original disse que isto provava cota por certificado, e não prova.
- **#5** — usou um NSU real, mas obtido por `consChNFe`. Não era o `ultNSU` do fluxo. Rejeitada.

> ### 🔴 RETRATAÇÃO — 12/09/2026: #3 e #4 não provam cota por certificado
>
> O texto anterior dizia: *"primeiras consultas daqueles CNPJs, com `ultNSU=0`,
> que seria legítimo. Rejeitadas mesmo assim. **Isso indica que o controle é por
> certificado, não por CNPJ**"*.
>
> **Não eram primeiras consultas.** Os CNPJs `0008-43` e `0003-39` estão entre os
> 12 atendidos pela **Qive**, que já vinha consultando o `DistDFe` deles havia
> meses. O cursor deles **na SEFAZ** estava muito além de zero. Mandar `0` ali
> não é começo legítimo: é *consultar fora da sequência*, que é a segunda causa
> de 656 da NT 2014.002, item 3.11.4.1.
>
> A explicação estava neste mesmo documento, na Conclusão principal: "as duas
> consultam o mesmo `NFeDistribuicaoDFe` dos mesmos CNPJs, cada uma com seu
> próprio cursor". O documento se contradizia e ninguém notou por um mês.
>
> A NT é explícita no sentido oposto ao que foi concluído: *"o **CNPJ** é
> bloqueado por 1 hora"*, e *"para o mesmo **CNPJ (14 dígitos – informado na
> requisição xml)**"*. A palavra `IP` **não aparece nas 18 páginas**.
>
> Consolidado em [02_conhecimento-sefaz.md §5](02_conhecimento-sefaz.md).

### Hipóteses testadas e descartadas

| Hipótese | Como foi descartada |
|---|---|
| Frequência excessiva | intervalos de 6 a 20 h entre tentativas, 1 chamada cada |
| ~~Cota por CNPJ~~ | ~~3 CNPJs distintos, todos rejeitados~~ — **descarte inválido**, ver a retratação acima: os três tinham cursor avançado pela Qive, então `0` era fora de sequência em todos. A NT diz que a cota **é** por CNPJ |
| Repetição de requisição idêntica | #5 usou faixa nunca solicitada e ainda assim falhou |
| Cursor em zero especificamente | #5 usou valor alto e falhou; #1 usou zero e funcionou |
| Certificado vencido | vigente até 20/10/2026 |
| Bloqueio ativo na SEFAZ | #6 funcionou sem nenhuma intervenção externa |

---

## 3. Consequências no código

| Ajuste | Onde |
|---|---|
| `--reposicionar-cursor` recusa valor diferente do `ultNSU` recebido; exige `--confirmar` para forçar | `DfeIngerir::modoReposicionarCursor()` |
| Referência do último `ultNSU` obtida da trilha de execuções | `DfeExecucaoRepository::ultimoNsuRecebido()` |
| `CURSOR_TRAVADO` deixou de sugerir reposicionamento manual — não há saída conhecida | `DfeIngerir::drenaEmpresa()` |
| `cStat 656` aplica espera a **todas** as empresas do domínio — mais largo do que a NT exige (lá o bloqueio é do CNPJ), mantido enquanto a anomalia da empresa 30 não for explicada | `DfeCursorRepository::agendaEsperaGlobal()` |
| Freio de emergência: recusa consultar acima de N bloqueios em 24 h | `dfe_max_bloqueios_dia`, em `POSEIDON.DPC_PARAMETRO` |

---

## 4. A segunda causa: coexistência com a Qive

Depois de corrigir a regra do `ultNSU`, uma chamada com o cursor **correto** (`10277494`), 36 minutos após a bem-sucedida, foi rejeitada com 656 mesmo assim. Isso mostrou que o `ultNSU` era condição necessária, não suficiente.

A busca em bases de conhecimento de provedores trouxe a lista de causas do 656 ([NS Tecnologia](https://blog.nstecnologia.com.br/regras-de-consumo-indevido-para-dfe/)):

1. Uso indevido da tag `distNSU`
2. Continuar consultando após `cStat 137` dentro de 1 hora
3. **Não consultar os NSU sequencialmente (ignorar o `ultNSU`)** ← nossa causa nº 1, corrigida
4. **Múltiplas aplicações do mesmo ator consultando o mesmo CNPJ fora de ordem** ← nossa causa nº 2
5. Exceder 20 consultas/hora em consulta por chave ou NSU

A causa 4 descreve exatamente a situação da DPC: a **Qive** consulta os mesmos CNPJs, com cursor próprio. Somos um segundo consumidor do mesmo fluxo.

Isso explica o que nenhuma hipótese de ritmo explicava — **o resultado dependia de quando a Qive havia consultado**, algo fora do nosso controle. Daí a aparência errática: mesma configuração, resultados diferentes.

### Limites documentados (para referência)

| Regra | Valor |
|---|---|
| Lote máximo por `distNSU` | 50 documentos |
| Após `cStat 137` (nada novo) | esperar 1 hora |
| `consChNFe` / `consNSU` | 20 consultas por hora |
| Duração do bloqueio por 656 | 1 hora, desbloqueio automático |
| Intervalo mínimo entre `distNSU` **com** documentos | **não especificado em nenhuma fonte** |

### O que continua desconhecido

**Procedimento de retomada quando o cursor aponta para faixa expurgada.** Se a SEFAZ não avançar o `ultNSU` e a retenção de 90 dias já tiver descartado aquela faixa, não há caminho documentado — e reposicionar por conta própria gera 656.

---

## 5. Perguntas que permanecem para a SEFAZ

Não bloqueiam o desenvolvimento, mas afetam o dimensionamento e o plano de transição.

**1. O controle de consumo é por CNPJ, por certificado digital ou por IP?**
As filiais da DPC usam o certificado da matriz e saem do mesmo servidor. As rejeições #3 e #4 sugerem controle por certificado. Precisamos saber se as 12 empresas disputam uma única cota — isso define se a drenagem pode ser paralelizada.

**2. Confirmação sobre coexistência de sistemas.**
Fontes de provedores indicam que múltiplas aplicações consultando o mesmo CNPJ caracterizam consumo indevido — e nossos testes são consistentes com isso. Vale confirmar com a SEFAZ e definir com a Qive uma **janela de corte**: data e hora em que ela para de consultar e nós assumimos, sem sobreposição.

Uma pergunta prática decorrente: ao assumir, qual `ultNSU` usar? O cursor da Qive está com ela. Se a SEFAZ tratar `0` como indevido para um CNPJ já consultado, precisamos saber como iniciar.

**3. Se o cursor for perdido ou apontar para faixa já expurgada, como retomar?**
Reenviar `0` é tratado como consumo indevido quando o certificado já recebeu um `ultNSU`. Não localizamos alternativa documentada.

---

## 6. Estado atual da implantação

```
empresa 1 (66.471.517/0001-77)
   cursor    10.277.494
   maxNSU    11.072.706
   atraso       795.212 NSU

50 documentos capturados e normalizados, 0 erros
   32 procEventoNFe + 18 resEvento -> 50 eventos, todos orfaos
   (sao eventos de notas emitidas pela propria DPC; ficam guardados
    com a chave e serao religados se a nota entrar na base)
```

O `maxNSU` subiu de 11.053.596 para 11.072.706 entre a manhã e a tarde de 08/08 — cerca de **19 mil NSU em poucas horas**. Isso dá a ordem de grandeza do fluxo diário da matriz e mostra que o atraso não é estático: a drenagem precisa ganhar do ritmo de entrada.

Certificados: **3 de 12** utilizáveis (7 expirados em 13/11/2025, 2 com senha incorreta no banco). Pendência de cadastro, não de código.

## 7. A terceira causa: NF-e no fim da fila — **ABERTO, decidir na virada**

> ## 🔴 RETRATAÇÃO — 02/09/2026
>
> **A taxa desta seção estava contaminada por um defeito nosso.** Boa parte dos
> 656 medidos de 28 a 31/08 não era comportamento da SEFAZ: era o motor
> consultando **15 minutos** depois de ter sido mandado esperar uma hora.
>
> Olhando o que veio *imediatamente antes* de cada bloqueio:
>
> ```
> 30/08 05:45  emp 30  anterior=EM_DIA  0 docs   15 min antes  -> 656
> 30/08 06:00  emp 30  anterior=656     0 docs   15 min antes  -> 656
> 31/08 03:15  emp 30  anterior=EM_DIA  0 docs   15 min antes  -> 656
> 31/08 03:30  emp 30  anterior=656     0 docs   15 min antes  -> 656
> 31/08 05:00  emp 30  anterior=EM_DIA  0 docs   15 min antes  -> 656
> ```
>
> `EM_DIA` grava "espere 60 minutos". A execução seguinte do mesmo fluxo vinha no
> ciclo seguinte do cron — era o bug de fuso do `dta_liberado_em`, corrigido em
> `19c7b25` (31/08 19:02). O corte na série é exato: repetições de 15 minutos
> **todos os dias** antes do commit, **zero** depois (intervalos passam a 150,
> 181, 314, 688, 855 min).
>
> **O que cai:**
> - a taxa de "~2,5/dia por fluxo em operação normal";
> - a projeção de "~32/dia com 13 CNPJs", que multiplicava aquela taxa;
> - o argumento de que o freio global precisa virar freio por fluxo. A premissa
>   caiu; remedir com dado limpo antes de mexer.
>
> **O que fica de pé:**
> - o eixo do gatilho é o **serviço**: em 02/09, dos 33 bloqueios da base,
>   **33 são NFE e 0 são CTE** — e o CT-e teve 32 execuções e 5.031 documentos
>   no mesmo período;
> - ~~o eixo da cota é o **certificado + IP**~~ — **caiu em 12/09/2026**: a NT
>   2014.002 v.1.40 diz **CNPJ de 14 dígitos**, e "IP" não aparece no documento.
>   Ver a retratação da seção 2;
> - ~~**CNPJ ocioso devolve 656 com espera respeitada**~~ — **enfraquecido em
>   12/09/2026.** Continua verdade para a empresa 900 e para a 30, mas **não é
>   geral**: a empresa 29, em dia e com o mesmo certificado, fez **19 execuções
>   sem um bloqueio** entre 11 e 12/09, sete delas voltando vazias com `cStat
>   137` — a resposta normativa. O fenômeno existe, mas é de **alguns** CNPJs, e
>   a causa não está caracterizada. Ver
>   [02_conhecimento-sefaz.md §5.1](02_conhecimento-sefaz.md).
>
> O restante da seção fica como estava, **para registro do raciocínio** — inclusive
> porque a medição de 8 pontos consecutivos de 01/09 continua válida como
> evidência do eixo por serviço. Leia sabendo que os números de taxa foram
> revistos. Consolidado atual: [02_conhecimento-sefaz.md §5](02_conhecimento-sefaz.md).


> **Correção de enquadramento, 01/09/2026 20:30.** Esta seção nasceu chamando o
> problema de "CNPJ ocioso", a partir da ALL CARS. Medição posterior mostrou que
> o eixo é **o serviço, não o CNPJ** — e que atinge a empresa 30, que é a que
> importa. Ver "O que derrubou o enquadramento inicial", logo abaixo.

**Medido em 01/09/2026, em produção.** Não é hipótese: são 8 pontos consecutivos.

> **Anotado a pedido para ser resolvido quando o motor estiver todo testado.**
> Está **contornado**, não corrigido. Volta a morder se algum dos 12 CNPJs da
> Qive tiver pouco ou nenhum movimento.

### O que foi medido

Fluxo NF-e da empresa **900 (ALL CARS, 45.694.407/0001-02)**, cursor parado em
NSU 87 — fim da fila, CNPJ sem movimento fiscal:

| Quando | Intervalo | Resultado |
|---|---|---|
| 01/09 04:30 | — | `EM_DIA` (137) |
| 01/09 05:45 | 75 min | **656** |
| 01/09 07:00 | 75 min | `EM_DIA` |
| 01/09 08:15 | 75 min | **656** |
| 01/09 10:07 | 112 min | `EM_DIA` |
| 01/09 11:16 | 69 min | **656** |
| 01/09 14:15 | 179 min | `EM_DIA` |
| 01/09 16:30 | 134 min | **656** |

Sequência: `. X . X . X . X`

### A conclusão que os dados forçam

**Não é regra de tempo.** Com **179 minutos passou** e com **134 minutos
falhou** — o oposto do que um limite temporal produziria. Aumentar a espera foi
testado (`qtd_min_em_dia` de 60 → 120) e **não resolveu**.

O padrão é **de estado**: depois de um `137` bem-sucedido, a consulta seguinte
toma 656; depois do 656, a seguinte passa.

> Isso invalida, para CNPJ ocioso, a leitura de que basta respeitar a hora
> documentada na tabela de limites do §4. A regra da NT continua valendo como
> mínimo, mas **cumpri-la não é suficiente**.

### O que derrubou o enquadramento inicial

Medido em 01/09/2026 às 20:30, com a ALL CARS já pausada e a empresa 30 sozinha:

```
emp 30 / CTE   . . . . . . . . .    nove chamadas, nenhum 656
     intervalos 75, 75, 180, 120, 90, 135 min
     cursor parado em 7145, docs = 0 na maioria delas

emp 30 / NFE   . X X . . . . X
     10:00   536 docs  ->  ok
     11:15     1 doc   ->  ok
     14:30     4 docs  ->  ok
     18:00    10 docs  ->  ok
     20:15     0 docs  ->  656   (135 min depois, cooldown respeitado)
```

Duas conclusões que reescrevem a seção:

**1. O eixo é o SERVIÇO, não o CNPJ.** O `CTeDistribuicaoDFe` aceita consulta
repetida sem documento novo — nove vezes seguidas, cursor imóvel. O
`NFeDistribuicaoDFe` não. Mesmo certificado, mesmo IP, mesmos intervalos, mesma
empresa. Não é ociosidade do CNPJ: é o serviço de NF-e penalizando a repetição.

**2. Atinge qualquer CNPJ, não só o de teste.** A empresa 30 — o CNPJ real do
projeto — tomou 656 na primeira consulta em que a fila estava vazia. As quatro
anteriores, que **trouxeram documento**, passaram todas. Ou seja: o problema
aparece assim que a captura alcança o fim da fila, que é justamente o estado
normal de operação depois da drenagem inicial.

> Isso também corrige "a empresa 30 está limpa", afirmado mais cedo neste mesmo
> dia com base em UM par de ciclos. Um par não é padrão.

### Duas variantes distintas do mesmo cStat

Descoberta importante para pesquisa — os textos são diferentes e significam
coisas diferentes:

| `xMotivo` | Onde apareceu |
|---|---|
| *"Deve ser utilizado o ultNSU nas solicitacoes subsequentes"* | no bug do §1 (nosso, real) **e também** na empresa 30 em 01/09 20:15, consulta legítima sem documento novo |
| *"Deve ser aguardado 1 hora para efetuar nova solicitacao caso nao existam mais documentos a serem pesquisados"* | ALL CARS, mesma situação |

> **Não use o texto para separar benigno de perigoso.** Era o que esta seção
> propunha antes, e a medição de 20:15 derrubou: as duas mensagens apareceram na
> MESMA situação — consulta de NF-e sem documento novo. A variante do `ultNSU`,
> que eu tratava como sinal de uso indevido, veio de uma consulta que enviou
> exatamente o `ultNSU` que a SEFAZ havia devolvido (18544). Filtrar o freio por
> texto silenciaria também o caso que ele existe para pegar.

### Hipótese do mecanismo (NÃO confirmada)

A SEFAZ marcaria a repetição de um `ultNSU` que já respondeu "sem documentos",
e o próprio 656 limparia a marca. Encaixa nos 8 pontos, mas é inferência
nossa — não há fonte.

### Por que custa caro, mesmo sendo "benigno"

1. **Trava CNPJ saudável.** O 656 aplica espera de 1 hora a *todos* os fluxos do
   domínio SEFAZ — decisão nossa, mais larga do que a NT exige, que bloqueia
   apenas o CNPJ consultado. Medido: o 656 da ALL CARS
   às 16:30 pôs NF-e e CT-e da empresa 30 em espera até 17:30, sem que ela
   tivesse feito nada errado.
2. **Queima o freio de emergência.** Dos 6 bloqueios na janela de 24h em
   01/09, **5 eram da ALL CARS ociosa** e 1 da empresa 30 (o defeito de rajada,
   já corrigido). O freio acionou e parou o motor por causa de um CNPJ que não
   entrega documento nenhum.

### A taxa medida, e por que o freio global não escala

> 🔴 **Revisto em 02/09/2026 — ver a retratação no início desta seção.** Os números abaixo incluem os 656 causados pelo cooldown quebrado.

Medido de **28 a 31/08/2026**, quatro dias seguidos, com apenas **dois** fluxos
de NF-e ativos:

```
28/08   emp 30 NFE  3      emp 900 NFE  2      total 5
29/08   emp 30 NFE  3      emp 900 NFE  2      total 5
30/08   emp 30 NFE  3      emp 900 NFE  2      total 5
31/08   emp 30 NFE  3      emp 900 NFE  2      total 5
```

**~2,5 bloqueios por dia por fluxo de NF-e**, em operação normal, sem defeito
nenhum. O limite default de 5 ficava **abaixo do ruído do próprio sistema** — o
freio disparava todo dia e parava o motor sozinho.

> Alarme que soa diariamente ensina o time a ignorar alarme. Foi por isso que o
> O limite foi para 10 em 02/09/2026 e, no mesmo dia, **saiu do `.env`**: vive em `POSEIDON.DPC_PARAMETRO` (`dfe_max_bloqueios_dia`), que ApiNFE e ApiDPC leem juntas. Estava no `.env` de cada projeto e divergiu — 10 na ApiNFE, 5 na ApiDPC — e a tela do Monitor acusava freio acionado com o motor operando normal.

**Mas o número não é a solução, e não escala.** O freio conta bloqueio
GLOBALMENTE, e a taxa normal cresce com o número de CNPJs ativos:

| Fluxos de NF-e ativos | Bloqueios/dia esperados | Limite 10 |
|---|---|---|
| 2 (hoje) | ~5 | acomoda |
| **13 (após o corte da Qive)** | **~32** | **corta o motor todo dia** |

Subir o número resolve hoje e recria o problema exatamente no dia em que o
motor menos pode parar sozinho.

As duas saídas de verdade:

1. **Contar bloqueio por FLUXO, não global.** Um fluxo repetitivo pararia a si
   mesmo sem parar os outros — e isso escala com o número de CNPJs. É a menor
   mudança que resolve de forma durável.
2. **Resolver esta seção 7.** Com o 656 de fim de fila eliminado, a taxa normal
   cai para perto de zero e o limite volta a poder ser baixo, que é a condição
   para o freio ser alarme de verdade.

### Coexistência com a Qive: medição própria, 02/09/2026

O §4 descrevia a coexistência a partir de fontes de provedores. Agora há
medição direta, e ela custou um teste inválido:

Ao preparar o teste de volume, reativei o fluxo NF-e da **empresa 1 (matriz,
66.471.517/0001-77)** — que tem 795.212 NSU de atraso e é, de longe, o maior
volume do grupo. **Primeira chamada, 656**, cursor sem avançar:

```
02/09 10:30:03   emp 1 NFE   CONSUMO_INDEVIDO   1 chamada, 0 docs
                 NSU 10277494 -> 10277494
   xMotivo: "Deve ser utilizado o ultNSU nas solicitacoes subsequentes"
```

**A empresa 1 continua atendida pela Qive.** Só a 30 e a 900 estão liberadas.
Ou seja: o teste era inválido por construção, e o 656 é a confirmação do §4 —
dois consumidores no mesmo CNPJ, cada um com seu cursor.

Duas leituras erradas que eu registrei e retiro:

- **"o token de 25 dias não é mais aceito"** — não há evidência disso. A
  explicação simples é a coexistência.
- **"isso é um bloqueio para o corte da Qive"** — é o contrário: confirma que o
  corte seco é o caminho, e que depois dele a matriz passa a ser consultável.

E abre uma dúvida sobre o passado: as rejeições **#3 e #4** do §2, em CNPJs cujo
`ultNSU=0` era legítimo, foram atribuídas a "controle por certificado". Podem ter
sido coexistência. Não reescrevo aquela conclusão sem medir, mas fica anotado
que há segunda leitura possível.

> **Lição de método:** o critério de escolha do alvo era "quem tem backlog", e o
> correto era "quem podemos consultar". A empresa 1 tinha 795 mil de atraso
> justamente PORQUE nunca conseguimos consultá-la — o atraso era sintoma do
> bloqueio, não oportunidade.

### Contenção aplicada em 01/09

`poseidon.dpc_dfe_cursor` do fluxo NF-e da empresa 900 posto em
`status_sincronismo = 'P'`, com `updated_by = 'PAUSA MANUAL'`. Cursor
preservado em NSU 87. O NFS-e da 900 segue ativo (ADN, nunca deu 656).

### A decisão que fica para o fim

**Como consultar NF-e depois que a fila zera, sem tomar 656?** É essa a pergunta
— e ela vale para TODOS os CNPJs, não só os da Qive. Em regime, todo fluxo de
NF-e vive no fim da fila; a drenagem inicial é a exceção.

Caminhos, do mais seguro ao mais arriscado:

1. **Cooldown muito maior para NF-e depois de um ciclo sem documento** (ex.: 6h
   ou 12h). Não elimina o 656, mas reduz a frequência a um patamar que o freio
   absorve. É o único caminho que os dados sustentam hoje, e é barato: coluna
   `qtd_min_em_dia`, sem código.
2. **Aceitar o 656 como parte do ciclo e ajustar o freio** — contando o bloqueio
   por FLUXO em vez de global, por exemplo, para que um fluxo repetitivo não
   pare os outros. Mexe em lógica de segurança; exige entender o limite real da
   SEFAZ antes.
3. ~~Filtrar o freio pela variante da mensagem~~ — **descartado pela medição de
   20:15**: as duas variantes aparecem na mesma situação. Ver a tabela acima.

**Antes de qualquer um deles, pesquisar.** Os dois textos literais, nas bases de
provedores (Tecnospeed, NS Tecnologia, Focus NF-e, Oobj, Qive, tributos.io,
ACBr). A pergunta certa mudou: não é "como tratar CNPJ ocioso", e sim **"qual é
o intervalo aceito pelo NFeDistribuicaoDFe entre duas consultas que não trazem
documento, e por que o CTeDistribuicaoDFe não impõe o mesmo?"** — esse contraste
entre os dois serviços, medido aqui, é a pista mais forte que temos e vale
incluir na lista de perguntas do §5 para a SEFAZ.

---

## 8. Anexos

- `storage/logs/dfe-ingerir/*-request.xml` e `*-response.xml` — envelopes `distDFeInt`
- `poseidon.dpc_dfe_execucao` — trilha com timestamps, NSU inicial/final e `xMotivo` de cada tentativa
