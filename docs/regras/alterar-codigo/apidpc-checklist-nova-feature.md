# ApiDPC – Checklist: implementar nova feature

### Antes de codar

- [ ] Entender o domínio e em qual banco os dados ficam (PostgreSQL, Oracle ou MySQL).
- [ ] Verificar se já existe Controller/Repository/Model para o recurso (reaproveitar ou estender).
- [ ] Definir contrato da API: método HTTP, path, body/query e formato de resposta (`error`, `msg`, `data`, `quantidade`).

### Model e dados

- [ ] Criar ou estender Model com `$connection` correto e tabela/primary key.
- [ ] Se precisar de migration (PostgreSQL), criar em `database/migrations/`.
- [ ] Manter Models enxutos (regras complexas em Service).

### Repository

- [ ] Criar Repository em `app/Repositories/` implementando `iBaseRepository` e estendendo `BaseRepository`.
- [ ] Implementar pelo menos: `show`, `showAll`, `store`, `update` conforme necessidade.
- [ ] Manter queries apenas no Repository; não colocar SQL em Controller.

### Service (se houver regras de negócio)

- [ ] Criar Service em `app/Services/` quando houver validações, orquestração ou chamadas a APIs externas.
- [ ] Usar transações (`DB::connection()->beginTransaction()` + commit/rollback) quando fizer sentido.

### Controller

- [ ] Criar ou estender Controller em `app/Http/Controllers/`.
- [ ] Chamar Repository (e Service quando existir); não colocar lógica de negócio pesada no Controller.
- [ ] Retornar sempre JSON: `response()->json(['error' => 0|1, 'msg' => '...', 'data' => ..., 'quantidade' => N])`.
- [ ] Tratar exceções (try/catch) e retornar `error: 1` com mensagem adequada.

### Rotas

- [ ] Adicionar rotas em `routes/api.php` dentro do group com prefixo e middleware existentes.
- [ ] Preferir agrupar por recurso (prefix).

### Validação e segurança

- [ ] Validar entrada (Request ou validação manual).
- [ ] Não expor dados sensíveis ou stack trace em produção (`APP_DEBUG=false`).
- [ ] Usar transações em operações que alterem mais de uma tabela.

### Testes e deploy

- [ ] Escrever ao menos um teste (Feature ou Unit) para o fluxo principal.
- [ ] Rodar testes locais: `php artisan test` ou `./vendor/bin/phpunit`.
- [ ] Seguir fluxo de deploy (alpha/beta) e conferir logs (storage + Discord) após deploy.

### Revisão final

- [ ] Nomenclatura alinhada ao projeto (PascalCase para classes, camelCase para métodos).
- [ ] Sem SQL raw em Controller; sem lógica de negócio complexa em Controller quando houver Service.
- [ ] Resposta da API no formato padrão e códigos HTTP coerentes.
