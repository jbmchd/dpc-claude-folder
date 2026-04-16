# Tarefas – Trello, arquivos e documentação

Ao lidar com tarefas, usar o MCP Trello quando aplicável, operar no board `DPC Dev` e documentar em `.claude/tarefas` ou `.claude/tarefas/cards`.

## 1. Fonte de verdade da tarefa

- Se a tarefa vier do Trello, usar as ferramentas MCP disponíveis no ambiente atual.
- Nao assumir dados do Trello sem consultar o MCP.
- Cards devem ser localizados por link ou `idShort`.
- Se o usuário nao informar card number ou link, perguntar antes de buscar ou documentar.
- O usuário também pode fornecer arquivos, texto na conversa ou ambos.
- Quando houver múltiplas fontes, consolidar tudo e deduplicar cards repetidos.

## 2. Fluxo da tarefa

O fluxo documental da tarefa e dividido nas etapas abaixo:

### 2.1 Importacao

- Executar o fluxo de importacao para criar a pasta local da tarefa via comando `/importar-tarefa`.
- A importacao deve consolidar a fonte principal da tarefa em `conteudo-do-card.md` ou `conteudo-da-tarefa.md`.
- A importacao deve copiar anexos suportados e gerar `metadata.json` quando houver contexto suficiente.
- A importacao deve criar `planejamento.md` e `desenvolvimento.md` como arquivos iniciais da estrutura documental.
- A importacao deve criar `consideracoes.md` contendo o que foi entendido que é pra ser feito na tarefa.
- A importacao de PDF so pode ser concluida com evidencia de extracao de imagens (`images/`) ou justificativa explicita de ausencia de imagens extraiveis.
- A importacao nao deve criar branchs nem gerar planejamento tecnico detalhado.

### 2.2 Planejamento

- O planejamento deve consumir apenas a pasta ja criada pela importacao via comando `/planejar-tarefa`.
- O planejamento deve validar a estrutura minima da pasta antes de prosseguir.
- Em tarefas do `Faisao`, consultar tambem [faisao-principios-projeto.md](../alterar-codigo/faisao-principios-projeto.md) antes de detalhar a solucao e registrar no `planejamento.md` o mapeamento funcional exigido por essa regra.
- O planejamento deve gerar ou atualizar `planejamento.md` e garantir que `desenvolvimento.md` exista com a estrutura minima esperada.
- O planejamento nao deve importar arquivos novamente nem alterar codigo.

### 2.3 Execucao

- A execucao pode alterar codigo no projeto alvo, seguindo as regras especificas do projeto.
- Durante a execucao, `desenvolvimento.md` deve ser atualizado com a linha do tempo, decisoes e o `Resumo tecnico das alteracoes`.
- A execucao **nunca** faz `git commit`, `git push` ou abertura de PR automaticamente. Ao concluir as alteracoes de codigo, parar com a working tree suja e aguardar instrucao explicita do usuario. Isso vale mesmo quando o usuario ja autorizou commit em mensagem anterior — autorizacao nao persiste entre fases.
- Para tarefas de migracao de tela do Maracana para DPC/ApiDPC, seguir [migracao-legado.md](migracao-legado.md) alem deste arquivo.

## 3. Regra de uso do Trello

- Sempre operar no board `DPC Dev`.
- Se precisar do `idBoard`, obtê-lo via MCP a partir da lista de boards acessíveis.
- Se a tarefa explicitamente nao vier do Trello, nao usar ferramentas do Trello.

## 4. Tratamento de arquivos e texto

### 4.1 Detecção de fontes de entrada

Antes de criar qualquer arquivo, identificar todas as fontes presentes na mensagem do usuário:

| Tipo | Como detectar |
|---|---|
| Link do Trello | padrão `trello.com/c/[a-zA-Z0-9]+` no prompt |
| Card number | padrão `#\d{3,5}` ou número isolado no contexto de Trello |
| PDF | arquivo com extensão `.pdf` |
| Imagem avulsa | `.png`, `.jpg`, `.jpeg`, `.webp`, `.gif` |
| Outro documento | `.docx`, `.txt`, `.csv`, `.xlsx`, etc. |
| Texto solto | conteúdo textual no próprio prompt sem ser fonte estruturada |

Consolidar todas as fontes encontradas antes de iniciar qualquer fetch ou escrita em disco.

### 4.2 Trello via Composio

- Usar o MCP Composio para buscar dados do card quando houver link ou card number.
- Buscar obrigatoriamente: título, descrição, lista atual, labels, membros atribuídos, data de criação e due date.
- Buscar obrigatoriamente: checklists completos (nome do checklist + cada item com estado checked/unchecked).
- Buscar obrigatoriamente: comentários do card em ordem cronológica.
- Buscar anexos: para cada anexo do tipo imagem, tentar baixar para `images/trello/` dentro da pasta da tarefa.
- Registrar no `metadata.json` os campos: `id`, `idShort`, `title`, `list`, `labels`, `members`, `due`, `url`.

### 4.3 PDF via pdf_ocr.py

- Copiar o arquivo original para dentro da pasta da tarefa, preservando o nome.
- Executar OCR usando o script em `d:/Joabe/Documents/dev/projetos/joabe/ai-tools/pdf_ocr/pdf_ocr.py`:
  ```bash
  python d:/Joabe/Documents/dev/projetos/joabe/ai-tools/pdf_ocr/pdf_ocr.py <arquivo.pdf> -o ocr.md -v
  ```
