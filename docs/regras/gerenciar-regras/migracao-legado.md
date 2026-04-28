# Migração de telas do Maracanã para o DPC

> Regras obrigatórias para tarefas que migram uma tela do Maracanã (VB.NET desktop) para o DPC Aplicativos (Vue) + ApiDPC (Laravel).
> Essas regras evitam os percalços documentados nas tarefas #3057 e #3064.

Ver também: [tarefas.md](tarefas.md) · [apidpc-oracle-padroes.md](../alterar-codigo/apidpc-oracle-padroes.md) · [dpc-padroes-async.md](../alterar-codigo/dpc-padroes-async.md)

---

## 1. Código-fonte do Maracanã — onde está

O repositório do Maracanã está clonado localmente em:

```
workspace/maracana/Maracana/Maracana/
```

Estrutura relevante:

- `Telas/<Area>/<SubArea>/<Tela>/` — cada tela tem seu próprio subdiretório
- `Telas/.../dal<Nome>.vb` — camada de acesso a dados (queries Oracle, `OleDb`)
- `Telas/.../inf<Nome>.vb` — DTOs/estruturas de dados
- `Telas/.../frm<Nome>.vb` + `.Designer.vb` — formulário e layout

Documentação complementar em [.claude/docs/maracana/](../../maracana/).

**Consequência prática:** nunca planejar uma migração a partir **só de screenshots**. O código fonte VB.NET é autoridade sobre:
- Nomes reais dos campos da tela
- Queries SQL efetivamente executadas
- Regras de bloqueio/habilitação de controles
- Fluxo de salvamento e validações

---

## 2. Fluxo obrigatório na importação

Quando uma tarefa é de **migração de tela do Maracanã**, o `/importar-tarefa` deve, além do fluxo padrão de [tarefas.md](tarefas.md), registrar em `consideracoes.md`:

1. **Caminho exato da tela no Maracanã**, resolvido via busca em `workspace/maracana/**` pelo nome da tela ou funcionalidade.
   Exemplo: `maracana/Maracana/Maracana/Telas/Comercial/EDI Pedidos/Cadastro_Projeto/`
2. **Arquivos-chave encontrados**: `frm*.vb`, `dal*.vb`, `inf*.vb`.
3. **Indicação explícita** de que a migração será planejada a partir do código-fonte, não apenas das imagens do card.

Se a tela **não for encontrada** no clone local, parar e perguntar ao usuário antes de seguir — **não** presumir a estrutura.

---

## 3. Fluxo obrigatório no planejamento

O `/planejar-tarefa` para migração de tela deve incluir, antes do "Escopo da implementação":

### 3.1 Leitura do `dal*.vb` (acesso a dados)

Listar **todas** as queries SQL encontradas no DAL, identificando para cada:

- Schema e tabela/view alvo (ex.: `DOVEMAIL.DPCV_EDI_PROJETO_LICENCA`).
- Colunas selecionadas.
- Filtros e ordenação.
- Se é view — flagar que o endpoint DPC deve usar **a mesma view**, não a tabela base.

### 3.2 Leitura do `frm*.vb` / `.Designer.vb` (formulário)

Extrair **a partir do código** (não de screenshots):

- Lista completa dos controles visíveis na tela, em ordem de layout.
- Para cada controle: tipo (TextBox, ComboBox, CheckBox, DataGridView...), nome, label, estado inicial e regras de habilitação.
- Eventos que disparam lógica (ex.: `cboSegmento_SelectedIndexChanged` bloqueando `txtCodVendedor`).

### 3.3 Mapeamento de schema Oracle

**PROIBIDO acessar o banco real durante migração de tela — por qualquer meio**: MCP DPC, queries diretas, scripts, curl, ferramentas externas ou qualquer outro mecanismo. Essa proibição vale mesmo que pareça mais rápido ou conveniente. Só é permitido se o usuário pedir explicitamente na mesma mensagem.

A fonte de verdade é o código do Maracanã: o `dal*.vb` já contém os nomes de colunas, tipos inferíveis pelo uso, filtros e ordenação. Acessar o banco para "confirmar" o schema é desnecessário e viola o fluxo de migração.

Ao registrar em `.claude/docs/db/<dominio>.md` (template [db/_template-dominio.md](../../db/_template-dominio.md)), extrair as informações **exclusivamente do `dal*.vb`**:

- Colunas e tipos inferidos pelo uso no DAL.
- Filtros, ordenação e relacionamentos visíveis nas queries.
- Sequences mencionadas no código VB.NET.

Se o DAL não for suficiente para determinar algo, parar e perguntar ao usuário — nunca acessar o banco como atalho.

### 3.4 Plano do lado da tela, não do lado do model

O `planejamento.md` deve **listar as seções e campos a partir do formulário do Maracanã**, não a partir de todas as colunas do model Eloquent. Um model pode ter 30 colunas enquanto a tela exibe 15 — o plano considera os 15.

**Gate:** o planejamento não é considerado pronto sem:

- [ ] Caminho do `dal*.vb` e do `frm*.vb` citados.
- [ ] Lista de queries SQL extraídas do DAL.
- [ ] Lista de campos da tela extraída do `frm*.vb` (não do model).
- [ ] Documento de schema em `.claude/docs/db/<dominio>.md` criado/atualizado.

---

## 4. Fluxo obrigatório na execução

- Toda query Oracle nova passa pelo MCP DPC antes de virar PHP — ver [apidpc-oracle-padroes.md §3](../alterar-codigo/apidpc-oracle-padroes.md).
- Modais com selects carregados via API seguem [dpc-padroes-async.md](../alterar-codigo/dpc-padroes-async.md).
- Se a tela usar uma **view** Oracle, o endpoint DPC usa **a mesma view** (não a tabela base), para reaproveitar a lógica de filtro do legado.

---

## 5. Não reescrever componentes grandes em loop

Quando um arquivo Vue passa dos ~400 linhas (comum em modais de cadastro completos), evitar reescritas completas em iterações de correção. Usar `Edit` cirúrgico em blocos identificados. Reescrever um arquivo de 500 linhas 3 vezes na mesma tarefa é sintoma de falha de planejamento, não de execução.

---

## 6. Commits durante migração

Reforço da regra geral: o `/executar-tarefa` **não faz commit automático**. Ao terminar, deixa a working tree suja e aguarda o usuário. Ver [tarefas.md](tarefas.md) §9.

---

## 7. Anti-padrões a evitar

| Sintoma | Causa raiz | Regra que previne |
|---|---|---|
| Plano lista 24 campos, 6 inexistentes | Planejamento a partir do model, não da tela | §3.4 |
| Endpoint usa tabela base, front perde o nome do cliente | Não inspecionou o DAL do Maracanã | §3.1 |
| Schema Oracle descoberto só durante execução | Faltou mapeamento em `db/<dominio>.md` | §3.3 |
| `ModalSalvar.vue` reescrito 3 vezes | Plano incompleto, correções em loop | §3, §5 |
| Dropdown mostra código em vez de nome | Race condition ou view errada | §4 + [dpc-padroes-async.md](../alterar-codigo/dpc-padroes-async.md) |
| Query quebra por ambiguidade `ORDER BY` | SQL escrito de cabeça sem MCP | §4 + [apidpc-oracle-padroes.md §3](../alterar-codigo/apidpc-oracle-padroes.md) |
| Schema consultado no banco real sem ser pedido | Atalho indevido durante migração | §3.3 |
