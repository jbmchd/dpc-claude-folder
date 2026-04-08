# DPC (admin-dpc-vue) – Mapa mental

## Mapa mental textual do sistema

```
DPC (Admin Vue.js)
├── Entrada
│   ├── main.js (Vue, plugins, Echo)
│   ├── App.vue (layout, sidebar, topbar, router-view, modais, notificações)
│   └── router/beforeEach (auth, menus, permissões)
├── Autenticação
│   ├── Account.js (login, logoff, isAuthenticated, validateSession, hasAccess)
│   ├── JWT em cookie + Vuex (token, user)
│   └── dpcAxios interceptors (token na request, refresh na response)
├── Rotas
│   ├── router/index.js (history, baseUrl)
│   ├── app/routes.js (agregador)
│   └── app/[feature]/routes.js (por módulo)
├── Estado (Vuex)
│   ├── vuex/ (root: token, user, menus, permissaoUser, rota, etc.)
│   ├── app/vuex.js (agregador de módulos)
│   └── app/[feature]/vuex/ (state, mutations, actions, getters)
├── API
│   ├── dpcAxios.js (connection, interceptors)
│   └── config/api.env.js (126+ endpoints)
├── Módulos (src/app/)
│   ├── root (Login, 404)
│   ├── absenteismo, administracao, atendimentos
│   ├── clientes, vendas, produtos, usuarios
│   ├── financeiro, armazem
│   └── [30+ features]
│       ├── components/
│       ├── routes.js
│       └── vuex/ (quando há estado da feature)
├── Componentes compartilhados
│   ├── components/root (sidebar, topbar, table, modal, black-modal)
│   └── components/box
├── Estilo
│   ├── assets/css/sass (app.scss, bootstrap, custom)
│   └── <style lang="scss" scoped> nos .vue
├── Utilitários
│   └── utils/events/bus.js (event bus)
├── Integrações
│   ├── Firebase (push)
│   └── Laravel Echo + Pusher (WebSocket)
├── Build e deploy
│   ├── Webpack (build/)
│   ├── config/dev.env, prod.env, api.env
│   ├── dockerfile (Node build + Apache)
│   └── firebase.json
└── Resposta esperada da API
    └── { error: 0|1, msg: "...", data: [...], quantidade: N }
```