- O script gera `ocr.md` com o texto extraído por página via RapidOCR.
- Salvar o `ocr.md` dentro da pasta da tarefa.
- Ao consolidar o conteúdo em `conteudo-do-card.md` ou `conteudo-da-tarefa.md`, referenciar o `ocr.md` e transcrever os trechos relevantes.
- A importação de PDF só pode ser concluída com evidência de geração do `ocr.md` ou justificativa explícita de falha.

### 4.4 Imagens avulsas

- Copiar para `images/` dentro da pasta da tarefa.
- Referenciar no conteúdo consolidado no formato `imagem {n}: images/nome-do-arquivo.png`.

### 4.5 Outros documentos

- Copiar para dentro da pasta da tarefa, preservando os nomes.
- Extrair e consolidar o conteúdo relevante em `conteudo-do-card.md` ou `conteudo-da-tarefa.md`.

### 4.6 Texto solto do prompt

- Capturar como seção `## Contexto adicional` no arquivo de conteúdo consolidado.
- Não descartar nenhuma informação fornecida textualmente pelo usuário.

### 4.7 Consolidação de múltiplas fontes

- Mesclar todas as fontes em `conteudo-do-card.md` (com Trello) ou `conteudo-da-tarefa.md` (sem Trello).
- Separar cada fonte em seção própria com cabeçalho indicando a origem.
- Deduplicar informações repetidas entre fontes.
- Incluir seção de mapeamento de referências visuais ao final quando houver imagens.

Exemplo de estrutura consolidada com múltiplas fontes:

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

Trecho relevante extraído:
...

## Fonte: Imagem — tela-atual.png
imagem {1}: images/tela-atual.png

## Contexto adicional (prompt)
...

## Mapeamento de referências
- {1}: images/tela-atual.png
- {2}: images/trello/anexo-1.png
```

Exemplo recomendado:

```markdown
## Itens da tarefa

1. Verificar o bug do Header na aba de clientes ao selecionar um cliente.
	- imagem {1}: images/page-001-img-01.png

2. Na tela de clientes, quando a busca não retorna resultado, ao clicar no X para limpar, exibir loading durante a nova consulta.
	- imagens {2}: images/page-001-img-02.png, {3}: images/page-001-img-03.png

## Mapeamento de referências
- {1}: images/page-001-img-01.png
- {2}: images/page-001-img-02.png
- {3}: images/page-001-img-03.png
```

## 5. Estrutura da pasta da tarefa

- Garantir a existência de `.claude/tarefas`.
- Se a tarefa tiver card do Trello, garantir também `.claude/tarefas/cards`.
- Para tarefa com Trello, usar pasta no formato `{codigo}-{titulo-em-slug}` dentro de `.claude/tarefas/cards`.
- Para tarefa sem Trello, criar subpasta diretamente em `.claude/tarefas`, com nome em slug e identificador opcional.
- A pasta da tarefa deve conter `metadata.json`, `conteudo-do-card.md` ou `conteudo-da-tarefa.md`, `planejamento.md`, `desenvolvimento.md` e `consideracoes.md`.
- `metadata.json` deve concentrar, quando disponiveis, campos como `title`, `id`, `project`, `sourceType`, `sourceReference` e `branchNameSuggested`.
- Para tarefas com PDF, incluir tambem `pdfAssets` para auditoria da importacao.

## 6. Branch da tarefa

- Seguir [git-workflow-branches.md](git-workflow-branches.md) como fonte canonica para identificar, criar ou reutilizar a branch da tarefa.
- Registrar no `planejamento.md` a seção **Branch** conforme o formato definido nesse arquivo.

## 7. Arquivos mínimos obrigatórios

- `conteudo-do-card.md` (tarefa com Trello) ou `conteudo-da-tarefa.md` (tarefa sem Trello).
- `metadata.json` com os metadados disponiveis da tarefa.
- `planejamento.md` com plano técnico e passos da execução.
- `desenvolvimento.md` com linha do tempo, decisões e mensagem de commit sugerida.
- `consideracoes.md` com o entendimento inicial do que deve ser feito na tarefa.

## 8. Regras para `desenvolvimento.md`

- Registrar ações em ordem cronológica na seção `Linha do tempo`.
- Incluir `Resumo técnico das alterações` sempre que houver modificação de código.
- Em `Resumo técnico das alterações`, registrar arquivos alterados, tipo da mudança e impactos principais.
- A seção `Mensagem de commit sugerida` deve ser sempre a última do arquivo.

Template resumido:

```markdown
# Desenvolvimento – Card {numero} {titulo}

## Linha do tempo
- YYYY-MM-DD HH:MM – ação realizada

## Resumo técnico das alterações
- Arquivos alterados: caminhos principais impactados pela demanda
- Tipo da mudança: bugfix, feature, refactor, docs ou equivalente
- Impactos principais: resumo objetivo do que mudou

## Decisões e regras de negócio
- Decisão ou regra relevante

## Observações técnicas
- Opcional

## Mensagem de commit sugerida

Mensagem em português que resuma o estado atual das mudanças.
```

## 9. Limite operacional

- Quando o fluxo pedido for apenas de planejamento ou documentação, nao iniciar alterações de código.
