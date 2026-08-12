# ApiNFE — Convenções de código

> Backend PHP 8.2 / **Lumen 10** (não é Laravel). Aplicar em `ApiNFE/app/**/*.php` e `ApiNFE/routes/**`.
> Regras transversais (não refatorar fora de escopo, não alterar `node_modules`, comentários em PT) estão em `CLAUDE.md`.

Ver também: [apinfe-arquitetura.md](../../arquitetura/apinfe-arquitetura.md) · [apidpc-oracle-padroes.md](apidpc-oracle-padroes.md)

## Cuidados de Lumen 10 (não regredir)
- `bootstrap/app.php` carrega `.env` e os configs **manualmente** (`LoadEnvironmentVariables`, `$app->configure(...)`). Não remover — sem isso `env()` e `config()` voltam vazios.
- Auth no request: **sempre** `$request->attributes->set('auth', [...])` e leitura via `($request->attributes->get('auth', []))['user_id'] ?? null`. Nunca `$request->auth = $user` (padrão Lumen 5.x, quebra na v10).
- `JWT::decode($token, new Key($secret, 'HS256'))` — assinatura da `firebase/php-jwt` v6.
- `Handler::report(Throwable $e)` e `render($request, Throwable $e)` — Lumen 10 exige `Throwable`, não `Exception`.

## Controllers (`app/Http/Controllers/`)
- Estende `Controller`, namespace `App\Http\Controllers`.
- Construtor recebe `Request` e extrai `userId`/`token`; parâmetros via `$request->all()`, com `unset($params['token'])` antes de repassar ao repository.
- Instancia o Repository com `new` e delega. **Sem query nem regra de negócio no controller.**
- Sempre `return response()->json($retorno)`. **Nunca `echo`/`print_r`** — devolve texto cru e quebra o cliente.
- `try/catch` montando `$retorno` humanizado; não deixar exceção vazar sem mensagem.

## Repositories (`app/Repositories/`)
- Estende `BaseRepository` (classe abstrata **vazia** — não há interface a implementar), namespace `App\Repositories`.
- Retornar **array/Collection**, nunca `response()->json()`.
- Formato de erro padrão do projeto: `['error' => 1, 'mensagem' => '...']` — atenção: é **`mensagem`**, não `msg` como na ApiDPC.
- Sucesso: `['error' => 0, ...dados]`.
- Transação quando gravar em mais de uma tabela:
  ```php
  $connection = DB::connection(env('DB_CONNECTION_ORACLE'));
  $connection->beginTransaction();
  // ...
  $connection->commit();
  ```
- Repository de integração externa (SEFAZ/SOAP) não acessa banco — mantenha a separação de `SenigRepository`.

## Models (`app/*.php`)
- Ficam na **raiz de `app/`** (não em `app/Models/`), estendem `ModelBase`.
- Definir `$table`, `$primaryKey`, `$connection` e `$fillable` **dentro do `__construct`**:
  ```php
  public function __construct()
  {
      $this->table      = "poseidon.dpc_conta_entrada_nota";
      $this->primaryKey = "cod_entrada_nota";
      $this->connection = env('DB_CONNECTION_ORACLE');
      $this->fillable   = ['n.coluna', DB::raw('funcao(x) as alias')];
      parent::__construct();
  }
  ```
- **`$fillable` aqui é a lista de colunas do `SELECT`**, não mass-assignment.
- `showAll()` é `protected` e chamado estaticamente (`Model::showAll($params)`) via `__callStatic` do Eloquent. Manter a assinatura `($params, $return_data = true, $fillable = null)`; com `$return_data = false` o método devolve `count()`.
- Filtros seguem o padrão `isset() && !empty()` + `gettype() == "array" ? whereIn : where`.
- Sempre qualificar o schema (`consinco.`, `poseidon.`) e usar alias de tabela.
- Nunca expor a coluna `certificado` (PFX) no `$fillable` padrão — só via `buscaConteudoCertificado()`.

## Oracle
- Datas/horas do servidor: `DB::raw('SYSTIMESTAMP')` ou `DB::raw('sysdate')`.
- Interpolar valor em `whereRaw` **apenas** quando for número/valor totalmente controlado; preferir binding.
- Colunas e nomes de objeto seguem os padrões da [apidpc-oracle-padroes.md](apidpc-oracle-padroes.md); validar query no **MCP DPC** antes de virar código.

## Rotas (`routes/web.php`)
- Arquivo único. Rotas autenticadas **dentro** do grupo `['middleware' => ['cors', 'jwt']]`, agrupadas por `prefix`.
- Sintaxe `'ControllerNome@metodo'`; o namespace já é aplicado em `bootstrap/app.php`.
- **Não criar rota nova fora do grupo autenticado** sem decisão explícita — as públicas existentes (`/gatilho/*`, `/consulta/*`) são dívida conhecida, não padrão a seguir.

## Commands (`app/Console/Commands/`)
- Registrar em `app/Console/Kernel.php`; agendamento **sempre** dentro do guard `if (env('RUN_SCHEDULE') == 1)`.
- Usar `->withoutOverlapping()` em job com I/O externo lento (SOAP/SEFAZ).
- Processar item a item com `try/catch` individual: uma falha não pode abortar o lote.
- Oferecer `--dry-run` em comando que escreve em serviço externo — a Senig **não tem homologação**.

## Integrações externas
- SEFAZ via `NFePHP\NFe\Tools`; parse de retorno com `DOMDocument` ou `Standardize`.
- SOAP Senig: parâmetros **posicionais** (`__soapCall($metodo, [$xml, $cnpj])`), serviço Delphi/rpc. Manter `trace => 1` e ajustar `default_socket_timeout` além do `connection_timeout`.
- Parse defensivo: retorno pode vir como XML **escapado dentro de nó de texto**; tratar namespace com `getElementsByTagNameNS('*', ...)`.
- Erro de comunicação vira `['error' => 1, 'mensagem' => ...]` + `Log::debug` com request/response — não deixar a exceção subir.

## Resposta padrão da API
```json
{ "error": 0, "mensagem": "...", "entrada": [], "contador": 0 }
```
Cada endpoint nomeia sua própria chave de dados (`entrada`, `evento`, `nsu`, `pessoa`, `xml`, `pdf`). Ao editar endpoint existente, **preservar as chaves atuais** — o DPC depende delas.
