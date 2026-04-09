# Planejamento – Card #3057 EDI - Cadastro de Projetos

## Branch

> **ATENÇÃO — Pré-condição obrigatória antes de qualquer alteração de código:**
>
> 1. Verificar se há alterações não commitadas com `git status` em cada projeto (`DPC` e `ApiDPC`). Se houver, fazer commit ou stash antes de continuar.
> 2. Atualizar a branch base (`main`) com `git pull` dentro da pasta do projeto.
> 3. Criar a branch da tarefa (se não existir) ou fazer checkout dela:
>    ```bash
>    git checkout main && git pull
>    git checkout -b feature/3057-edi-cadastro-projetos
>    # ou, se já existir:
>    git checkout feature/3057-edi-cadastro-projetos && git pull
>    ```
> 4. Somente após confirmar que está na branch correta, iniciar a codificação.

- **Branch da tarefa:** `feature/3057-edi-cadastro-projetos`
- **Origem:** indicada explicitamente na descrição do card do Trello
- **Base:** `main`
- **Status:** nova branch — criar a partir de `main` atualizado
- **Projetos afetados:** `DPC` e `ApiDPC` (branches independentes por repositório)

---

## Objetivo

Criar a tela **Cadastro de Projetos EDI** no DPC Aplicativos (Vue.js), migrando a funcionalidade da tela equivalente do sistema Maracanã. A rota deve ter o nome `CadastroProjetosEdi` para funcionar com o menu dinâmico já configurado no DPC Aplicativos.

---

## Análise do estado atual

### DPC (frontend)
- Módulo `src/app/ti/edi-pedidos/` já existe com a sub-feature `layout/`.
- `ti/edi-pedidos/routes.js` só importa `layout`.
- `ti/routes.js` importa `LayoutEdiPedidos` (que inclui `layout`).
- **Não existe** `cadastro-projetos/` — precisa ser criado do zero.
- O menu do DPC Aplicativos já exibe "Cadastro de Projetos" em "EDI Pedidos / T.I", usando a rota de nome `CadastroProjetosEdi`.

### ApiDPC (backend)
- Endpoint existente: `POST /ti/projetos-edi/buscar` → `TiProjetosEdiController@showAll`
- Só existe listagem. **Não existem** endpoints de salvar, editar ou buscar por ID.
- Model `DpcEdiProjeto` → tabela `dovemail.dpc_edi_projeto` (Oracle).
- Campos disponíveis: `cod_projeto`, `descricao`, `status`, `licenca`, `cod_projeto_terceiro`, `validacao_totalizadores`, `acatar_preco`, `descartar_produto_sem_estoque`, `bloquear_pedido_minimo`, `bloquear_otc`, `bloquear_cp_nao_disponivel`, `motivo_atendimento`, `motivo_nao_relacionado`, `vlr_min_bloq`, `vlr_max_bloq_ped`, `ret_ped_individual`, `nrosegmento`, `cod_vendedor`, `motivo_atendimento_item`, `ret_qtd_max_pedida`, `importar`, `retorno`, `id`, `acatar_desconto`, `soma_desconto`, `converter_unidades`, `edi_projetos`.

---

## Mapeamento funcional

| Elemento | Maracanã | DPC Aplicativos |
|---|---|---|
| Tela de listagem | Form nativo Delphi com grid | `Main.vue` com `vue-good-table` |
| Botões de ação | Toolbar nativo | Botões **Novo** e **Editar** no `slot="header"` do `Box` |
| Cadastro/edição | Formulário no próprio form | `ModalSalvar.vue` |
| Acesso via menu | Maracanã → EDI Pedidos → Cadastro de Projetos | DPC → T.I → EDI Pedidos → Cadastro de Projetos (rota `CadastroProjetosEdi`) |
| API | Sistema legado Oracle | ApiDPC `POST /ti/projetos-edi/buscar` (já existe); `salvar` a criar |
| Campos principais | Código, Sigla, checkboxes de comportamento | Campos do model `DpcEdiProjeto` |

**Regras de negócio observadas no Maracanã:**
- Cada projeto tem um código (`cod_projeto`) e uma descrição/sigla (`descricao`).
- Existem diversas flags booleanas que controlam comportamentos do EDI (acatar preço, bloquear pedido mínimo, descartar produto sem estoque, etc.).
- O campo `status` controla se o projeto está ativo ou inativo.
- A tela de listagem apresenta ao menos: código, descrição e status.

---

## Escopo da implementação

### ApiDPC

**1. `TiProjetosEdiController.php`** — adicionar métodos:
- `show(Request $request, $id)` — busca projeto por `cod_projeto`
- `store(Request $request)` — salvar (insert/update)

**2. `TiProjetosEdiRepository.php`** — adicionar métodos:
- `show($id)` — retorna um projeto pelo `cod_projeto`
- `store($params)` — insert ou update no model `DpcEdiProjeto`

