# Tarefas — Trello, arquivos e documentação

Fonte canônica do fluxo de tarefas no workspace DPC. Os commands `/importar-tarefa`, `/planejar-tarefa` e `/executar-tarefa` são stubs finos que apontam para este arquivo.

## 1. Fonte de verdade da tarefa

- Se a tarefa vier do Trello, usar o MCP Trello (board `DPC Dev`), localizando o card por link ou `idShort`.
- Nunca assumir dados do Trello sem consultar.
- Se o usuário não informar card number ou link, perguntar antes de buscar ou documentar.
- O usuário pode também fornecer arquivos, texto no prompt, ou ambos.
- Quando houver múltiplas fontes, consolidar tudo e deduplicar.

## 2. Fluxo em 3 fases

### 2.1 Importação (`/importar-tarefa`)
- Cria a pasta da tarefa e consolida a fonte principal em `conteudo-do-card.md` (com Trello) ou `conteudo-da-tarefa.md` (sem Trello).
- Copia anexos suportados; gera `metadata.json` quando houver contexto.
- Cria `planejamento.md`, `desenvolvimento.md` e `consideracoes.md` como arquivos iniciais.
- PDF só encerra com evidência de `ocr.md` ou justificativa explícita.
- **Não** cria branch nem gera planejamento técnico.

### 2.2 Planejamento (`/planejar-tarefa`)
- Consome apenas a pasta já criada; não importa arquivos novos.
- Valida estrutura mínima; se incompleta, orienta rodar `/importar-tarefa` antes.
- Consulta os docs do projeto alvo em `alterar-codigo/` antes de definir a abordagem.
- Em tarefas do Faisao, aplica a regra de mapeamento cross-project (`faisao-convencoes.md`).
- Gera/atualiza `planejamento.md` e preenche a seção **Branch** via `git-workflow-branches.md`.
- **Não** altera código.

### 2.3 Execução (`/executar-tarefa`)
- Valida que a pasta tem `planejamento.md` (com Branch), `desenvolvimento.md`, `consideracoes.md` e `metadata.json` com `project`.
- Carrega os docs do projeto alvo (checklists bug/feature + convenções).
- Executa o fluxo de branch de `git-workflow-branches.md`; não avança com árvore suja.
- Implementa seguindo os checklists e convenções.
- Atualiza `desenvolvimento.md` durante e ao final.
- **Nunca** faz `git commit`, `git push` ou abre PR automaticamente. Encerra com árvore suja e aguarda instrução. Autorização prévia não persiste entre fases.
- Tarefas de migração Maracanã → DPC/ApiDPC seguem também [migracao-legado.md](migracao-legado.md).

## 3. Trello
- Operar sempre no board `DPC Dev`.
- `idBoard` vem do MCP a partir da lista de boards acessíveis.
- Se a tarefa explicitamente não vier do Trello, não usar ferramentas do Trello.

## 4. Tratamento de fontes de entrada

### 4.1 Detecção

| Tipo | Como detectar |
|---|---|
| Link do Trello | padrão `trello.com/c/[a-zA-Z0-9]+` |
| Card number | padrão `#\d{3,5}` ou número isolado no contexto de Trello |
| PDF | `.pdf` |
| Imagem avulsa | `.png`, `.jpg`, `.jpeg`, `.webp`, `.gif` |
| Outro documento | `.docx`, `.txt`, `.csv`, `.xlsx`, etc. |
| Texto solto | conteúdo textual no prompt sem ser fonte estruturada |

Consolidar todas as fontes antes de iniciar fetch ou escrita em disco. **Toda imagem, de qualquer fonte, vai para `images/` dentro da pasta da tarefa.**

### 4.2 Trello via `trello_card.py`

Executar o script de importação passando card ID ou URL:
```bash
python3 d:/Joabe/Documents/dev/projetos/joabe/ai-tools/trello/trello_card.py <card_id_ou_url>
```
O script gera `d:/Joabe/Documents/dev/projetos/joabe/ai-tools/trello/<idShort>/`:
- `card_data.json` — dados do card (título, descrição, lista, labels, membros, due, checklists, comentários, attachments).
- `attachments/` — anexos baixados com nome `<nome>_<id>.<ext>`.

Após execução:
1. Ler `card_data.json` como fonte dos dados do card.
2. Para cada arquivo em `attachments/`:
   - Imagens (`.png`, `.jpg`, `.jpeg`, `.webp`, `.gif`, `.bmp`) → mover para `images/`.
   - Demais arquivos → mover para a raiz da pasta da tarefa.
3. Todos os anexos devem ser listados e referenciados no conteúdo consolidado.
4. Limpar a pasta temporária gerada pelo script (`<idShort>/`).

