# Visão geral do ecossistema DPC

Este documento descreve o ecossistema DPC como um todo: os três projetos principais e como cada um interage com os demais. Para detalhes de stack, organização de pastas, riscos e dívida técnica de cada projeto, use os arquivos de arquitetura específicos listados ao final.

---

## 1. Resumo do ecossistema

| Projeto | Papel | Documentação |
|---------|--------|---------------|
| **ApiDPC** | API REST central (Laravel 5.5); fonte única de dados de negócio para o admin e o app. | [apidpc-arquitetura.md](apidpc-arquitetura.md) |
| **DPC** | Painel administrativo web (Vue 2 + Vuex); usuários internos (gestão de vendas, clientes, financeiro, usuários, etc.). | [dpc-arquitetura.md](dpc-arquitetura.md) |
| **Faisao** | Aplicativo mobile (React Native/Expo); vendedores em campo (clientes, pedidos, títulos, rastreamento). | [faisao-arquitetura.md](faisao-arquitetura.md) |

---

## 2. Diagrama de visão geral

```mermaid
flowchart TB
    subgraph clients [Clientes]
        DPC[DPC Vue Admin]
        Faisao[Faisao Mobile]
    end
    subgraph auth [Autenticação]
        ApiAuth[ApiAuth IMEI]
    end
    subgraph core [ApiDPC]
        API[REST API]
    end
    subgraph data [Dados]
        PG[(PostgreSQL)]
        ORA[(Oracle)]
        MYSQL[(MySQL)]
    end
    subgraph external [Externos]
        ApiAtend[Api Atendimento]
        Firebase[Firebase]
        Pusher[Pusher]
        NFe[NFe Boleto FTP]
    end
    DPC --> API
    Faisao --> ApiAuth
    ApiAuth --> Faisao
    Faisao --> API
    Faisao --> ApiAtend
    DPC --> Firebase
    DPC --> Pusher
    API --> PG
    API --> ORA
    API --> MYSQL
    API --> NFe
```

- **Clientes:** DPC (web) e Faisao (mobile).
- **ApiDPC:** núcleo (middleware, 382+ controllers, 302+ repositórios, 300+ models).
- **Bancos:** PostgreSQL (usuários/app), Oracle (ERP), MySQL (Asterisk CDR).
- **Autenticação:** DPC usa JWT direto da ApiDPC; Faisao usa ApiAuth (`apiauth.dpcnet.com.br`) para login com IMEI e depois consome ApiDPC com o mesmo token.
- **Externos:** Api Atendimento (Faisao), Firebase/Pusher (DPC), NFe/Boleto/FTP (ApiDPC).

---

## 3. Como cada projeto interage com os demais

| De | Para | O quê |
|----|------|--------|
| **DPC** | ApiDPC | Todas as operações (CRUD, buscas, relatórios); JWT; base URL em `ENDERECO_APIDPC`; 126+ endpoints em `config/api.env.js`. |
| **Faisao** | ApiAuth | Login com `username`, `password`, `imei`, `app_id: '506'`; retorno JWT guardado em SecureStore. |
| **Faisao** | ApiDPC | Dados de negócio (vendedores, clientes, pedidos, títulos, rastreamento); token em query; base `apidpc.dpcnet.com.br`. |
| **Faisao** | Api Atendimento | Chamados/atendimento; base `apiatendimento.dpcnet.com.br`. |
| **ApiDPC** | DPC / Faisao | Resposta padrão `{ "error": 0 ou 1, "msg": "...", "data": [...], "quantidade": N }`; JWT refresh no header `Authorization`. |

**DPC e Faisao** não se comunicam diretamente. A interação é indireta via ApiDPC (mesmos dados e regras). O admin (DPC) pode receber eventos em tempo real via Pusher/Firebase.

---

## 4. Autenticação no ecossistema

| Projeto | Fluxo |
|---------|--------|
| **DPC** | Login direto na ApiDPC → JWT em cookie + Vuex; refresh pelo interceptor Axios; guards no router (`Account.isAuthenticated()`, `Account.hasAccess()`). |
| **Faisao** | Login na ApiAuth (validação de IMEI) → JWT em `expo-secure-store`; token enviado em query (`?token=`) nas requisições à ApiDPC; 401 no interceptor dispara logout. |
| **ApiDPC** | Emite e valida JWT (tymon/jwt-auth); usuário em PostgreSQL (`acesso.dim_usuario`, chave `cod_usuario`); middlewares `jwt` (refresh) e `jwt.auth`. |

**ApiAuth** é um serviço separado (fora dos repositórios ApiDPC/DPC/Faisao documentados aqui), usado apenas pelo Faisao para login com validação de dispositivo (IMEI).

---

## 5. Dados e integrações externas

| Projeto | Persistência / integrações |
|---------|----------------------------|
| **ApiDPC** | Única que persiste em PG/ORA/MySQL; integra NFe, Boleto, FTP, SMTP; queue `sync` (sem fila assíncrona). |
| **DPC** | Firebase (push), Laravel Echo + Pusher (WebSocket); não persiste dados de negócio. |
| **Faisao** | AsyncStorage (fila de localização offline); envia rastreamento para ApiDPC (`POST /rastreamento`); consome Api Atendimento. |

---

## 6. Deploy e ambientes (resumo)

| Projeto | Deploy | Observação |
|---------|--------|------------|
| **ApiDPC** | Docker (PHP 7.2, nginx porta 8004); CI/CD GitHub Actions (branches alpha/beta); cron e supervisor. | `deploy.sh`; variáveis em `.env`. |
| **DPC** | Docker (Node 10 build + Apache), Firebase Hosting. | Variáveis em `config/dev.env.js`, `config/prod.env.js`. |
| **Faisao** | EAS Build (Expo); sem pipeline de CI no repositório. | URLs atualmente hardcoded; recomendado .env ou EAS env vars. |

---

## 7. Referências cruzadas

- **apidpc-arquitetura.md** — Detalhes da API REST (stack, camadas, repositórios, autenticação JWT, bancos, rotas, deploy).
- **dpc-arquitetura.md** — Detalhes do painel admin (Vue/Vuex, módulos, dpcAxios, Firebase/Pusher, deploy).
- **faisao-arquitetura.md** — Detalhes do app mobile (React Native/Expo, React Query, ApiAuth, rastreamento, deploy).
