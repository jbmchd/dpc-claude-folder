# /importar-tarefa

**Objetivo:** criar a pasta local da tarefa e consolidar fontes de entrada (Trello, PDF, imagens, outros documentos, texto no prompt).

**Entradas aceitas:** link do Trello, card number (`#NNNN`), PDF, imagens, outros documentos, texto solto no prompt — isoladamente ou combinados.

**Saídas:**
- Pasta em `d:/Joabe/Documents/dev/projetos/dpc/.claude-work-items/cards/{codigo}-{slug}/` (com Trello) ou `d:/Joabe/Documents/dev/projetos/dpc/.claude-work-items/{slug}/` (sem Trello).
- Arquivos mínimos: `metadata.json`, `conteudo-do-card.md` ou `conteudo-da-tarefa.md`, `consideracoes.md`, `planejamento.md` (inicial), `desenvolvimento.md` (inicial), anexos copiados (`images/` + outros).

**Não faz:** alterar código, criar branch, gerar planejamento técnico, processar vídeos.

**Fluxo detalhado:** [tarefas.md §2.1 e §4](../docs/regras/gerenciar-regras/tarefas.md).

**Exceções:**
- Sem informação para nomear a pasta ou identificar o projeto → interromper e perguntar antes de criar qualquer arquivo.
- PDF sem `ocr.md` gerado → bloquear a conclusão ou documentar justificativa explícita de falha.
- Tarefa de migração de tela do Maracanã → seguir também [migracao-legado.md](../docs/regras/gerenciar-regras/migracao-legado.md).

**Encerramento:** informar o caminho da pasta criada e que o próximo passo é `/planejar-tarefa`.
