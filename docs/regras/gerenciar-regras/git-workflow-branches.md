# Git Workflow – Branches por Tarefa

Toda tarefa deve ser executada em um branch dedicado. Este documento define como identificar, criar ou reutilizar esse branch antes de iniciar qualquer alteração de código.

---

## 1. Identificação do nome da branch

Verificar, nesta ordem de prioridade:

1. **Card do Trello**: campo ou texto que contenha branch (ex.: `branch: feature/3012-coleta-gps`).
2. **Arquivos ou imagens enviadas pelo usuário**: qualquer menção explícita de branch.
3. **Fallback – nome da tarefa**: se nenhuma fonte acima indicar branch, usar o padrão:

```
feature/{numero}-{slug-da-tarefa}
```

Exemplos:
- Card #3012 "Coleta GPS" → `feature/3012-coleta-gps`
- Sem número, tarefa "Ajuste de login" → `feature/ajuste-de-login`

> Sempre registrar no início do `planejamento.md` qual branch será usada e qual foi a origem da decisão (card, documento ou fallback).

---

## 2. Pré-condição obrigatória: árvore de trabalho limpa

Antes de qualquer operação de branch, verificar se há alterações não commitadas:

```bash
git status
```

- Se houver alterações pendentes: **parar e solicitar** que o usuário faça commit ou stash antes de continuar.
- Não continuar o fluxo com árvore suja para evitar perda acidental de código.

---

## 3. Detecção da branch base

- Preferir `main` — verificar se existe localmente ou no remoto.
- Se `main` não existir, usar `master`.
- Se nenhuma das duas existir, abortar e informar o usuário.

---

## 4. Fluxo: branch já existe

```bash
git checkout <branch>
git pull
git pull origin <main|master>
```

> Se o `git pull` resultar em conflito, parar e solicitar que o usuário resolva os conflitos antes de prosseguir.

---

## 5. Fluxo: branch não existe

```bash
git checkout <main|master>
git pull
git checkout -b <branch>
```

---

## 6. Pré-requisito: remoto configurado

- Se não houver remoto `origin` configurado: **abortar** os passos de pull/push.
- Informar o usuário que o remote `origin` não está configurado.
- Executar apenas as operações locais (checkout, create branch) se fizer sentido no contexto.

---

## 7. Registro obrigatório no planejamento

O `planejamento.md` da tarefa deve conter uma seção **Branch** com:

- Nome da branch da tarefa.
- Origem da decisão (indicada no card/documento, ou fallback pelo nome da tarefa).
- Branch base usada (`main` ou `master`).
- Se era branch existente ou nova.

Exemplo:

```markdown
## Branch
- **Branch da tarefa:** `feature/3012-coleta-gps`
- **Origem:** indicada no card do Trello
- **Base:** `main`
- **Status:** branch existente – atualizada com remoto e base
```
