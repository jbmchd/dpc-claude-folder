# /tarefa-completa

**Objetivo:** orquestrar o fluxo completo importar → classificar → planejar → executar, alternando modelos por fase e com pausa obrigatória para aprovação antes de alterar código.

**Entrada:** qualquer entrada válida para `/importar-tarefa` (link Trello, `#NNNN`, PDF, texto, etc.). Pode conter **mais de um card** na mesma chamada.

**Não faz:** pular a pausa de aprovação, fazer push ou abrir PR. **Não commita** — exceto o auto-commit por card do **Modo A multi-card** (ver Fase 0 e [git-workflow-branches.md](../docs/regras/gerenciar-regras/git-workflow-branches.md)).

---

## Fluxo

### Fase 0 — Detecção de múltiplos cards

Antes de qualquer coisa, contar quantos **cards distintos do Trello** aparecem na entrada (links `trello.com/c/…` ou `#NNNN`; deduplicar).

> **Entrada só como imagem:** a detecção é **textual**. Se os cards vierem apenas em imagem/print (sem links nem `#NNNN` no texto) e a imagem sugerir **mais de um card**, **não** tentar adivinhar os identificadores pela imagem — **parar e pedir** ao usuário os links ou números (`#NNNN`) dos cards antes de contar e seguir. Só prosseguir após receber os identificadores.

- **0 ou 1 card** → seguir o fluxo padrão (Fases 1→5) uma única vez. Fase 0 não gera pergunta.
- **≥2 cards** → `AskUserQuestion` perguntando como tratá-los:
  - **Modo A — cards separados:** cada card é uma demanda independente (N pastas, N branches, N PRs) + uma **branch de integração** só para teste conjunto.
  - **Modo B — cards mesclados:** os N cards são uma única demanda (1 pasta, 1 branch, 1 PR).

Regra canônica dos dois modos: [tarefas.md §9](../docs/regras/gerenciar-regras/tarefas.md).

#### Modo A — cards separados (sequencial)

O git tem uma árvore de trabalho única; por isso o processamento é **sequencial**, nunca paralelo.

1. Para cada card, na ordem recebida: rodar Fase 1 (Importar) → Fase 2 (Classificar) → Fase 3 (Planejar), cada um gerando sua pasta `cards/{codigo}-{slug}/` e sua branch `feature/{card}-{slug}`.
2. Apresentar **uma única pausa de aprovação** listando os N planos (aprovar todos / cancelar). Não avançar sem aprovação explícita.
3. Aprovado, para cada card **em sequência**: rodar Fase 4 (Executar) na sua branch e, ao terminar, fazer **auto-commit** na branch da tarefa usando a "Mensagem de commit sugerida" do `desenvolvimento.md` (exceção de [git-workflow-branches.md](../docs/regras/gerenciar-regras/git-workflow-branches.md)) — deixando a árvore limpa para o próximo card.
4. Ao final de todos: criar a branch `integracao/{cards}` (idShorts unidos por `-`, ex.: `integracao/3183-3184-3185`) a partir da base (`main`/`master`) e fazer **merge** de cada branch de tarefa nela. Conflito → parar e pedir resolução.
5. Reportar: N branches prontas + branch de integração pronta **só para teste**. **Push e abertura de PR são feitos a pedido do usuário; correções vão sempre na branch da tarefa/card específico — nunca na de integração.**
   - **Após o PR de um card já ter sido aberto**, correções nesse card seguem o padrão de [git-workflow-branches.md §8.4](../docs/regras/gerenciar-regras/git-workflow-branches.md): aplicar na branch da tarefa → commit → push (atualiza o PR) → rebuild da `integracao/{cards}`, **sem perguntar de novo**.
   - Enquanto o PR ainda **não** foi aberto, uma correção fica na branch da tarefa e o rebuild da integração é **oferecido** (não automático).

#### Modo B — cards mesclados (ciclo único)

1. Rodar Fase 1 (Importar) **uma vez com todos os cards** → uma pasta `cards/{codigo-primeiro}-{slug}/`, com `metadata.json` contendo o array `cards: [...]` e `conteudo-do-card.md` consolidando cada card em uma seção `## Fonte: Trello #NNNN`.
2. Seguir Fases 2→5 normalmente (uma classificação, um planejamento, uma execução) → 1 branch `feature/{cards}-{slug}`, 1 PR (manual). **Sem auto-commit:** por ser branch única, comporta-se como card único — a execução deixa a árvore suja e o commit é manual.

