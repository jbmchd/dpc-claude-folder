# ApiNFE — Checklist: nova feature

> Estende [_checklist-base-feature.md](_checklist-base-feature.md). Convenções: [apinfe-convencoes.md](apinfe-convencoes.md).

### Antes de codar (delta ApiNFE)
- Confirmar que a feature é **fiscal** (SEFAZ, NF-e, DANFE, averbação). Se for dado de negócio comum, o lugar é a **ApiDPC**, não aqui.
- Identificar o banco: Oracle (`consinco`/`poseidon`) para negócio; PostgreSQL (`acesso`) só para usuário.
- Verificar se já existe Controller/Repository/Model para o recurso (o projeto é pequeno — reuso é o normal).
- Definir contrato com o front do DPC: método, path, body e **nomes das chaves** da resposta.
- Decidir o gatilho: rota HTTP, command agendado, ou tabela compartilhada (como a Senig faz com a ApiDPC).

### Model e dados
- Novo model na **raiz de `app/`**, estendendo `ModelBase`, com `$table`/`$primaryKey`/`$connection`/`$fillable` no `__construct`.
- `showAll($params, $return_data = true, $fillable = null)` seguindo o padrão de filtros (`isset && !empty`, `whereIn` para array).
- Sem migration para Oracle — DDL é feito pelo DBA; validar estrutura no **MCP DPC** antes.
- Padrões Oracle (sequences, uppercase, schema) em [apidpc-oracle-padroes.md](apidpc-oracle-padroes.md).

### Repository
- `app/Repositories/`, estendendo `BaseRepository` (vazio — sem interface obrigatória).
- Retorna array/Collection; nunca `response()->json()`.
- Transação explícita via `DB::connection(env('DB_CONNECTION_ORACLE'))` ao gravar em mais de uma tabela.
- Integração externa nova → repository dedicado, sem acesso a banco (modelo: `SenigRepository`).

### Controller
- Estende `Controller`; extrai `userId`/`token` no construtor; `unset($params['token'])` antes de delegar.
- `try/catch` + `response()->json(['error' => 0|1, 'mensagem' => ..., ...])`.

### Rotas
- `routes/web.php`, **dentro** do grupo `['cors', 'jwt']`, em `prefix` existente quando possível.
- Rota pública só com decisão explícita do usuário (as atuais são dívida conhecida, não padrão).

### Command agendado (quando aplicável)
- Registrar em `Console/Kernel.php`, sempre sob `if (env('RUN_SCHEDULE') == 1)` e com `->withoutOverlapping()`.
- Oferecer `--dry-run`, `--limit` e filtro pontual (`--chave`) para teste seguro.
- Item a item com `try/catch` individual + registro best-effort da falha.
- Se precisar de worker de fila, criar o Job de verdade em `app/Jobs/` — os 27 `.conf` de supervisor existentes **não têm jobs correspondentes** e não servem de referência.

### Certificado / SEFAZ
- Certificado vem de `poseidon.dpc_conta_certif_digital_emp` via `CertificadoDigitalRepository::buscaConteudoCertificado()`; nunca hardcode nem novo arquivo no repo.
- Respeitar `TIPO_AMBIENTE` no `config.json` do sped-nfe; documentar se o serviço só operar em produção.
- Tratar `cStat`/`dStatus` explicitamente e persistir o retorno bruto para auditoria.

### Testes e deploy
- Não há suíte real; validar via tela do DPC (ou `--dry-run` no command) e logs do container.
- Sem CI/CD no repositório — subida é manual (`./build.run` / `docker compose`).
- Variável nova → adicionar ao `.env.example` **sem valor real** e avisar quem opera o ambiente.
