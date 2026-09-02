# Captura própria de NF-e de entrada — decisão sobre a Qive

**Para:** gestão · **Data:** 08/08/2026 · **Assunto:** substituição do serviço Qive por sistema próprio

---

## Resumo em três frases

O sistema próprio de captura de notas fiscais de entrada **está construído e funcionando**. Descobrimos, porém, que a Receita **não permite que dois sistemas capturem as notas do mesmo CNPJ ao mesmo tempo** — e enquanto a Qive estiver ativa, o nosso é bloqueado. A decisão necessária é **quando desligar a Qive**, porque não existe período de convivência entre os dois.

---

## 1. O que foi construído

Um sistema dentro da ApiNFE que busca na Receita as notas fiscais emitidas contra o CNPJ da DPC, guarda e organiza. É o que a Qive faz hoje.

O que já foi comprovado funcionando, com dados reais de produção:

- comunicação com a Receita usando o certificado digital da empresa
- captura e armazenamento dos documentos originais
- interpretação e organização dos dados
- controles de segurança para não exceder os limites da Receita

---

## 2. O problema

A Receita trata como **uso indevido** quando mais de um sistema consulta as notas do mesmo CNPJ. Quando isso acontece, ela **bloqueia o acesso por 1 hora**.

Hoje a Qive faz essas consultas para a DPC. Quando o nosso sistema consulta, a Receita entende que há dois sistemas disputando o mesmo canal, e bloqueia.

Isso não é um defeito do nosso sistema nem da Qive. É uma regra da Receita, documentada, e existe para proteger os servidores dela.

**A consequência prática:** não há como testar o sistema próprio em paralelo, nem fazer transição gradual comparando os resultados dos dois. É necessário desligar um para ligar o outro.

---

## 3. As opções

### A) Desligar a Qive e assumir com o sistema próprio

**Prós** — elimina o custo do serviço; a DPC passa a ter os XMLs em base própria; sem dependência de terceiro.

**Contras** — período inicial sem rede de segurança; se algo falhar, notas podem deixar de ser capturadas até a correção. A Receita guarda os documentos por **90 dias**, então falhas curtas são recuperáveis, mas não indefinidamente.

**Risco:** médio. Mitigável com corte em período de menor movimento e acompanhamento diário nas primeiras semanas.

### B) Manter a Qive

**Prós** — nenhuma mudança operacional; risco zero no curto prazo.

**Contras** — o investimento já feito no sistema próprio não se converte em economia; a dependência continua.

### C) Corte parcial, por empresa

Desligar a Qive apenas para **algumas filiais** e assumir só essas, mantendo o restante com a Qive.

**Esta opção depende de uma confirmação técnica que ainda não temos:** se o controle da Receita é por CNPJ ou por certificado digital. Como todas as filiais da DPC usam o certificado da matriz, é possível que o bloqueio afete o grupo inteiro mesmo separando por empresa — nossos testes sugerem que sim.

**Ação necessária:** confirmar com a Receita antes de considerar esta opção viável.

---

## 4. O que recomendamos

**Opção A, com corte planejado**, na seguinte sequência:

| Etapa | O que envolve | Depende de |
|---|---|---|
| 1 | Confirmar com a Qive a data/hora em que ela para de consultar | negociação contratual |
| 2 | Obter da Qive a posição de leitura atual, se possível | Qive |
| 3 | Corrigir o cadastro dos certificados (ver §5) | equipe interna |
| 4 | Ligar o sistema próprio e acompanhar diariamente por 2 semanas | TI |
| 5 | Encerrar o contrato | gestão |

> **A NFS-e sai por último.** Os passos acima valem para NF-e e CT-e, onde o ERP permite conferir. Para NFS-e não há segunda fonte, e o corte exige um período com as duas rodando em paralelo antes de desligar. Ver seção 8.

O passo 2 merece atenção: a Receita controla a leitura por uma espécie de "marcador de posição". Esse marcador está hoje com a Qive. Se ela puder informá-lo no momento do corte, a transição é limpa. Se não, existe risco de repetição ou de lacuna nos primeiros dias — recuperável, mas exige acompanhamento.

---

## 5. Um problema que apareceu no caminho, independente da decisão

Ao levantar o ambiente, encontramos algo que **já afeta a operação atual**:

> **Dos 27 CNPJs ativos da DPC, apenas 3 têm certificado digital utilizável.**

- 7 estão com certificado **vencido desde 13/11/2025** — ou seja, há **9 meses**
- 2 estão com a senha cadastrada incorretamente no sistema
- 15 nunca tiveram certificado cadastrado

Isso significa que **a maior parte das filiais não consegue se comunicar com a Receita** por meios próprios hoje. Vale verificar com a contabilidade se isso tem impactado algum processo fiscal, independentemente da decisão sobre a Qive.

A renovação foi feita e aplicada em apenas 3 empresas — as demais ficaram para trás e ninguém percebeu por 9 meses. O sistema novo já inclui um monitor que alerta 30 dias antes do vencimento, justamente para isso não se repetir.

---

