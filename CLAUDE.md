# DPC Workspace

## Escopo
- Workspace contém ApiDPC, DPC e Faisao. Regras valem para todos os agentes e sessões.

## Regras transversais
- Identificar projeto e área afetados antes de alterar código.
- Preferir mudanças pequenas, aderentes ao padrão existente; evitar refatorações fora do escopo.
- Preservar contratos entre frontend, mobile e API.
- Nunca alterar `node_modules/**` sem pedido explícito na mesma mensagem.
- Dúvida estrutural → consultar `.claude/docs` antes de agir.
- Não copiar conteúdo longo de doc para a resposta quando um link resolve.

## Locais protegidos
- `.claude/docs/**`, `.claude/agents/**`, `.claude/commands/**`, `CLAUDE.md`.
- Só alterar com pedido explícito citando o caminho. Default: leitura; pedir confirmação antes de edit/rename/move/delete.

## MCPs obrigatórios
- Documentação externa → MCP `context7`.
- Banco de dados → MCP DPC.
- Trello → MCP Trello (board `DPC Dev`, card por `idShort` ou link).

## Índice de documentação

| Preciso de… | Arquivo |
|---|---|
| Visão do ecossistema e contratos cross-project | [visao-geral-ecossistema-dpc.md](.claude/docs/arquitetura/visao-geral-ecossistema-dpc.md) |
| Arquitetura detalhada por projeto | `.claude/docs/arquitetura/<projeto>-arquitetura.md` |
| Convenções de código por projeto | `.claude/docs/regras/alterar-codigo/<projeto>-convencoes.md` |
| Checklist bug / feature por projeto | `.claude/docs/regras/alterar-codigo/<projeto>-checklist-corrigir-bug.md` e `-nova-feature.md` |
| Fluxo de tarefas e Trello | [tarefas.md](.claude/docs/regras/gerenciar-regras/tarefas.md) |
| Branch da tarefa | [git-workflow-branches.md](.claude/docs/regras/gerenciar-regras/git-workflow-branches.md) |
| Criar/alterar regras, commands, agentes, docs | [criar-regras.md](.claude/docs/regras/gerenciar-regras/criar-regras.md) |
| Migração Maracanã → DPC/ApiDPC | [migracao-legado.md](.claude/docs/regras/gerenciar-regras/migracao-legado.md) |
| Padrões Oracle (ApiDPC) | [apidpc-oracle-padroes.md](.claude/docs/regras/alterar-codigo/apidpc-oracle-padroes.md) |
| Padrões async Vue (DPC) | [dpc-padroes-async.md](.claude/docs/regras/alterar-codigo/dpc-padroes-async.md) |

Para mudanças que envolvam mais de um projeto, começar sempre pela visão do ecossistema.

## Regras por projeto
- **ApiDPC** (`ApiDPC/app/**`, `ApiDPC/routes/**`): Laravel 5.5 / PHP 7.2 — ver [apidpc-convencoes.md](.claude/docs/regras/alterar-codigo/apidpc-convencoes.md).
- **DPC** (`DPC/src/**`): Vue 2 / Vuex — ver [dpc-convencoes.md](.claude/docs/regras/alterar-codigo/dpc-convencoes.md).
- **Faisao** (`Faisao/src/**`): React Native / Expo / TS — ver [faisao-convencoes.md](.claude/docs/regras/alterar-codigo/faisao-convencoes.md) (**regra obrigatória de mapeamento cross-project**).

## Bugfix e nova feature
- Consultar o checklist do projeto alvo (`<projeto>-checklist-corrigir-bug.md` ou `-nova-feature.md`).
- Bugfix: reprodução → causa-raiz → menor mudança segura → validação de impacto colateral.
- Feature: validar arquitetura, contratos e impactos cross-project antes de propor mudanças estruturais.

## Tarefas
- Fluxo canônico: [tarefas.md](.claude/docs/regras/gerenciar-regras/tarefas.md) + commands `/importar-tarefa`, `/planejar-tarefa`, `/executar-tarefa`.
- Execução **nunca** commita, faz push ou abre PR automaticamente.
- Quando o pedido for apenas planejamento ou documentação, não alterar código.

## Documentação
- Toda doc nova fica em `.claude/docs/`, em markdown, com recursos visuais (diagramas/tabelas/imagens) quando possível.
