# Prompt — Gerar documentação inteligente para workspace Claude Code

> Cole este prompt em uma sessão Claude Code no novo workspace.
> Substitua os placeholders `{{...}}` antes de executar.

---

## Prompt

```
Preciso que você gere toda a estrutura de documentação inteligente do Claude Code para este workspace. O objetivo é que o agente tenha contexto profundo sobre os projetos, regras claras de como alterar código, e fluxos operacionais reproduzíveis via slash commands.

Siga o plano abaixo fase a fase. Não pule etapas. Antes de gerar qualquer arquivo, explore o codebase real deste workspace para extrair informações factuais — nunca invente estrutura, stacks ou convenções.

---

### FASE 0 — Descoberta do workspace

Antes de escrever qualquer arquivo:

1. Listar todos os projetos/pastas raiz do workspace (ex.: `ls`, `find . -maxdepth 2 -name "package.json" -o -name "composer.json" -o -name "requirements.txt" -o -name "go.mod" -o -name "Cargo.toml" -o -name "*.sln" -o -name "*.csproj"`).
2. Para cada projeto encontrado, identificar:
   - Stack/framework (ler package.json, composer.json, etc.)
   - Linguagem e versão (ler configs, Dockerfiles, .tool-versions)
   - Estrutura de pastas principal (src/, app/, routes/, components/, screens/, etc.)
   - Padrão de autenticação (JWT, session, OAuth)
   - Bancos de dados usados (ler .env, configs de conexão)
   - Deploy (Dockerfile, CI/CD, scripts)
3. Mapear como os projetos se comunicam entre si (API calls, imports, shared DB, eventos).
4. Identificar MCPs configurados em:
   - `C:\Users\joabe\AppData\Roaming\Code\User\mcp.json`
   - `C:\Users\joabe\.cursor\mcp.json`
   - `C:\Users\joabe\.claude\settings.json`
   - `.claude/settings.json` no workspace
   - `.mcp.json` na raiz do projeto
5. Apresentar um resumo da descoberta e pedir confirmação antes de prosseguir.

---

### FASE 1 — Estrutura base `.claude/`

Criar a árvore de diretórios:

```
.claude/
├── CLAUDE.md                          # Regras globais (hub central)
├── settings.json                      # Permissões e hooks
├── agents/
│   ├── blueprint-mode.md              # Agente de engenharia estruturada
│   └── context7.md                    # Agente de documentação de libs
├── commands/
│   ├── importar-tarefa.md             # Importação de tarefas
│   ├── planejar-tarefa.md             # Planejamento técnico
│   └── executar-tarefa.md             # Execução com registro
├── docs/
│   ├── arquitetura/
│   │   ├── visao-geral-ecossistema.md # Visão do ecossistema + diagrama Mermaid
│   │   └── <projeto>-arquitetura.md   # Um por projeto
│   ├── regras/
│   │   ├── alterar-codigo/
│   │   │   ├── _checklist-base-bug.md         # Checklist genérico de bugfix
│   │   │   ├── _checklist-base-feature.md     # Checklist genérico de feature
│   │   │   ├── <projeto>-convencoes.md        # Convenções por projeto
│   │   │   ├── <projeto>-checklist-corrigir-bug.md  # Delta de bug por projeto
│   │   │   └── <projeto>-checklist-nova-feature.md  # Delta de feature por projeto
│   │   └── gerenciar-regras/
│   │       ├── criar-regras.md         # Meta-regra: como criar/alterar docs
│   │       ├── git-workflow-branches.md # Fluxo de branches por tarefa
│   │       └── tarefas.md              # Fluxo canônico de tarefas
├── hooks/
│   └── validate-protected-paths.py     # Hook de proteção de paths
└── temp/                               # Área temporária (não versionada)
```

---

### FASE 2 — `CLAUDE.md` (hub central)

Gerar o CLAUDE.md com estas seções, preenchidas a partir da descoberta:

```markdown
# {{Nome do Workspace}}

## Escopo
- Workspace contém {{projetos}}. Regras valem para todos os agentes e sessões.

## Regras transversais
- Identificar projeto e área afetados antes de alterar código.
- Preferir mudanças pequenas, aderentes ao padrão existente; evitar refatorações fora do escopo.
- Preservar contratos entre {{camadas/projetos que se comunicam}}.
- Nunca alterar `node_modules/**` sem pedido explícito na mesma mensagem.
- Dúvida estrutural → consultar `.claude/docs` antes de agir.
- Não copiar conteúdo longo de doc para a resposta quando um link resolve.

## Locais protegidos
- `.claude/docs/**`, `.claude/agents/**`, `.claude/commands/**`, `CLAUDE.md`.
- Só alterar com pedido explícito citando o caminho.

## MCPs obrigatórios
{{listar MCPs descobertos e seu propósito}}