## 6. Perguntas para levar à Qive

1. É possível combinar **data e hora exatas** para o encerramento das consultas?
2. A Qive pode fornecer a **posição de leitura atual** (o "ultNSU") de cada CNPJ no momento do corte?
3. Existe forma de **exportar o histórico** de XMLs já capturados? A Receita só disponibiliza os últimos 90 dias — o que estiver além disso só existe na base da Qive.
4. Há período contratual mínimo ou multa por encerramento?

A pergunta 3 é a mais importante: **o histórico anterior a 90 dias não é recuperável pela Receita**. Se houver necessidade fiscal ou de auditoria desses arquivos, eles precisam ser obtidos antes do encerramento.

---

## 7. O que a TI precisa da gestão

1. **Decisão sobre desligar a Qive** e em que data
2. **Autorização para tratar com a Qive** os pontos do §6
3. **Encaminhamento do problema dos certificados** (§5), que independe do resto
4. **Definição sobre o histórico**: é necessário extrair da Qive antes do corte?

---

## 8. Achado posterior: NFS-e muda o tamanho da decisão

Levantado em 19/08/2026, depois de a primeira versão deste documento ficar pronta.

> **Atualizado em 20/08/2026.** O **achado** desta seção continua valendo e é o mais importante do documento: a NFS-e recebida **não existe no ERP**, e por isso a Qive não é onde se confere — é o único lugar onde ela existe.
>
> O que mudou é a **conclusão**. A versão anterior recomendava manter a Qive só para NFS-e e tratar o assunto como projeto separado. Não é mais o caminho: a captura de NFS-e **foi construída** e já traz documento real do ADN Nacional. A decisão passa a depender de **medir cobertura**, não de contratar fornecedor — ver "Situação em 20/08" abaixo.

### O que a Qive entrega hoje

Além de NF-e, a Qive entrega **CT-e** (conhecimento de transporte, o frete) e **NFS-e** (nota de serviço). O sistema próprio, quando este documento foi escrito, cobria apenas NF-e.

Desde então o **CT-e foi concluído**: o sistema já captura, interpreta e guarda, testado com 30 documentos reais sem erro. Ele identifica inclusive se a DPC é quem pagou o frete ou se apenas aparece no documento — distinção que a listagem precisa ter para servir à contabilidade.

### O caso da NFS-e é diferente, e é o ponto que importa

Para NF-e e CT-e, o sistema próprio **duplica** um dado que o ERP já registra. Dá para comparar os dois e conferir se está tudo lá.

Para NFS-e não existe essa comparação. Verificamos no banco: **a NFS-e recebida não é registrada como documento fiscal no ERP** — nem na tabela de notas fiscais, nem no módulo de recebimento. Ela aparece, no máximo, como um título a pagar, pelo valor. A área confirmou: *"só olhamos na Qive"*.

Ou seja, para nota de serviço a Qive **não é onde se confere — é o único lugar onde esses documentos existem de forma organizada.**

### Consequência prática

Isso separa a decisão em duas partes, com riscos bem diferentes:

| | NF-e e CT-e | NFS-e |
|---|---|---|
| O ERP registra? | sim | **não** |
| O sistema próprio cobre? | sim | **sim, desde 20/08** |
| Desligar a Qive significa | trocar de fornecedor | trocar o **único** registro por outro registro próprio |

A assimetria de risco permanece, e é ela que deve guiar a ordem: em NF-e e CT-e um erro nosso é **conferível** contra o ERP; em NFS-e um erro nosso é **invisível**, porque não há segunda fonte. Isso não impede o corte — exige que a NFS-e seja a **última** a sair da Qive, e só depois de um período com as duas rodando em paralelo.

### Quais CNPJs a Qive atende, e por que isso limita o teste

Confirmado em 20/08/2026: a Qive atende **todos** os CNPJs da DPC, com **duas
exceções** — a empresa **900** (ALL CARS, cadastrada só para teste) e a empresa
**30** (filial MS).

Isso não é um detalhe operacional, é o que define o que pode ser testado hoje. A
posição de leitura (o NSU) é **uma por CNPJ, compartilhada entre quem consulta**.
Dois consumidores no mesmo CNPJ disputam a mesma sequência e dobram o consumo —
com risco de bloqueio. Por isso:

- os fluxos das 12 empresas atendidas pela Qive seguem **pausados**, de propósito;
- toda validação em produção foi feita nas empresas **900 e 30**;
- ativar as demais depende de a Qive informar **quando** ela para de consultar
  cada CNPJ — a mesma pergunta do "marcador de posição" na §6.

Para NFS-e há uma incerteza adicional que não bloqueia nada: não se sabe se a
Qive consome o ADN ou raspa o sistema de cada município. Como 900 e 30 estão fora
do alcance dela, a medição de cobertura pôde ser feita sem essa resposta.

### Situação em 20/08: a captura de NFS-e foi construída

A NFS-e Nacional tem um ambiente de distribuição — o **ADN** — que entrega ao tomador as notas de serviço recebidas. Ele foi integrado ao mesmo motor:

- **Comunicação estabelecida em produção**, com documento real chegando (a primeira NFS-e capturada tem prestador, tomador, ISSQN, retenções e município de incidência completos).
- **Um motor, não dois.** A tecnologia de comunicação do ADN é diferente da da Receita, mas essa diferença ficou isolada num único ponto do código. Agendamento, controle de consumo, guarda do documento original e monitoramento são os mesmos de NF-e e CT-e — o que significa que manter isso não custa uma segunda rotina para cuidar.
- **Guarda em tabela própria**, com o campo que a contabilidade usa (mês de competência) e a distinção entre serviço que a DPC **contratou** e serviço que a DPC **prestou** — a empresa 3 é transportadora e emite nota de serviço.

Resta **uma** pergunta aberta, e ela é de medição, não de construção:

> **Quanto do que a DPC recebe passa pelo ADN?** A cobertura depende de o município ter aderido ao padrão nacional. Estimativas de mercado falam em torno de 70% das emissões do país, mas o número que importa é o da DPC, não o do país.

Isso deixou de ser estimativa. Medição real nas **duas** empresas que a Qive não
atende — a 900 (ALL CARS) e a 30 (filial de Mato Grosso do Sul):

| IBGE | Município | UF | Notas | Prestadores | Valor |
|---|---|---|---|---|---|
| 5002704 | Campo Grande | MS | 9 | 3 | R$ 354.940,25 |
| 3113404 | Caratinga | MG | 9 | 3 | R$ 678,00 |
| 3106200 | Belo Horizonte | MG | 8 | 6 | R$ 5.401,90 |
| 3505708 | Barueri | SP | 3 | 1 | R$ 3,00 |
| 5003702 | Dourados | MS | 2 | 1 | R$ 7.450,36 |
| 3170107 | Uberaba | MG | 2 | 1 | R$ 245,05 |
| 3202454 | Ibatiba | ES | 1 | 1 | R$ 10.857,00 |
| 3205309 | Vitória | ES | 1 | 1 | R$ 150,00 |
| 3130903 | Inhapim | MG | 1 | 1 | R$ 209,00 |
| 2919207 | Lauro de Freitas | BA | 1 | 1 | R$ 50,00 |

**10 municípios · 5 UFs · 37 notas · R$ 379.984,56 · 37 de 37 como tomador.**

Três leituras que essa medição já permite:

1. **Município pequeno aparece.** Inhapim, Ibatiba, Caratinga e Lauro de Freitas
   não são capitais, e ainda assim entregaram nota pelo ADN. É indício favorável à
   cobertura: a adesão ao padrão nacional não está restrita a cidade grande.
2. **O ADN guarda histórico, mas não o mesmo para todos.** A ALL CARS trouxe nota
   de **out/2024**; a filial MS começa em **mar/2026**. Em nenhum dos dois casos
   são os 90 dias da Receita — a primeira consulta de um CNPJ pode trazer anos de
   documento, o que é bom para o histórico e exige cuidado no ritmo da carga
   inicial.
3. **O que aparece é despesa real de operação.** Na filial MS: frete (R$ 92 mil e
   R$ 87 mil de uma transportadora), internet, consultoria, benefícios. Não é
   documento marginal — é gasto que a contabilidade acompanha, e que hoje só existe
   organizado na Qive.

**O que pedimos:** autorizar a **operação em paralelo** (Qive e sistema próprio,
ambos ligados) para NFS-e nos CNPJs que a Qive atende.

A medição acima cobre as duas empresas que a Qive **não** atende. Ela prova que o
mecanismo funciona e já mostra volume relevante, mas **não** substitui a comparação
lado a lado: são 2 CNPJs de 14, e não há como saber o que o ADN *deixou* de
entregar sem ter a lista da Qive do mesmo período para comparar. É essa comparação
que dá o percentual de cobertura no volume real da DPC — e, como não existe segunda
fonte para NFS-e, é a única forma de um erro nosso aparecer **antes** de a Qive
sair.

## Anexo — situação técnica resumida

| Item | Situação |
|---|---|
| Sistema próprio — NF-e | construído e validado com documento real: notas, eventos e conciliação com o ERP |
| Comunicação com a Receita | funcionando |
| Bloqueio por concorrência com a Qive | **impede a operação** enquanto as duas coexistirem |
| Sistema próprio — CT-e | construído e validado: 30 documentos reais, sem erro |
| Sistema próprio — NFS-e | **construído**; comunicação com o ADN validada em produção com documento real. Cobertura por município ainda **não medida** (ver seção 8) |
| Registro de NFS-e no ERP | **não existe** — nem em notas fiscais, nem no recebimento (ver seção 8) |
| Certificados | 5 de 27 CNPJs utilizáveis |
| Instalação | ambiente de testes; produção pendente de decisão |
| Histórico anterior a 90 dias | recuperável apenas pela Qive |
| Registro de NFS-e recebida | hoje **somente na Qive**; o sistema próprio já captura, falta medir cobertura |

Detalhamento técnico em `12_sefaz-656-consumo-indevido.md`.
