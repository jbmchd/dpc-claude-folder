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
Executar o script de importação passando o card ID ou URL:
```bash
python3 d:/Joabe/Documents/dev/projetos/joabe/ai-tools/trello/trello_card.py <card_id_ou_url>
```
O script gera `d:/Joabe/Documents/dev/projetos/joabe/ai-tools/trello/<idShort>/`:
- `card_data.json` — todos os dados do card (título, descrição, lista, labels, membros, due date, checklists, comentários, attachments)
- `attachments/` — todos os anexos baixados (imagens, PDFs, documentos, etc.) com nome no formato `<nome>_<id>.<ext>`

Após execução:
1. Ler `card_data.json` como fonte dos dados do card.
2. Para cada arquivo em `attachments/`:
   - Imagens (`.png`, `.jpg`, `.jpeg`, `.webp`, `.gif`, `.bmp`) → mover para `images/`
   - Demais arquivos → mover para a raiz da pasta da tarefa
3. Todos os anexos devem ser listados e referenciados no conteúdo consolidado.
4. Limpar a pasta temporária gerada pelo script (`<idShort>/`).

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
