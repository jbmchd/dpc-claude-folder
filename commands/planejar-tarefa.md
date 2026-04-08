Seu objetivo é gerar ou atualizar o planejamento de uma tarefa a partir de uma pasta local já criada, consumindo apenas os arquivos presentes nela e sem executar importações nem alterar código.

## Limitações
- Não é permitido alterar código neste fluxo.
- O planejamento deve ser coerente com o projeto alvo, mas sem alterar código ou criar branches neste fluxo.
- Não execute importação de arquivos; consumir apenas arquivos presentes na pasta informada.
- Se a pasta não existir ou faltar arquivo essencial, informar claramente o problema e não executar nenhuma ação parcial.

## Orientações Gerais
- Consulte primeiro [tarefas.md](.claude/docs/regras/gerenciar-regras/tarefas.md).
- Consulte [git-workflow-branches.md](.claude/docs/regras/gerenciar-regras/git-workflow-branches.md) como fonte canônica para definir e registrar a branch da tarefa antes de finalizar o planejamento.
- Para o projeto alvo, consulte também os docs relevantes em [regras/alterar-codigo](.claude/docs/regras/alterar-codigo/).
- Em tarefas do `Faisao`, aplicar a regra de referência funcional definida em [faisao-principios-projeto.md](.claude/docs/regras/alterar-codigo/faisao-principios-projeto.md).

## Entradas esperadas
- Caminho para a pasta de tarefa já criada (ex.: `.claude/tarefas/<id-ou-slug>`). Se não fornecido, perguntar ao usuário.
- Estrutura documental mínima da tarefa conforme definida em `tarefas.md`, incluindo `metadata.json` quando disponível.

## Validações obrigatórias
- Confirmar que a pasta informada existe.
- Confirmar que a estrutura documental mínima definida em `tarefas.md` está presente ou pode ser normalizada.
- Confirmar que `consideracoes.md` existe na pasta informada; se ausente, orientar o usuário a rodar `/importar-tarefa` novamente antes de prosseguir.
- Se a pasta for inválida ou incompleta, orientar o usuário a corrigir a estrutura ou rodar `/importar-tarefa` novamente antes de prosseguir.

## Regras de execução
- Leia os arquivos da estrutura documental da tarefa, priorizando `metadata.json`, `conteudo-do-card.md` ou `conteudo-da-tarefa.md` e `consideracoes.md`, para extrair contexto, detalhes e o entendimento inicial da tarefa antes de gerar o planejamento.
- Em tarefas do `Faisao`, registrar no `planejamento.md` o mapeamento funcional exigido por `faisao-principios-projeto.md`, destacando as regras de negócio, contratos, validações e inteligências que precisam ser preservados no app mobile.
- Gere ou atualize `planejamento.md` seguindo a estrutura definida em `tarefas.md`.
- Preencha a seção **Branch** do `planejamento.md` conforme `git-workflow-branches.md`.
- Garanta que `desenvolvimento.md` exista e siga a estrutura definida em `tarefas.md`, sem registrar alterações de código que ainda não aconteceram.
- Finalize com um resumo dos próximos passos, deixando claro que a etapa seguinte é a execução da tarefa no projeto alvo.

## Saída esperada
- `planejamento.md` preenchido com o plano técnico e a seção **Branch**.
- Estrutura documental da tarefa normalizada conforme `tarefas.md`, incluindo `desenvolvimento.md`.
- Resumo final do planejamento e dos próximos passos para execução.

## Exceções
- Se o caminho da pasta não for informado, pergunte explicitamente antes de seguir.
- Se a pasta não existir, informar o caminho inválido e orientar o usuário a rodar `/importar-tarefa` ou corrigir a referência.
- Se a estrutura documental mínima da tarefa não puder ser validada ou normalizada, interromper o fluxo e solicitar a regularização da pasta antes de planejar.
