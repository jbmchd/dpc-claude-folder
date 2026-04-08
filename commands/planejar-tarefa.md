Gere ou atualize o planejamento de uma tarefa a partir de uma pasta local já criada, consumindo apenas os arquivos presentes nela. Consulte [tarefas.md](.claude/docs/regras/gerenciar-regras/tarefas.md) e [git-workflow-branches.md](.claude/docs/regras/gerenciar-regras/git-workflow-branches.md) como fontes canônicas.

## Limitações
- Não alterar código nem criar branches neste fluxo.
- Não importar arquivos; consumir apenas o que está na pasta informada.

## Validações obrigatórias

Antes de qualquer ação, confirmar que a pasta informada existe e contém a estrutura mínima definida em `tarefas.md`, incluindo `consideracoes.md`. Se a pasta for inválida, incompleta ou `consideracoes.md` ausente, interromper e orientar o usuário a rodar `/importar-tarefa` antes de prosseguir.

## Regras de execução

- Se o caminho da pasta não for informado, perguntar antes de seguir.
- Ler `metadata.json`, `conteudo-do-card.md` ou `conteudo-da-tarefa.md`, `consideracoes.md` e as imagens em `images/` para extrair contexto completo da tarefa.
- Consultar os docs do projeto alvo em [regras/alterar-codigo](.claude/docs/regras/alterar-codigo/) antes de definir a abordagem.
- Em tarefas do `Faisao`, registrar no `planejamento.md` o mapeamento funcional exigido por [faisao-principios-projeto.md](.claude/docs/regras/alterar-codigo/faisao-principios-projeto.md), destacando regras de negócio, contratos, validações e inteligências que precisam ser preservados.
- Gerar ou atualizar `planejamento.md` seguindo a estrutura definida em `tarefas.md`.
- Preencher a seção **Branch** do `planejamento.md` conforme `git-workflow-branches.md`.
- Garantir que `desenvolvimento.md` exista com a estrutura mínima definida em `tarefas.md`, sem registrar alterações que ainda não aconteceram.

## Encerramento

- Finalizar com resumo do planejamento e dos próximos passos, deixando claro que a etapa seguinte é `/executar-tarefa`.
- Se a estrutura documental não puder ser validada ou normalizada, interromper e solicitar regularização antes de planejar.
