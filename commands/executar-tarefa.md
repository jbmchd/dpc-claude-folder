Seu objetivo é executar uma tarefa planejada no projeto alvo, seguindo o fluxo de branch, os checklists e os princípios do projeto, e registrar as alterações em `desenvolvimento.md`.

## Limitações
- Não é permitido executar sem pasta de tarefa válida e `planejamento.md` presente com seção Branch preenchida.
- Não é permitido iniciar alterações de código antes de concluir o fluxo de branch via [git-workflow-branches.md](.claude/docs/regras/gerenciar-regras/git-workflow-branches.md).
- Não alterar arquivos em `.claude/docs/**`, `.claude/agents/**`, `.claude/commands/**`, `.claude/instructions/**` ou `CLAUDE.md` neste fluxo.
- Não importar arquivos novamente nem regredir para a etapa de planejamento neste fluxo.

## Orientações Gerais
- Consulte primeiro [tarefas.md](.claude/docs/regras/gerenciar-regras/tarefas.md) para as regras de `desenvolvimento.md`.
- Consulte [git-workflow-branches.md](.claude/docs/regras/gerenciar-regras/git-workflow-branches.md) como fonte canônica para o fluxo de branch antes de qualquer alteração de código.
- Consulte os checklists e princípios do projeto alvo em [docs/regras/alterar-codigo](.claude/docs/regras/alterar-codigo) antes de começar a implementar.

## Entradas esperadas
- Caminho para a pasta de tarefa já planejada (ex.: `.claude/tarefas/<id-ou-slug>`). Se não fornecido, perguntar ao usuário.

## Validações obrigatórias
- Confirmar que a pasta informada existe.
- Confirmar que `planejamento.md` existe na pasta e contém seção **Branch** preenchida.
- Confirmar que `desenvolvimento.md` e `consideracoes.md` existem na pasta.
- Confirmar que o campo `project` em `metadata.json` identifica o projeto alvo (apidpc, dpc ou faisao); se ausente, perguntar ao usuário antes de prosseguir.
- Se qualquer validação falhar, informar o problema e orientar o usuário a corrigir ou rodar `/planejar-tarefa` antes de prosseguir.

## Regras de execução
- Leia `planejamento.md`, `consideracoes.md` e `desenvolvimento.md` para extrair o contexto completo antes de começar.
- Identifique o projeto alvo a partir de `metadata.json` e carregue os docs correspondentes:
  - Checklist de bug: `.claude/docs/regras/alterar-codigo/<projeto>-checklist-corrigir-bug.md`
  - Checklist de feature: `.claude/docs/regras/alterar-codigo/<projeto>-checklist-nova-feature.md`
  - Princípios do projeto: `.claude/docs/regras/alterar-codigo/<projeto>-principios-projeto.md`
- Execute o fluxo de branch conforme [git-workflow-branches.md](.claude/docs/regras/gerenciar-regras/git-workflow-branches.md) usando a branch registrada na seção **Branch** do `planejamento.md`. Não avance para implementação se a árvore estiver suja ou se o fluxo de branch falhar.
- Implemente as alterações no projeto alvo seguindo os checklists e princípios carregados.
- Atualize `desenvolvimento.md` durante e ao final da execução:
  - Seção `Linha do tempo`: registrar cada ação relevante com data e hora.
  - Seção `Resumo técnico das alterações`: registrar arquivos alterados, tipo de mudança e impactos.
  - Seção `Mensagem de commit sugerida`: manter como última seção do arquivo, atualizada ao final.

## Saída esperada
- Código alterado no projeto alvo, na branch correta.
- `desenvolvimento.md` atualizado com linha do tempo, resumo técnico e mensagem de commit sugerida.
- Resumo final das alterações feitas e dos próximos passos (ex.: testes manuais, PR, deploy).

## Exceções
- Se o caminho da pasta não for informado, perguntar explicitamente antes de seguir.
- Se `planejamento.md` não tiver seção **Branch**, interromper o fluxo e orientar o usuário a rodar `/planejar-tarefa` para preenchê-la.
- Se `metadata.json` não tiver campo `project` e o projeto alvo não puder ser inferido com certeza, perguntar ao usuário antes de carregar qualquer checklist ou iniciar implementação.
- Se o fluxo de branch resultar em conflito, parar e solicitar que o usuário resolva antes de prosseguir.
