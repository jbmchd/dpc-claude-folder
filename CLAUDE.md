# DPC Workspace

## Escopo
- Este workspace contém `ApiDPC`, `DPC` e `Faisao`.
- Todas as regras abaixo valem para todos os agentes e sessões neste workspace.

## Regras transversais
- Antes de alterar código, identificar claramente qual projeto e qual área do projeto serão afetados.
- Preferir mudanças pequenas e aderentes ao padrão existente.
- Evitar refatorações amplas sem necessidade funcional clara.
- Preservar contratos atuais entre frontend, mobile e API.
- Nunca alterar arquivos/pacotes em `node_modules/**`, sob nenhuma hipótese, exceto quando o usuário pedir explicitamente essa alteração na mesma mensagem.
- Quando houver dúvida estrutural, consultar primeiro a documentação em [.claude/docs](.claude/docs).
- Não copiar para a resposta o conteúdo longo da documentação quando um link para o doc for suficiente.

## Locais protegidos
- Os seguintes locais são protegidos e não devem ser alterados por padrão:
  - `.claude/docs/**`
  - `.claude/agents/**`
  - `.claude/commands/**`
  - `.claude/instructions/**`
  - `CLAUDE.md` (este arquivo)
- Só alterar locais protegidos quando o usuário pedir de forma explícita na mesma mensagem, citando claramente o caminho/arquivo alvo.
- Sem autorização explícita, operar apenas em modo leitura nesses locais e pedir confirmação antes de qualquer edição, rename, move ou delete.

## Regras de Documentação
- Toda documentação deve ser criada em [`.claude/docs/`](.claude/docs/).
- Toda documentação deve ser feita em markdown (`.md`).
- Toda documentação deve conter recursos visuais (diagramas, tabelas, imagens) se possível.

## Consultas Externas via MCP
- Toda consulta externa de documentação deve ser feita via MCP `context7` primeiramente.
- Toda consulta a banco de dados deve ser feita via MCP da DPC.
- Toda consulta ao Trello deve ser feita via MCP do Trello.

## Consulta de documentação
- Para contexto transversal do ecossistema, consultar [visao-geral-ecossistema-dpc.md](.claude/docs/arquitetura/visao-geral-ecossistema-dpc.md).
- Para arquitetura por projeto, consultar os arquivos em [docs/arquitetura](.claude/docs/arquitetura).
- Para visão rápida de cada projeto, consultar os mapas mentais em [docs/regras](.claude/docs/regras).
- Para regras de alteração de código, consultar os arquivos em [docs/regras/alterar-codigo](.claude/docs/regras/alterar-codigo).
- Para fluxos de tarefas e Trello, consultar [tarefas.md](.claude/docs/regras/gerenciar-regras/tarefas.md).
- Para mudanças que envolvam mais de um projeto, consultar primeiro [visao-geral-ecossistema-dpc.md](.claude/docs/arquitetura/visao-geral-ecossistema-dpc.md).
- Para criar ou alterar regras, commands, agentes ou docs do workspace, consultar [criar-regras.md](.claude/docs/regras/gerenciar-regras/criar-regras.md).

## Bugfix
- Consultar o checklist de corrigir bug do projeto correspondente em `.claude/docs/regras/alterar-codigo/<projeto>-checklist-corrigir-bug.md`.
- Priorizar: reprodução → causa raiz → menor mudança segura → validação de impacto colateral.

## Nova Feature
- Consultar o checklist de nova feature do projeto correspondente em `.claude/docs/regras/alterar-codigo/<projeto>-checklist-nova-feature.md`.
- Consultar arquitetura e mapa mental do projeto antes de propor mudanças estruturais.
- Validar contratos e impactos cross-project.

## Tarefas e Trello
- Consultar [tarefas.md](.claude/docs/regras/gerenciar-regras/tarefas.md) como fonte principal do fluxo de tarefas antes de importar, planejar ou atualizar a documentação da demanda.
- Consultar [git-workflow-branches.md](.claude/docs/regras/gerenciar-regras/git-workflow-branches.md) quando o planejamento precisar registrar a branch da tarefa ou quando a execução envolver alteração de código.
- Quando houver Trello, usar o board `DPC Dev` e trabalhar com card number (`idShort`) ou link.
- Usar os comandos `/importar-tarefa`, `/planejar-tarefa` e `/executar-tarefa` como passo a passo operacional.
- Quando houver alteração de código, seguir as regras de `desenvolvimento.md` definidas em [tarefas.md](.claude/docs/regras/gerenciar-regras/tarefas.md).
- Não executar alterações de código quando o fluxo pedido for apenas de planejamento ou documentação.

---

## Regras por projeto

@.claude/instructions/apidpc.md
@.claude/instructions/dpc.md
@.claude/instructions/faisao.md
