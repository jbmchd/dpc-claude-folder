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

**Tarefa mesclada (Modo B — múltiplos cards, [tarefas.md §9](tarefas.md)):** usar `feature/{cards}-{slug}`, com os idShort dos cards unidos por `-`. Ex.: cards #3183/#3184/#3185 "ajuste de pedido" → `feature/3183-3184-3185-ajuste-de-pedido`.

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

---

## 8. Múltiplos cards no mesmo pedido — Modo A (branch de integração)

Aplica-se **somente** ao **Modo A** do fluxo multi-card ([tarefas.md §9](tarefas.md)), em que cada card é uma demanda separada. Não vale para card único nem para o Modo B (mesclado).

### 8.1 Exceção de auto-commit (restrita ao Modo A multi-card)
Para existirem N branches com código **e** uma branch de integração montável, o código de cada card precisa estar commitado na sua branch. Por isso, **apenas neste fluxo**, o orquestrador `/tarefa-completa`:

- Após executar cada card, faz `git commit` na branch da tarefa (`feature/{card}-{slug}`) usando a "Mensagem de commit sugerida" registrada no `desenvolvimento.md` — deixando a árvore limpa para trocar de branch e processar o próximo card.
- **Não faz `git push` nem abre PR** — essas ações continuam sempre manuais, aqui e em qualquer outro fluxo.

Fora do Modo A multi-card, a regra padrão permanece intacta: a execução **nunca** commita automaticamente (ver [tarefas.md §2.3](tarefas.md)).

### 8.2 Montagem da branch de integração
Depois que todos os cards foram executados e commitados nas suas branches:

- **Nome:** `integracao/{cards}` — idShort dos cards unidos por `-`. Ex.: `integracao/3183-3184-3185`.
- **Base:** mesma detecção da §3 (`main`/`master`).
- **Montagem:** criar a branch a partir da base atualizada e fazer `merge` de cada branch de tarefa nela:

```bash
git checkout <main|master>
git pull
git checkout -b integracao/{cards}
git merge feature/{card1}-{slug1}
git merge feature/{card2}-{slug2}
# ... uma por card
```

> Se algum `merge` der conflito, **parar** e pedir ao usuário que resolva antes de prosseguir.

### 8.3 A integração é só para teste
- A `integracao/{cards}` existe **exclusivamente para testar o conjunto dos cards juntos**.
- **Nunca** é alvo de PR nem de correção: abrir PR e corrigir qualquer coisa acontecem sempre na branch da tarefa/card correspondente (`feature/{card}-{slug}`).
- Se uma branch de tarefa mudar depois (correção, ajuste), a integração fica **desatualizada** → remontá-la (recriar `integracao/{cards}` do zero pela §8.2) quando o usuário quiser testar o conjunto de novo.