> **Auto-commit só no Modo A.** É a única situação do workspace em que um commit automático é permitido (para separar N branches + montar a integração). Card único e Modo B seguem a regra padrão: execução nunca commita.

> As Fases 1→5 abaixo descrevem o ciclo de **uma** tarefa. No Modo A elas rodam N vezes (com o auto-commit e a integração acima); no Modo B rodam uma vez sobre a pasta mesclada.

### Fase 1 — Importar (Haiku)

Acionar `Agente Importar Tarefa`. **O que passar depende do modo (Fase 0):**

- **Card único / fluxo padrão:** passar a entrada recebida inteira.
- **Modo A (separados):** invocar o agente **uma vez por card**, passando **apenas aquele card** (seu link/`#NNNN`). Material sem card (PDF, imagens, texto solto) deve ser anexado ao card a que se refere; se a associação não for clara, **perguntar** a qual card pertence antes de importar.
- **Modo B (mesclados):** invocar o agente **uma vez**, passando **todos os cards** e a instrução explícita de que devem ser **mesclados numa única tarefa** (§9.3 de [tarefas.md](../docs/regras/gerenciar-regras/tarefas.md)) — sem essa instrução o importador trata como single-card.

Para cada invocação:
- Se `{"status": "erro"}` → exibir motivo e **encerrar**. Orientar a corrigir e rodar `/tarefa-completa` ou `/importar-tarefa` manualmente.
- Se `{"status": "ok"}` → guardar `pasta` e avançar. No Modo A, guardar as N pastas na ordem dos cards.

### Fase 2 — Classificar (Sonnet)

Acionar `Agente Classificar Tarefa` passando o caminho da pasta.

- Se `{"status": "erro"}` → exibir motivo e **encerrar**.
- Se `{"status": "ok"}` → guardar `complexidade` e `motivo`, avançar.

### Fase 3 — Planejar (Sonnet ou Opus)

Rotear conforme `complexidade`:

- `"simples"` → acionar `Agente Planejar Tarefa Sonnet`
- `"complexa"` → acionar `Agente Planejar Tarefa Opus`

Passar o caminho da pasta. Informar ao usuário qual modelo foi escolhido e o motivo da classificação antes de spawnar.

- Se `{"status": "erro"}` → exibir motivo e **encerrar**. Orientar a corrigir e rodar `/planejar-tarefa` manualmente.
- Se `{"status": "ok"}` → exibir o `resumo` e a **pausa de aprovação**.

### ⏸ Pausa obrigatória

Apresentar ao usuário:

```
Planejamento concluído. [Sonnet|Opus]

[resumo do agente-planejar]

Arquivo completo: <pasta>/planejamento.md

O que deseja fazer?
  1. Aprovar e executar
  2. Ajustar planejamento manualmente e rodar /executar-tarefa depois
  3. Cancelar
```

Aguardar resposta. **Não avançar sem confirmação explícita de opção 1.**

> **Modo A:** a pausa é **única** e lista os N planos (um resumo por card, com sua branch). As opções passam a ser **1. Aprovar e executar todos** / **2. Ajustar manualmente** / **3. Cancelar**. Aprovar (opção 1) libera a execução sequencial de todos os cards.

### Fase 4 — Executar (Sonnet) — somente se opção 1 aprovada

Acionar `Agente Executar Tarefa` passando o caminho da pasta.

- Se `{"status": "erro"}` → exibir motivo. Orientar a corrigir e rodar `/executar-tarefa` manualmente.
- Se `{"status": "ok"}` → exibir lista de arquivos alterados e próximos passos (testes manuais, PR, deploy).

> **Modo A:** executar os cards **em sequência** (passar a pasta de cada card, um por vez). Após cada `{"status":"ok"}`, fazer o **auto-commit** na branch daquele card (passo 3 do Modo A) antes de executar o próximo. Terminados todos, montar a `integracao/{cards}` (passo 4) e reportar (passo 5). Se algum card retornar `erro`, parar a sequência, reportar em qual card parou e o que já foi commitado.

### Fase 5 — Explicar (somente se a invocação trouxer `--explicar`)

Acionar **apenas depois** da Fase 4 concluída com `{"status": "ok"}` — ou seja, com a tarefa feita. Rodar [`/explicar`](explicar.md) sobre a pasta em modo "já feito" e gerar `explicacao.md`.

- Se o fluxo encerrou antes da Fase 4 (erro ou pausa não aprovada), **não** acionar `--explicar`.

---

**Encerramento:** independente da fase final, informar claramente onde o fluxo parou e o próximo passo recomendado.
