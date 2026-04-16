# DPC — Referência de Alteração de Código

> Painel admin Vue.js 2 / Vuex. Aplicar em `DPC/src/**`.

Ver também: [principios-comuns-alterar-codigo.md](principios-comuns-alterar-codigo.md) · [dpc-padroes-async.md](dpc-padroes-async.md)

## Princípios do projeto

- Preservar a organização existente: `src/app`, `src/components`, `src/vuex`, `src/router`, `src/utils`, `config`.
- Não propor migrações grandes do frontend web nem reestruturações amplas fora do escopo da tarefa.
- Comentários e textos de interface podem permanecer em português.

## Módulos de feature (`src/app/<feature>/`)

- Cada feature: `components/`, `routes.js`, e quando existir `vuex/`.
- `routes.js` exporta array de rotas; importa o componente principal (`Main.vue`).
- `src/app/routes.js`: apenas importa e espalha (`...feature`) os arrays; seguir padrão existente.
- Vuex de feature: registrar em `src/app/vuex.js` com `export { vuex as <nome> } from "./<nome>"`.
- API: usar `dpcAxios.connection()` e constantes de `config/api.env.js`; formato de resposta `{ error, msg, data }`.
- Alias `@/` para imports fora da pasta da feature; relativos para arquivos da mesma feature.

## Componentes compartilhados (`src/components/`)

- Organização de pastas conforme existente (`root/`, `box/`, `filtro/`, etc.).
- Alias `@/` para imports de `src/`; evitar paths absolutos de filesystem.
- UI: Bootstrap 3 + `bootstrap-vue` + SCSS existente; não trocar sem pedido explícito.
- Respeitar padrão de props, eventos (`$emit`) e slots dos componentes existentes.
- Preferir estender/compor componente existente a criar implementação paralela.

## Vuex, Router e config

- **Vuex root** (`src/vuex/`): manter `state.js`, `mutations.js`, `actions.js`, `getters.js`, `modules.js`; não renomear chaves globais (`token`, `user`, `menus`, `permissaoUser`).
- **Router** (`src/router/`): preservar `beforeEach.js` (guards de auth, menus, permissão) e `router/index.js`.
- **Config** (`config/api.env.js`): manter estrutura de constantes de endpoint; usar nomes/chaves existentes ao adicionar.
- Evitar dividir arquivos de Vuex, router ou config sem necessidade.

## Arquitetura completa

Consultar [dpc-arquitetura.md](../../arquitetura/dpc-arquitetura.md).