**3. `routes/api.php`** — dentro do grupo `ti/projetos-edi`, adicionar:
```php
Route::get('/busca/{id}', 'TiProjetosEdiController@show');
Route::post('/salvar', 'TiProjetosEdiController@store');
```

### DPC (frontend Vue.js)

**1. Criar `src/app/ti/edi-pedidos/cadastro-projetos/routes.js`:**
```js
import CadastroProjetosEdi from "./components/Main";
export default [
    {
        path: "/ti/edi-pedidos/cadastro-projetos",
        name: "CadastroProjetosEdi",
        component: CadastroProjetosEdi
    }
];
```

**2. Criar `src/app/ti/edi-pedidos/cadastro-projetos/components/Main.vue`:**
- Seguir o padrão do `LayoutEdiPedidos/Main.vue` como referência direta.
- `slot="header"` do `Box`: botões **Novo** e **Editar** (editar desabilitado quando nenhum item selecionado).
- `slot="body"`: `vue-good-table` com colunas `cod_projeto`, `descricao`, `status`.
- Chamada: `POST process.env.ENDERECO_APIDPC + "ti/projetos-edi/buscar"` com paginação, searchTerm e orderBy.
- Ao selecionar linha + clicar Editar ou fazer double-click: abrir `ModalSalvar` passando `codProjeto`.
- Ao clicar Novo: abrir `ModalSalvar` com `codProjeto = null`.

**3. Criar `src/app/ti/edi-pedidos/cadastro-projetos/components/modal/ModalSalvar.vue`:**
- Props: `codProjeto` (null = novo, número = editar).
- Se `codProjeto != null`, carregar dados via `GET /ti/projetos-edi/busca/{id}` no `mounted`.
- Campos mínimos do formulário (baseados no Maracanã e no model):
  - `cod_projeto` (somente leitura se editando)
  - `descricao`
  - `status` (select: Ativo/Inativo)
  - `licenca`
  - `cod_projeto_terceiro`
  - Checkboxes: `validacao_totalizadores`, `acatar_preco`, `descartar_produto_sem_estoque`, `bloquear_pedido_minimo`, `bloquear_otc`, `bloquear_cp_nao_disponivel`, `acatar_desconto`, `soma_desconto`, `converter_unidades`, `ret_ped_individual`, `ret_qtd_max_pedida`, `importar`, `retorno`
  - Campos numéricos: `vlr_min_bloq`, `vlr_max_bloq_ped`, `nrosegmento`, `cod_vendedor`
  - `motivo_atendimento`, `motivo_nao_relacionado`, `motivo_atendimento_item`
- Salvar via `POST /ti/projetos-edi/salvar`.
- Emitir `@buscar-dados` ao fechar com sucesso.

**4. Atualizar `src/app/ti/edi-pedidos/routes.js`:**
```js
import layout from "./layout/routes";
import cadastroProjetos from "./cadastro-projetos/routes";

export default [
    ...layout,
    ...cadastroProjetos,
];
```

> `ti/routes.js` **não precisa ser alterado** — já importa `LayoutEdiPedidos` que agora incluirá o novo módulo automaticamente.

---

## Passos de execução

- [ ] **ApiDPC**
  - [ ] Adicionar `show` e `store` em `TiProjetosEdiRepository.php`
  - [ ] Adicionar `show` e `store` em `TiProjetosEdiController.php`
  - [ ] Adicionar rotas em `routes/api.php` dentro do grupo `ti/projetos-edi`
- [ ] **DPC**
  - [ ] Criar pasta `src/app/ti/edi-pedidos/cadastro-projetos/components/modal/`
  - [ ] Criar `routes.js`
  - [ ] Criar `Main.vue`
  - [ ] Criar `ModalSalvar.vue`
  - [ ] Atualizar `ti/edi-pedidos/routes.js`
- [ ] **Validação**
  - [ ] `npm run dev` no DPC e navegar até a rota `CadastroProjetosEdi`
  - [ ] Testar listagem, criação e edição de projeto
  - [ ] `npm run build` sem erros de Webpack

---

## Referências visuais

| Imagem | Descrição |
|---|---|
| `images/tela-maracana-01.png` | Menu do Maracanã com EDI → Cadastro de Projetos |
| `images/tela-maracana-02.png` | Tela EDI Projetos Especiais no Maracanã (aba principal) |
| `images/tela-maracana-03.png` | Tela EDI Projetos Especiais no Maracanã (visão complementar) |
| `images/menu-dpc-cadastro-projetos-edi.png` | Menu DPC onde a tela deve aparecer |
| `images/layout-dpc-referencia.png` | Layout padrão DPC (Novo/Editar + tabela) |
| `images/codigo-maracana.png` | Código fonte da tela no projeto Maracanã |
