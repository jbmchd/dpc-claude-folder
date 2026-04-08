Crie a pasta local da tarefa, importe os arquivos de origem e gere a estrutura documental mínima para planejamento posterior. Consulte [tarefas.md](.claude/docs/regras/gerenciar-regras/tarefas.md) como fonte canônica da estrutura esperada.

## Limitações
- Não alterar código nem criar branches neste fluxo.
- Não processar vídeos.
- Não gerar planejamento técnico detalhado; apenas prepare para `/planejar-tarefa`.

## Fase 0 — Detecção de entradas

Antes de qualquer ação, identificar todas as fontes na mensagem:
- Link do Trello (`trello.com/c/...`) ou card number (`#NNNN`)
- PDFs, imagens (`.png`, `.jpg`, `.jpeg`, `.webp`, etc.), outros documentos
- Texto solto no prompt

**Toda imagem, de qualquer fonte, vai para `images/` dentro da pasta da tarefa.**

## Fase 1 — Coleta por fonte

### Trello
Buscar via MCP Composio: título, descrição, lista atual, labels, membros, due date, checklists completos (nome + itens com estado), comentários em ordem cronológica.
Anexos: listar URLs no conteúdo consolidado. **Não baixar imagens do Trello** — não é permitido.

### PDF
Copiar o arquivo para a pasta da tarefa e executar OCR:
```bash
python d:/Joabe/Documents/dev/projetos/joabe/ai-tools/pdf_ocr/pdf_ocr.py <arquivo.pdf> -o ocr.md -v
```

### Imagens e outros documentos
Copiar para a pasta da tarefa (imagens em `images/`), preservando os nomes.

### Texto solto
Capturar como `## Contexto adicional` no conteúdo consolidado.

## Fase 2 — Consolidação

Mesclar todas as fontes em `conteudo-do-card.md` (com Trello) ou `conteudo-da-tarefa.md` (sem Trello), cada fonte em seção própria com cabeçalho de origem. Deduplicar. Incluir mapeamento de referências visuais quando houver imagens. Seguir o formato definido em `tarefas.md`.

## Fase 3 — Estrutura documental

- Pasta em `.claude/tarefas/cards/{codigo}-{slug}` (com Trello) ou `.claude/tarefas/{slug}` (sem Trello).
- Criar `metadata.json` com os campos disponíveis: `title`, `id`, `idShort`, `project`, `sourceType`, `sourceReference`, `list`, `labels`, `members`, `due`, `url`, `branchNameSuggested`.
- Criar `consideracoes.md`, `planejamento.md` e `desenvolvimento.md`.

## Encerramento

- Se faltar contexto para nomear a pasta ou identificar o projeto, interromper e perguntar antes de criar qualquer arquivo.
- PDF sem `ocr.md` gerado: bloquear conclusão ou documentar justificativa explícita de falha.
- Ao concluir: informar o caminho da pasta criada e que o próximo passo é `/planejar-tarefa`.
