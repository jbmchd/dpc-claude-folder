# ApiDPC – Mapa mental

## Mapa mental textual do sistema

```
ApiDPC (API REST Laravel)
├── Entrada
│   ├── HTTP (public/index.php → Kernel → Rotas)
│   ├── CLI (artisan → Console Kernel)
│   └── Middlewares
│       ├── CORS
│       ├── JWT (RefreshToken, CustomGetUserFromToken)
│       └── jwt.refresh
├── Rotas
│   ├── api.php (prefixo /api, ~2.738 linhas)
│   ├── web.php
│   ├── itg.php (integrações)
│   └── console.php
├── Camada de aplicação
│   ├── Controllers (382+)
│   │   ├── Por domínio (Meta, Recebimento, Usuarios, etc.)
│   │   └── Padrão: showAll, store, edit, destroy
│   ├── Services (5)
│   │   ├── StatusService
│   │   ├── BoletoAvistaService
│   │   ├── CriticaPedidoService
│   │   ├── GestaoPontoService
│   │   └── PolibrasUploadImageService
│   └── Repositories (302+)
│       ├── iBaseRepository / BaseRepository
│       └── Um por entidade (VendedorRepository, etc.)
├── Modelo de dados
│   ├── Models (300+, Eloquent)
│   ├── Connections
│   │   ├── pgsql / pgsql_tst (PostgreSQL – usuários/app)
│   │   ├── oracle / oracle_tst (Oracle – ERP)
│   │   └── asterisk_cdr (MySQL – CDR)
│   └── Migrations, Seeds, Factories
├── Autenticação
│   ├── JWT (tymon/jwt-auth)
│   ├── User (acesso.dim_usuario, PostgreSQL)
│   ├── TTL 2h, refresh 1 ano
│   └── Blacklist grace 30s
├── Integrações
│   ├── APIs HTTP (Guzzle): NFe, Boleto, Pedido, Atendimento, WebSocket, Sintegra
│   ├── FTP: Dovemail, SIME, relatórios preço
│   └── SMTP (notificações)
├── Infraestrutura
│   ├── Logs (daily + Discord)
│   ├── Cache (file)
│   ├── Queue (sync)
│   └── Config (config/*.php)
├── Deploy
│   ├── Docker (php-fpm + nginx)
│   ├── GitHub Actions (alpha/beta)
│   ├── deploy.sh
│   └── Cron (Scheduler)
└── Resposta padrão
    └── { error: 0|1, msg: "...", data: [...], quantidade: N }
```
