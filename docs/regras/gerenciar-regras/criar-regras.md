# Claude Code — Gerenciar criação de novas regras

Use este documento sempre que for criar ou alterar regras, comandos ou orientações do Claude Code neste workspace. Ele define onde cada tipo de arquivo fica e como manter o escopo claro.

## 1. Onde fica a estrutura que o Claude enxerga

Tudo em `.claude/`:

- **Regras globais sempre ativas**: `.claude/CLAUDE.md` (com as regras transversais e as regras por projeto consolidadas).
- **Comandos operacionais** acionados no chat: `.claude/commands/*.md` (invocados com `/nome`).
- **Agentes especializados**: `.claude/agents/*.md` (invocados com `@NomeDoAgente`).
- **Docs longos (detalhamento)**: `.claude/docs/`.

## 2. Onde fica o conteúdo longo

O texto completo fica em `.claude/docs/`, na subpasta mais adequada:

- Regras sobre **alterar código**: `.claude/docs/regras/alterar-codigo/`
- Regras sobre **processo, tarefas e gerência das regras**: `.claude/docs/regras/gerenciar-regras/`
- Arquitetura e visão do ecossistema: `.claude/docs/arquitetura/`

Os arquivos ativos em `CLAUDE.md`, `.claude/commands/` e `.claude/agents/` devem ser curtos e apontar para essa documentação quando necessário, sem duplicar conteúdo extenso.

## 3. Qual tipo de arquivo criar

- **`CLAUDE.md`**: regra transversal, sempre válida para o workspace; consolida também as regras por projeto como ponteiros curtos.
- **`.claude/commands/*.md`**: fluxo operacional que o usuário executa explicitamente no chat com `/comando`. Deve conter apenas objetivo, entradas, saídas, exceções e link para a doc detalhada.
- **`.claude/agents/*.md`**: agente especializado ativado com `@NomeDoAgente`.
- **Docs em `.claude/docs/`**: explicação longa, checklist, mapa mental, arquitetura ou procedimento detalhado.

## 4. Escopo e nomeação

Toda regra deve ter **escopo explícito**:

- **Geral**: vale para todo o workspace.
- **Por projeto**: vale para `ApiDPC`, `DPC` ou `Faisao`.
- **Por domínio**: tema transversal (tarefas, testes, deploy).

Padrões de nomeação:

- Projeto: `apidpc-*.md`, `dpc-*.md`, `faisao-*.md`
- Domínio: `tarefas.md`, `criar-regras.md`, `git-workflow-branches.md`
- Agentes: `blueprint-mode.md`, `context7.md`
- Comandos: `importar-tarefa.md`, `planejar-tarefa.md`, `gerar-apk.md`

## 5. Checklist ao criar ou alterar uma regra

- [ ] Definir se a necessidade é global, por projeto, por domínio ou um fluxo de comando.
- [ ] Escolher o arquivo correto em `.claude/` em vez de criar estrutura paralela.
- [ ] Manter o texto ativo curto e mover detalhes para `.claude/docs/`.
- [ ] Conferir se os links apontam para arquivos existentes.
- [ ] Preservar os padrões de nomeação do workspace.
- [ ] Verificar se a regra já não está em outro arquivo ativo.

## 6. Otimização de contexto

- Commands contêm apenas objetivo, entradas, saídas, exceções e link para a doc.
- Passo a passo detalhado, exemplos longos e explicações extensas vivem em docs de apoio.
- Evitar repetir a mesma regra em várias camadas.
- Mover para docs qualquer trecho que não altere decisão operacional do agente.

## 7. Regras práticas para evitar quebra

- Não criar arquivos ativos fora de `.claude/` para fluxos já migrados.
- Ao alterar docs de processo, revisar também commands e agentes que referenciam esse doc.
- Antes de remover um arquivo, rodar Grep no workspace inteiro para confirmar zero referências órfãs.