## Índice de documentação
| Preciso de… | Arquivo |
|---|---|
| Visão do ecossistema | [visao-geral-ecossistema.md](...) |
| Arquitetura de {{projeto}} | [{{projeto}}-arquitetura.md](...) |
| Convenções de {{projeto}} | [{{projeto}}-convencoes.md](...) |
| Checklist bug/feature | [{{projeto}}-checklist-*.md](...) |
| Fluxo de tarefas | [tarefas.md](...) |
| Branches | [git-workflow-branches.md](...) |
| Criar/alterar regras | [criar-regras.md](...) |

## Regras por projeto
{{Para cada projeto: nome, path, stack — link para convenções}}

## Bugfix e nova feature
- Consultar o checklist do projeto alvo.
- Bugfix: reprodução → causa-raiz → menor mudança segura → validação de impacto colateral.
- Feature: validar arquitetura, contratos e impactos cross-project antes de propor mudanças.

## Tarefas
- Fluxo canônico: tarefas.md + commands /importar-tarefa, /planejar-tarefa, /executar-tarefa.
- Execução nunca commita, faz push ou abre PR automaticamente.

## Documentação
- Toda doc nova fica em `.claude/docs/`, em markdown, com recursos visuais quando possível.
```

---

### FASE 3 — Documentação de arquitetura

Para cada projeto e para o ecossistema geral, gerar docs baseados em leitura real do código:

#### `visao-geral-ecossistema.md`
- Tabela resumo dos projetos (nome, papel, link para doc específica)
- Diagrama Mermaid (`flowchart TB`) mostrando: clientes, APIs, bancos, serviços externos
- Tabela de interações (De → Para → O quê)
- Seção de autenticação
- Seção de dados e integrações
- Seção de deploy/ambientes
- Referências cruzadas para docs específicos

#### `<projeto>-arquitetura.md` (um por projeto)
Extrair do código real:
- Stack e versões (ler package.json, Dockerfile, etc.)
- Estrutura de pastas com propósito de cada uma
- Camadas (controller/service/repo, components/screens/state)
- Padrão de autenticação
- Conexões com banco de dados
- Integrações externas
- Riscos e dívida técnica observados
- Deploy e variáveis de ambiente

---

### FASE 4 — Convenções de código por projeto

Para cada projeto, gerar `<projeto>-convencoes.md` lendo o código existente:

- Cabeçalho com stack, path e link para arquitetura
- Organização de arquivos/módulos
- Padrões de nomenclatura (variáveis, funções, arquivos, rotas)
- Padrão de imports
- Gerenciamento de estado
- Padrão de resposta/contrato de API
- Componentes compartilhados
- Config e variáveis de ambiente
- Padrões assíncronos relevantes

Importante: extrair convenções do código real, não inventar. Se o projeto mistura padrões, documentar o que existe e qual é o predominante.

---

### FASE 5 — Checklists de bug e feature

#### `_checklist-base-bug.md` (genérico)
```markdown
# Checklist base — corrigir bug
### Reprodução e escopo
- [ ] Reproduzir o bug em ambiente controlado
- [ ] Identificar a camada exata onde ocorre
- [ ] Verificar se o padrão existe em outros pontos

### Análise de impacto
- [ ] Listar chamadores/consumidores do código afetado
- [ ] Verificar dependências diretas
- [ ] Revisar testes que cobrem a área

### Correção mínima
- [ ] Aplicar a menor alteração possível
- [ ] Manter o padrão do projeto
- [ ] Não remover validações sem alternativa segura

### Validação
- [ ] Testar o cenário que falhava
- [ ] Testar cenários de sucesso do mesmo fluxo
- [ ] Testar fluxos relacionados
- [ ] Testar bordas (token inválido, rede off, dados vazios)

### Regressão e entrega
- [ ] Rodar suíte de testes
- [ ] Revisar diff: sem logs de debug, sem alterações fora de escopo
- [ ] Registrar em desenvolvimento.md causa-raiz e alteração
```

#### `_checklist-base-feature.md` (genérico)
```markdown
# Checklist base — nova feature
### Antes de codar
- [ ] Entender domínio, dados e contratos afetados
- [ ] Verificar código/camada reaproveitável
- [ ] Definir contrato da API
- [ ] Verificar permissões e autenticação

### Estrutura
- [ ] Criar arquivos respeitando organização existente
- [ ] Manter separação de responsabilidades
- [ ] Reutilizar componentes/utilitários compartilhados

### Estado e dados
- [ ] Escolher forma de estado adequada ao padrão do projeto
- [ ] Tratar loading, erro e estado vazio
- [ ] Validar entradas

### Testes e build
- [ ] Ao menos um teste no fluxo principal
- [ ] Rodar testes e build locais
- [ ] Testar casos de borda

