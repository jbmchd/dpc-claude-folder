# /executar-tarefa

**Objetivo:** executar uma tarefa planejada alterando código no projeto alvo e registrando as mudanças em `desenvolvimento.md`.

**Entrada:** caminho da pasta da tarefa (se não informado, perguntar).

**Saída:** código alterado no projeto; `desenvolvimento.md` atualizado com linha do tempo, decisões e resumo técnico; árvore de trabalho **suja** aguardando instrução do usuário.

**Não faz:** `git commit`, `git push`, abertura de PR — **nunca**, mesmo com autorização prévia em mensagens anteriores. Autorização não persiste entre fases.

**Fluxo detalhado:** [tarefas.md §2.3](../docs/regras/gerenciar-regras/tarefas.md) · [git-workflow-branches.md](../docs/regras/gerenciar-regras/git-workflow-branches.md).

**Pré-condições:**
- Pasta existe e contém `planejamento.md` (com seção **Branch** preenchida), `desenvolvimento.md`, `consideracoes.md`.
- `metadata.json` tem `project` (`apidpc`, `dpc` ou `faisao`). Se ausente e não inferível com certeza → perguntar.
- Árvore de trabalho limpa antes do fluxo de branch; se suja, parar e pedir commit/stash.

**Docs carregados por projeto alvo:**
- `.claude/docs/regras/alterar-codigo/<projeto>-checklist-corrigir-bug.md`
- `.claude/docs/regras/alterar-codigo/<projeto>-checklist-nova-feature.md`
- `.claude/docs/regras/alterar-codigo/<projeto>-convencoes.md`

**Exceções:**
- Fluxo de branch em conflito → parar e pedir que o usuário resolva antes de continuar.
- Qualquer validação falhando → informar e orientar rodar `/planejar-tarefa` para corrigir.
- Tarefa de migração Maracanã → seguir também [migracao-legado.md](../docs/regras/gerenciar-regras/migracao-legado.md).

**Encerramento:** resumo das alterações e próximos passos (testes manuais, PR, deploy), mantendo a árvore suja.
