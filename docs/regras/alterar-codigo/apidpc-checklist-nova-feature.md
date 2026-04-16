# ApiDPC — Checklist: nova feature

> Estende [_checklist-base-feature.md](_checklist-base-feature.md).

### Antes de codar (delta ApiDPC)
- Identificar o banco dos dados (PostgreSQL, Oracle, MySQL).
- Verificar se já existe Controller/Repository/Model para o recurso.
- Definir contrato: método HTTP, path, body/query, resposta `{ error, msg, data, quantidade }`.

### Model e dados
- Model enxuto com `$connection` correto, tabela e PK.
- Migration em `database/migrations/` quando usar PostgreSQL.
- Regras complexas ficam em Service, não em Model.
- Para Oracle, seguir [apidpc-oracle-padroes.md](apidpc-oracle-padroes.md) (sequences, UPPERCASE, schemas, validação via MCP).

### Repository
- `app/Repositories/` implementando `iBaseRepository` e estendendo `BaseRepository`.
- Implementar ao menos `show`, `showAll`, `store`, `update` conforme necessário.
- Queries só no Repository — nunca no Controller.

### Service (quando houver regras de negócio)
- `app/Services/` para validações, orquestração ou chamadas externas.
- Usar transações (`DB::connection()->beginTransaction()` + commit/rollback) quando mexer em mais de uma tabela.

### Controller
- Estende `Controller`, delega a Repository/Service.
- Retorno sempre JSON `{ error: 0|1, msg, data, quantidade }`.
- `try/catch` retornando `error: 1` com mensagem humanizada.

### Rotas
- Adicionar em `routes/api.php` dentro do group com prefix e middleware existentes.

### Testes e deploy
- Feature ou Unit test para o fluxo principal.
- `php artisan test` ou `./vendor/bin/phpunit`.
- Deploy alpha/beta; conferir logs após deploy.