### Revisão final
- [ ] Nomenclatura alinhada ao padrão
- [ ] Contrato de resposta no formato padrão
- [ ] Sem lógica de negócio no lugar errado
- [ ] Registrar em desenvolvimento.md
```

#### `<projeto>-checklist-*.md` (delta por projeto)
Gerar um checklist delta para cada projeto com passos específicos daquela stack (ex.: comandos de teste, camadas a verificar, ferramentas).

---

### FASE 6 — Regras de gerenciamento

#### `criar-regras.md`
Documentar:
- Onde fica cada tipo de arquivo (.claude/)
- Quando criar CLAUDE.md vs command vs agent vs doc
- Padrões de nomeação
- Checklist ao criar/alterar regra
- Otimização de contexto (commands curtos, detalhes em docs)
- Regras para evitar quebra

#### `git-workflow-branches.md`
- Identificação do nome da branch (fontes de verdade)
- Pré-condição: árvore limpa
- Detecção da branch base (main/master)
- Fluxo branch existente vs nova
- Remoto configurado
- Registro obrigatório no planejamento

#### `tarefas.md`
- Fonte de verdade (Trello/Linear/Jira — o que o workspace usar)
- Fluxo em 3 fases: importação → planejamento → execução
- Tratamento de fontes de entrada (cards, PDFs, imagens, texto)
- Estrutura da pasta da tarefa
- Template de desenvolvimento.md
- Limites operacionais (não commitar automaticamente)

---

### FASE 7 — Commands (slash commands)

Gerar commands curtos e operacionais:

#### `/importar-tarefa`
- Objetivo, entradas aceitas, saídas, exceções, link para tarefas.md

#### `/planejar-tarefa`
- Objetivo, entrada, saída, pré-condições, obrigatórios no planejamento.md, link para tarefas.md

#### `/executar-tarefa`
- Objetivo, entrada, saída, pré-condições, docs carregados por projeto, exceções, link para tarefas.md
- NUNCA faz git commit/push/PR automaticamente

---

### FASE 8 — Agents

#### `blueprint-mode.md`
Copiar o agente Blueprint Mode (engenheiro sênior pragmático com workflows Debug/Express/Main/Loop, self-reflection, comunicação mínima). Adaptar a seção de contexto do workspace.

#### `context7.md`
Copiar o agente Context7 Expert (especialista em docs de libs via MCP Context7, nunca responde de memória).

---

### FASE 9 — Settings e hooks

#### `settings.json`
```json
{
  "permissions": {
    "allow": [
      "Bash(git:*)",
      "Bash(ls:*)",
      "Bash(cat:*)",
      "Bash(find:*)",
      "Bash(grep:*)",
      "Bash(npm:*)",
      "Bash(node:*)"
    ]
  },
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": "python {{caminho}}/hooks/validate-protected-paths.py"
          }
        ]
      }
    ]
  }
}
```

Adaptar as permissões às stacks do workspace (adicionar php, composer, python, go, etc. conforme necessário).

#### `hooks/validate-protected-paths.py`
```python
import json, sys, os

data = json.load(sys.stdin)
tool_input = data.get("tool_input", {})
path = tool_input.get("file_path", "")

if not path:
    sys.exit(0)

path = path.replace("\\", "/")

PROTECTED = ["/.claude/docs/", "/.claude/agents/", "/.claude/commands/"]
PROTECTED_FILES = ["CLAUDE.md"]

blocked = any(p in path for p in PROTECTED)
if not blocked:
    blocked = any(path.endswith(f) or f"/{f}" in path for f in PROTECTED_FILES)

if blocked:
    print(f"AVISO: '{os.path.basename(path)}' está em local protegido.")
    print("Só altere locais protegidos quando o usuário pedir explicitamente.")

sys.exit(0)
```

---

### FASE 10 — Validação final

Após gerar tudo:

1. Verificar que todos os links em CLAUDE.md apontam para arquivos existentes.
2. Verificar que nenhum doc repete conteúdo extenso de outro.
3. Confirmar que commands são curtos (objetivo/entradas/saídas/exceções/link).
4. Confirmar que agents têm frontmatter com name, description, model.
5. Listar os arquivos criados em formato de árvore.
6. Perguntar ao usuário se quer ajustes ou docs adicionais.

---

### Regras gerais para todo o processo

- TODO conteúdo deve vir da leitura real do código, não de suposição.
- Markdown com recursos visuais (tabelas, diagramas Mermaid, listas) quando possível.
- Convenções extraídas do padrão predominante no código — documentar divergências, não escondê-las.
- Docs longos ficam em `.claude/docs/`; commands e CLAUDE.md ficam curtos com links.
- Não criar docs redundantes. Um fato = um lugar canônico.
- Comentários e nomes de seção em português (padrão do workspace).
```
