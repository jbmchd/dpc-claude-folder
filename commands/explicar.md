# /explicar

**Objetivo:** explicar uma demanda como um tech lead explicaria — *o que* é pra ser feito (ou foi feito) e, principalmente, *por quê* — em três níveis de profundidade. Serve para entender o sentido, o impacto e a relevância da tarefa antes ou depois de mexer no código.

**Uso canônico:** rodar **depois de algo feito e testado**, para registrar o entendimento do que foi entregue (modo "já feito"). Também funciona "a fazer" e em pedidos conceituais.

## Regra de ouro
- **NUNCA** altera código, cria branch, instala dependências ou implementa qualquer coisa. Só lê e explica.
- Vale inclusive para pedidos conceituais (`/explicar feature de login`): apenas explica. Só implementar quando o usuário pedir explicitamente, em outra mensagem.

## Modos de uso
- **Standalone:** `/explicar <fonte>` — onde `<fonte>` pode ser:
  - link do Trello ou `#NNNN` (card);
  - caminho de uma pasta de tarefa em `.claude-work-items/`;
  - texto livre / conceito, mesmo sem tarefa formal (ex.: `/explicar feature de login`, `/explicar como funciona o EDI`).
- **Modificador `--explicar`:** anexado a outro command (`/importar-tarefa --explicar`, `/planejar-tarefa --explicar`, `/executar-tarefa --explicar`). O command principal roda normalmente e, **ao final**, é gerada a explicação nos 3 níveis sobre o que aquele command produziu/fará. O `--explicar` nunca relaxa os limites do command principal.

## Entradas aceitas
Link do Trello, card number (`#NNNN`), caminho de pasta de tarefa, texto solto no prompt, conceito do sistema — isoladamente ou combinados. Se a fonte for ambígua ou faltar contexto para identificar do que se trata, **perguntar antes** de investigar.

## Fontes que o comando deve consultar antes de explicar
Investigar o suficiente para explicar com fundamento (sem só repetir o texto do card):
- **Pasta da tarefa**, se existir: `conteudo-*.md`, `consideracoes.md`, `planejamento.md`, `desenvolvimento.md`, `metadata.json`, anexos.
- **Card do Trello** (MCP Trello, board `DPC Dev`) quando for link/número e não houver pasta importada.
- **Código do projeto alvo** — ler os arquivos realmente envolvidos para descrever recursos e pontos críticos com precisão.
- **Banco de dados** via **MCP DPC** — identificar tabelas/colunas envolvidas (schemas: `consinco`, `poseidon`, `dovemail`).
- **Docs internos**: arquitetura (`.claude/docs/arquitetura/<projeto>-arquitetura.md`), convenções e checklists (`.claude/docs/regras/alterar-codigo/`), visão do ecossistema para tarefas cross-project.
- **context7** para bibliotecas/frameworks externos quando a explicação técnica depender disso.

Limite de investigação: seguir a diretriz de no máx. 2 tentativas por consulta MCP antes de perguntar; não entrar em loop.

## Detecção de modo (a fazer × já feito)
- **Já feito** → se houver `desenvolvimento.md` com alterações registradas, branch com mudanças ou diff disponível. A explicação descreve *o que foi alterado e por quê*.
- **A fazer** → caso contrário. A explicação descreve *o que deve ser feito e por quê*.
- Sempre deixar explícito no topo da saída em qual modo está (`Modo: a fazer` / `Modo: já feito`).

## Público-alvo e linguagem
- Escrever sempre como se explicasse para **alguém de fora da TI**: frases curtas, sem jargão não explicado. O termo técnico/fiscal só entra acompanhado da explicação (ou de referência ao glossário).
- A densidade técnica **cresce por nível**: Nível 1 totalmente leigo; Nível 2 funcional; Nível 3 é onde mora o detalhe técnico. Nunca começar técnico.

## Estrutura da explicação (saída)
Apresentar nesta ordem, em linguagem direta de tech lead:

1. **Nível 1 — Visão geral** (linguagem simples, sem jargão): o que é, se é bug ou feature, quem é impactado (cliente / usuário / área interna), qual o problema ou ganho e por que isso importa. Ex.: *"é a correção do bug X que gera o problema Y, impactando o cliente em Z"* ou *"é a feature X que permite ao usuário fazer Y"*.
2. **Nível 2 — Regras de negócio:** o comportamento correto esperado, as regras do domínio que governam isso, entidades conceituais envolvidas e o *porquê* de cada regra. É o "contrato" funcional, independente de tecnologia.
3. **Nível 3 — Regras técnicas:** projeto(s) afetado(s) (ApiDPC / DPC / Faisao / DpcInventario), arquivos e camadas envolvidos, tabelas/colunas de banco, recursos de framework usados (Laravel/Eloquent, Vue/Vuex, React Native/Expo, etc.), **ponto(s) crítico(s)**, riscos e pontos de atenção colaterais.

Depois dos 3 níveis, sempre incluir:

- **Glossário de termos:** lista curta dos jargões de domínio/técnicos que aparecem (ex.: EDI, CFOP, Simples Nacional, OTA), cada um em uma frase. **Antes de definir**, consultar o glossário acumulado em [`.claude/docs/glossario-dominio.md`](../docs/glossario-dominio.md) e reusar as definições de lá. **Ao final**, registrar nesse arquivo os termos novos que ainda não existirem (uma linha por termo, conforme as regras do próprio glossário), para o dicionário do sistema crescer a cada tarefa explicada.
- **Diagrama de fluxo (mermaid):** o fluxo afetado de ponta a ponta (ex.: tela → API → banco), em bloco ```mermaid```. Manter simples e fiel ao que foi investigado.
- **Perguntas pro tech lead:** lista de perguntas objetivas para preencher lacunas que o card não esclarece (regra ambígua, caso de borda, prioridade, dado que faltou). São perguntas que o usuário pode levar ao tech lead.

## Persistência
- Se existir pasta da tarefa → salvar a explicação como `explicacao.md` dentro dela **e** apresentar no chat.
- Pedido conceitual sem pasta → apenas chat (não criar pasta).
- Modo modificador (`--explicar`) → salvar `explicacao.md` na pasta da tarefa do command principal, quando houver.

## Não faz
- Não altera código, não cria/checkout de branch, não commita, não implementa.
- Não importa nem reprocessa anexos (isso é do `/importar-tarefa`).
- Não substitui o `planejamento.md` (foco é entendimento, não plano de execução).

## Encerramento
Confirmar o modo usado, onde a explicação foi salva (se aplicável) e lembrar que nada foi alterado no código. Se for tarefa real, sugerir o próximo passo do fluxo (`/planejar-tarefa` ou `/executar-tarefa`) sem executá-lo.
