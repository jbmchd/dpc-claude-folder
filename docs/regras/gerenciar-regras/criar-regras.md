# Claude Code – Gerenciar criação de novas regras

Use este documento sempre que for criar ou alterar regras, comandos ou orientações do Claude Code neste workspace. Ele define onde cada tipo de arquivo deve ficar e como manter o escopo claro.

## 1. Onde fica a estrutura que o Claude enxerga

A estrutura ativa deste workspace fica em `.claude/`:

- **Regras globais sempre ativas**: `CLAUDE.md` (raiz do workspace)
- **Regras por projeto**: `CLAUDE.md` importa via `@` os arquivos em `.claude/instructions/`
- **Regras condicionais por projeto**: `.claude/instructions/apidpc.md`, `dpc.md`, `faisao.md`
- **Comandos operacionais acionados explicitamente no chat**: `.claude/commands/*.md` (invocados com `/nome-do-comando`)
- **Agentes especializados**: `.claude/agents/*.md` (invocados com `@NomeDoAgente`)

## 2. Onde fica o conteúdo longo da regra

O texto completo e a documentação de apoio ficam em `.claude/docs/`, na subpasta mais adequada:

- Regras sobre **alterar código**: `.claude/docs/regras/alterar-codigo/`
- Regras sobre **processo, tarefas e gerência das regras**: `.claude/docs/regras/gerenciar-regras/`
- Arquitetura e visão do ecossistema: `.claude/docs/arquitetura/`

Os arquivos ativos em `CLAUDE.md`, `.claude/instructions/` e `.claude/commands/` devem ser curtos e apontar para essa documentação quando necessário, sem duplicar conteúdo extenso.

## 3. Qual tipo de arquivo criar

Use o tipo certo para cada necessidade:

- **`CLAUDE.md`**: regra transversal, sempre válida para o workspace — inclui via `@` os arquivos de instrução por projeto.
- **`.claude/instructions/*.md`**: regra modular por projeto ou domínio.
- **`.claude/commands/*.md`**: fluxo operacional que o usuário executa explicitamente no chat com `/comando`.
- **`.claude/agents/*.md`**: agente especializado ativado com `@NomeDoAgente`.
- **Docs em `.claude/docs/`**: explicação longa, checklist, mapa mental, arquitetura ou procedimento detalhado.

## 4. Escopo e nomeação

Toda regra deve ter **escopo explícito**:

- **Geral**: vale para todo o workspace.
- **Por projeto**: vale para `ApiDPC`, `DPC` ou `Faisao`.
- **Por domínio**: vale para um tema transversal, como tarefas, testes ou deploy.

Padrões de nomeação deste workspace:

- Projeto: `apidpc-*.md`, `dpc-*.md`, `faisao-*.md`
- Domínio: `tarefas.md`, `criar-regras.md`, `git-workflow-branches.md`
- Agentes: `blueprint-mode.md`, `context7.md`, `debug.md`
- Comandos: `importar-tarefa.md`, `planejar-tarefa.md`, `gerar-apk.md`

## 5. Checklist ao criar ou alterar uma regra

- [ ] Definir se a necessidade é global, por projeto, por domínio ou um fluxo de comando.
- [ ] Escolher o arquivo correto em `.claude/` em vez de criar uma estrutura paralela.
- [ ] Manter o texto ativo curto e mover detalhes longos para `.claude/docs/`.
- [ ] Conferir se os links para docs apontam para arquivos existentes.
- [ ] Preservar os padrões de nomeação já usados neste workspace.
- [ ] Verificar se a mesma regra já está em `CLAUDE.md`, em outro `instructions/*.md` ou em um doc ativo.
- [ ] Revisar se o texto novo aumenta o contexto sem ganho operacional real.

## 6. Otimização de contexto

- Manter comandos com objetivo, entradas, saídas e exceções;
- Deixar passo a passo detalhado, exemplos longos e explicações extensas em docs de apoio;
- Evitar repetir em várias camadas a mesma regra global;
- Mover para docs qualquer trecho que não altere decisão operacional do agente.

## 7. Regras práticas para evitar quebra

- Não criar novos arquivos ativos fora de `.claude/` para fluxos que já estão migrados.
- Não duplicar a mesma regra em `CLAUDE.md` e `.claude/instructions/` sem necessidade.
- Ao alterar docs de processo, revisar também os comandos e instruções que referenciam esse doc.
