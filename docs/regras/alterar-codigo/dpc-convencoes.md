# DPC — Convenções de código

> Painel admin Vue.js 2 / Vuex. Aplicar em `DPC/src/**`.
> Regras transversais estão em `CLAUDE.md`.

Ver também: [dpc-padroes-async.md](dpc-padroes-async.md) · [dpc-arquitetura.md](../../arquitetura/dpc-arquitetura.md)

## Módulos de feature (`src/app/<feature>/`)
- Estrutura: `components/`, `routes.js`, `vuex/` quando houver estado.
- `routes.js` exporta array de rotas; importa o componente principal (`Main.vue`).
- `src/app/routes.js`: apenas importa e espalha (`...feature`) os arrays.
- Vuex de feature: registrar em `src/app/vuex.js` com `export { vuex as <nome> } from "./<nome>"`.
- API: `dpcAxios.connection()` + constantes de `config/api.env.js`. Resposta esperada `{ error, msg, data, quantidade }`.
- Alias `@/` para imports fora da feature; relativos dentro da mesma feature.

## Componentes compartilhados (`src/components/`)
- Organização atual (`root/`, `box/`, `filtro/`, etc.) — não reorganizar.
- UI: Bootstrap 3 + `bootstrap-vue` + SCSS; não trocar sem pedido explícito.
- Respeitar props, eventos (`$emit`) e slots dos componentes existentes.
- Estender/compor componente existente antes de criar um paralelo.

## Vuex, Router e config
- **Vuex root** (`src/vuex/`): manter `state/mutations/actions/getters/modules`; não renomear chaves globais (`token`, `user`, `menus`, `permissaoUser`).
- **Router** (`src/router/`): preservar `beforeEach.js` (auth/menus/permissão).
- **Config** (`config/api.env.js`): manter estrutura de constantes; adicionar com nomes já padronizados.

## Padrões async
Carregamento de dependências em `mounted()`, fallbacks de select e tratamento de `error != 0`: ver [dpc-padroes-async.md](dpc-padroes-async.md).
