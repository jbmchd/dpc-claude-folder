Execute uma tarefa planejada no projeto alvo, seguindo o fluxo de branch e os princípios do projeto, e registre as alterações em `desenvolvimento.md`. Consulte [tarefas.md](.claude/docs/regras/gerenciar-regras/tarefas.md) como fonte canônica.

## Limitações
- Não executar sem pasta válida e `planejamento.md` com seção **Branch** preenchida.
- Não iniciar alterações de código antes de concluir o fluxo de branch via [git-workflow-branches.md](.claude/docs/regras/gerenciar-regras/git-workflow-branches.md).
- Não importar arquivos nem regredir para etapas anteriores neste fluxo.

## Validações obrigatórias

Antes de qualquer ação, confirmar que a pasta existe e contém `planejamento.md` (com seção **Branch** preenchida), `desenvolvimento.md` e `consideracoes.md`. Confirmar que `metadata.json` tem o campo `project` (apidpc, dpc ou faisao); se ausente e não inferível com certeza, perguntar antes de prosseguir.

## Regras de execução

- Se o caminho da pasta não for informado, perguntar antes de seguir.
- Ler `planejamento.md`, `consideracoes.md`, `desenvolvimento.md` e as imagens em `images/` para extrair contexto completo antes de começar.
- Identificar o projeto alvo via `metadata.json` e carregar os docs correspondentes:
  - `.claude/docs/regras/alterar-codigo/<projeto>-checklist-corrigir-bug.md`
  - `.claude/docs/regras/alterar-codigo/<projeto>-checklist-nova-feature.md`
  - `.claude/docs/regras/alterar-codigo/<projeto>-principios-projeto.md`
- Executar o fluxo de branch conforme `git-workflow-branches.md` usando a branch do `planejamento.md`. Não avançar se a árvore estiver suja ou o fluxo de branch falhar.
- Implementar as alterações seguindo os checklists e princípios carregados.
- Atualizar `desenvolvimento.md` durante e ao final da execução conforme a estrutura definida em `tarefas.md`.

## Encerramento

- Finalizar com resumo das alterações feitas e próximos passos (testes manuais, PR, deploy).
- Se qualquer validação falhar, informar o problema e orientar o usuário a rodar `/planejar-tarefa` para corrigir antes de prosseguir.
- Se o fluxo de branch resultar em conflito, parar e solicitar que o usuário resolva antes de continuar.