Campos obrigatórios no `metadata.json`: `id`, `idShort`, `title`, `list`, `labels`, `members`, `due`, `url`.

### 4.3 PDF via `pdf_ocr.py`

```bash
python d:/Joabe/Documents/dev/projetos/joabe/ai-tools/pdf_ocr/pdf_ocr.py <arquivo.pdf> -o ocr.md -v
```
- Copiar o PDF original para a pasta da tarefa.
- Salvar o `ocr.md` na mesma pasta.
- Referenciar o `ocr.md` no conteúdo consolidado e transcrever os trechos relevantes.
- Importação só é concluída com `ocr.md` gerado ou justificativa explícita de falha.

### 4.4 Imagens avulsas
- Copiar para `images/`, preservando o nome.
- Referenciar no conteúdo consolidado como `imagem {n}: images/nome-do-arquivo.png`.

### 4.5 Outros documentos
- Copiar para a pasta da tarefa preservando o nome.
- Extrair e consolidar o conteúdo relevante no arquivo principal.

### 4.6 Texto solto do prompt
- Capturar como seção `## Contexto adicional` no conteúdo consolidado.
- Não descartar nenhuma informação fornecida textualmente.

### 4.7 Consolidação

Mesclar todas as fontes em `conteudo-do-card.md` (com Trello) ou `conteudo-da-tarefa.md` (sem Trello), cada fonte em seção própria com cabeçalho de origem. Deduplicar. Incluir mapeamento de referências visuais ao final quando houver imagens.

Exemplo:

```markdown
## Fonte: Trello #3057
**Título:** #DPC - EDI - Cadastro de Projetos
**Lista:** Fazendo | **Labels:** Novo | **Membros:** Joabe

### Descrição
...

### Checklists
- [x] Item 1
- [ ] Item 2

### Comentários
- 2026-04-01 Joabe: observação registrada

## Fonte: PDF — requisitos.pdf
(ver ocr.md para texto completo)
...

## Fonte: Imagem — tela-atual.png
imagem {1}: images/tela-atual.png

## Contexto adicional (prompt)
...

## Mapeamento de referências
- {1}: images/tela-atual.png
- {2}: images/trello/anexo-1.png
```

## 5. Estrutura da pasta da tarefa

- Base: `d:/Joabe/Documents/dev/projetos/dpc/.claude-work-items/`.
- Com Trello: `d:/Joabe/Documents/dev/projetos/dpc/.claude-work-items/cards/{codigo}-{titulo-em-slug}/`.
- Sem Trello: `d:/Joabe/Documents/dev/projetos/dpc/.claude-work-items/{slug}/` (com identificador opcional).
- Arquivos mínimos obrigatórios:
  - `conteudo-do-card.md` ou `conteudo-da-tarefa.md`
  - `metadata.json`
  - `consideracoes.md` — entendimento inicial da tarefa
  - `planejamento.md` — plano técnico e passos
  - `desenvolvimento.md` — linha do tempo + resumo técnico
- `metadata.json` deve ter, quando disponíveis: `title`, `id`, `idShort`, `project`, `sourceType`, `sourceReference`, `list`, `labels`, `members`, `due`, `url`, `branchNameSuggested`. Para tarefas com PDF, incluir `pdfAssets`.

## 6. Branch

- Fonte canônica: [git-workflow-branches.md](git-workflow-branches.md).
- `planejamento.md` tem seção **Branch** com nome, origem da decisão, branch base e status (existente/nova).
- Pré-condição obrigatória em `/executar-tarefa`: antes de qualquer alteração de código, atualizar a base (`main`/`master` via `git pull`), criar/checkout da branch da tarefa, e só então iniciar a codificação.

## 7. `desenvolvimento.md`

- Registrar ações em ordem cronológica na seção `Linha do tempo`.
- `Resumo técnico das alterações` sempre que houver modificação de código (arquivos alterados, tipo da mudança, impactos).
- `Mensagem de commit sugerida` deve ser sempre a última seção do arquivo.

Template:

```markdown
# Desenvolvimento – Card {numero} {titulo}

## Linha do tempo
- YYYY-MM-DD HH:MM – ação realizada

## Resumo técnico das alterações
- Arquivos alterados: caminhos principais impactados
- Tipo da mudança: bugfix, feature, refactor, docs, etc.
- Impactos principais: resumo objetivo do que mudou

## Decisões e regras de negócio
- Decisão ou regra relevante

## Observações técnicas
- Opcional

## Mensagem de commit sugerida

Mensagem em português que resuma o estado atual das mudanças.
```

## 8. Limite operacional

- Quando o fluxo pedido for apenas planejamento ou documentação, não iniciar alterações de código.
