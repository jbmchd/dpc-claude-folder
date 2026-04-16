# /planejar-tarefa

**Objetivo:** gerar ou atualizar o `planejamento.md` de uma tarefa consumindo apenas os arquivos da pasta já criada.

**Entrada:** caminho da pasta da tarefa (se não informado, perguntar).

**Saída:** `planejamento.md` atualizado com escopo técnico, passos, riscos e seção **Branch**; `desenvolvimento.md` garantido com estrutura mínima.

**Não faz:** alterar código, criar branches, importar arquivos novamente.

**Fluxo detalhado:** [tarefas.md §2.2 e §6](../docs/regras/gerenciar-regras/tarefas.md) · [git-workflow-branches.md](../docs/regras/gerenciar-regras/git-workflow-branches.md).

**Pré-condições:**
- Pasta existe e contém a estrutura mínima (`metadata.json`, `conteudo-*.md`, `consideracoes.md`, `planejamento.md`, `desenvolvimento.md`).
- Se faltar algum arquivo obrigatório → interromper e orientar rodar `/importar-tarefa`.

**Obrigatório no `planejamento.md`:**
- Seção **Branch** com nome, origem da decisão, base e status — conforme `git-workflow-branches.md`.
- Aviso destacado no topo da seção Branch: antes de qualquer alteração de código em `/executar-tarefa`, atualizar a branch base (`git pull`), criar/checkout da branch da tarefa e só então codificar.
- Consulta prévia aos docs em [alterar-codigo/](../docs/regras/alterar-codigo/) do projeto alvo.
- Em tarefas do Faisao, mapeamento funcional cross-project conforme [faisao-convencoes.md](../docs/regras/alterar-codigo/faisao-convencoes.md).

**Encerramento:** resumo do planejamento e próximos passos, deixando claro que a etapa seguinte é `/executar-tarefa`.
