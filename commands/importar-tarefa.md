# /importar-tarefa

**Objetivo:** criar a pasta local da tarefa e consolidar fontes de entrada (Trello, PDF, imagens, outros documentos, texto no prompt).

**Entradas aceitas:** link do Trello, card number (`#NNNN`), PDF, imagens, outros documentos, texto solto no prompt — isoladamente ou combinados.

**Saídas:**
- Pasta em `d:/Joabe/Documents/dev/projetos/dpc/.claude-work-items/cards/{codigo}-{slug}/` (com Trello) ou `d:/Joabe/Documents/dev/projetos/dpc/.claude-work-items/{slug}/` (sem Trello).
- Arquivos mínimos: `metadata.json`, `conteudo-do-card.md` ou `conteudo-da-tarefa.md`, `consideracoes.md`, `planejamento.md` (inicial), `desenvolvimento.md` (inicial), anexos copiados (`images/` + outros).

**Não faz:** alterar código, criar branch, gerar planejamento técnico, processar vídeos.

**Múltiplos cards ([tarefas.md §9](../docs/regras/gerenciar-regras/tarefas.md)):**
- **Modo A (separados):** invocado uma vez por card pelo orquestrador → cada chamada cria uma pasta single-card normal. Sem lógica especial aqui.
- **Modo B (mesclados):** invocado uma vez com todos os cards → cria **uma** pasta `cards/{codigo-primeiro}-{slug}/`, com `conteudo-do-card.md` consolidando cada card em uma seção `## Fonte: Trello #NNNN` (reuso da consolidação de §4.7) e `metadata.json` com o array `cards: [...]` (§5).

**Fluxo detalhado:** [tarefas.md §2.1 e §4](../docs/regras/gerenciar-regras/tarefas.md).

**Exceções:**
- Sem informação para nomear a pasta ou identificar o projeto → interromper e perguntar antes de criar qualquer arquivo.
- PDF sem `ocr.md` gerado → bloquear a conclusão ou documentar justificativa explícita de falha.
- Tarefa de migração de tela do Maracanã → seguir também [migracao-legado.md](../docs/regras/gerenciar-regras/migracao-legado.md).

**Modificador `--explicar`:** se a invocação trouxer `--explicar`, após concluir a importação, rodar [`/explicar`](explicar.md) sobre a pasta criada e gerar `explicacao.md`. Não altera os limites desta fase.

**Encerramento:** informar o caminho da pasta criada e que o próximo passo é `/planejar-tarefa`.
