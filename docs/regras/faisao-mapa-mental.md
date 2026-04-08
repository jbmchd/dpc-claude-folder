# Faisao – Mapa mental

## Mapa mental textual do sistema

```
Faisao (App React Native / Expo)
├── Entrada
│   ├── index.js (registerRootComponent(App))
│   ├── App.tsx (SafeAreaProvider, ToastProvider, AppContextProvider, Routes)
│   └── Modais globais (ModalLocationServicesOff, UserSessionNotificationChannel)
├── Autenticação
│   ├── Login (POST apiauth.dpcnet.com.br/auth/login, imei, app_id 506)
│   ├── Token em expo-secure-store (userToken)
│   ├── api.ts interceptors (token na URL, 401 → logout)
│   └── getLoggedUser() na inicialização
├── Rotas
│   ├── routes/index.tsx (NavigationContainer, Stack: Login, Main, ViewVendedor, ViewCliente)
│   ├── tab.routes.tsx (Bottom Tabs: Vendedores, Clientes, User)
│   ├── vendedor.routes.tsx, cliente.routes.tsx
│   └── NavigationService (navigate, goBack, reset)
├── Estado
│   ├── AppContextProvider (user, vendedorParams, equipes, toast, isLocationEnabled, isBatterySaverOn)
│   ├── React Query (useQuery, useInfiniteQuery – vendedores, clientes, pedidos, titulos)
│   └── Local (useState nos componentes)
├── Serviços
│   ├── api.ts (createApi, baseURL ApiDPC e Atendimento)
│   ├── backgroundTasks.ts, coletaQueueManager.ts (localização, fila offline)
│   ├── equipeService, bairroService, cityService, rcaService
│   └── names.ts (constantes)
├── Telas
│   ├── Login, User (configurações)
│   ├── Vendedores, ViewVendedor
│   ├── Cliente, ViewCliente, DadosCliente
│   ├── Pedido, Titulos, Devolucoes
│   └── DadosVendedor, ScreenWrapper
├── Componentes
│   ├── Card/CardScroll (listas, ErrorState, retry)
│   ├── DatePicker, Filter, FloatingLabelInput, Header, Loading
│   ├── ModalLocationServicesOff, ModalOverlay, ToastWrapper
│   └── SelectBox, ProgressBar, etc.
├── Estilo
│   ├── NativeWind (tailwind.config.js, global.css)
│   ├── style/colors.ts
│   └── styled-components (em alguns componentes)
├── Background e offline
│   ├── expo-task-manager, expo-background-fetch
│   ├── coletaQueueManager (singleton, AsyncStorage, EventEmitter)
│   └── POST /rastreamento quando online
├── Build e deploy
│   ├── Metro (metro.config.js, alias ~ → src)
│   ├── EAS Build (eas.json: development, preview, production)
│   └── app.json (Expo config)
└── APIs consumidas
    ├── ApiDPC (apidpc.dpcnet.com.br/api)
    ├── ApiAuth (apiauth.dpcnet.com.br)
    └── Api Atendimento (apiatendimento.dpcnet.com.br)
```
