# Desenvolvimento – Card #3057 EDI - Cadastro de Projetos

## Linha do tempo

- 2026-04-09 – Importação do card realizada, pasta e estrutura documental criadas.
- 2026-04-09 – Planejamento gerado: análise de código existente (DPC + ApiDPC), mapeamento funcional e definição da estrutura de arquivos a criar.
- 2026-04-09 – Execução: branch `feature/3057-edi-cadastro-projetos` criada em DPC e ApiDPC. Todos os arquivos implementados.

## Resumo técnico das alterações

### ApiDPC

- **`app/Repositories/TiProjetosEdiRepository.php`** — adicionados métodos `show($id)` (busca projeto por `cod_projeto`) e `store($params)` (insert/update condicional pelo campo `cod_projeto`).
- **`app/Http/Controllers/TiProjetosEdiController.php`** — adicionados métodos `show(Request, $id)` e `store(Request)` delegando ao repository.
- **`routes/api.php`** — adicionadas rotas dentro do grupo `ti/projetos-edi`:
  - `GET /busca/{id}` → `TiProjetosEdiController@show`
  - `POST /salvar` → `TiProjetosEdiController@store`

### DPC

- **`src/app/ti/edi-pedidos/cadastro-projetos/routes.js`** — criado: rota `/ti/edi-pedidos/cadastro-projetos` com name `CadastroProjetosEdi`.
- **`src/app/ti/edi-pedidos/cadastro-projetos/components/Main.vue`** — criado: listagem de projetos EDI com `vue-good-table`, botões Novo e Editar no header do Box, paginação server-side, double-click para editar.
- **`src/app/ti/edi-pedidos/cadastro-projetos/components/modal/ModalSalvar.vue`** — criado: formulário completo para criação/edição de projeto EDI com todos os campos do model `DpcEdiProjeto` organizados em seções (Básico, Configurações de Pedido, Retorno, Outros). Toggle de status, validação de campos obrigatórios (`cod_projeto`, `descricao`).
- **`src/app/ti/edi-pedidos/routes.js`** — atualizado: importa e espalha `cadastroProjetos` ao lado de `layout`.

### Tipo da mudança
Feature nova (zero código alterado, apenas adições)

### Impactos principais
- Menu `CadastroProjetosEdi` no DPC Aplicativos passa a funcionar.
- Endpoint de listagem existente (`/ti/projetos-edi/buscar`) mantido sem alteração.
- Dois novos endpoints na ApiDPC para completar o CRUD.

## Decisões e regras de negócio

- `cod_projeto` é chave natural da tabela Oracle — `store` usa `where('cod_projeto', ...)` para update e insert direto para criação. Campo desabilitado no modal ao editar.
- Flags booleanas do EDI são armazenadas como `S`/`N` (char Oracle), mapeadas para checkbox Vue com `true-value="S" false-value="N"`.
- Status usa `toggle-button` com mapeamento `true → "A"` / `false → "I"`, padrão DPC.
- `ti/routes.js` não precisou de alteração — já importa `LayoutEdiPedidos` que agora inclui `cadastroProjetos` via `edi-pedidos/routes.js`.

## Observações técnicas

- O campo `total` retornado pelo `showAll` do repository usa `$relatorio->showAll($params, false)` (count). O `Main.vue` consome `response.data.total` para `qtdRows`.
- O modal tem `max-height: 70vh` com `overflow-y: auto` para comportar todos os campos sem ultrapassar a viewport.

## Mensagem de commit sugerida

```
feat(ti): adiciona tela de Cadastro de Projetos EDI (#3057)

- DPC: novo módulo em src/app/ti/edi-pedidos/cadastro-projetos com Main.vue, ModalSalvar.vue e routes.js
- DPC: atualiza ti/edi-pedidos/routes.js para registrar a nova rota CadastroProjetosEdi
- ApiDPC: adiciona endpoints GET /ti/projetos-edi/busca/{id} e POST /ti/projetos-edi/salvar
- ApiDPC: adiciona métodos show e store em TiProjetosEdiController e TiProjetosEdiRepository
```
