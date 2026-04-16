# ApiDPC — Referência de Alteração de Código

> Backend PHP 7.2 / Laravel 5.5. Aplicar em `ApiDPC/app/**/*.php` e `ApiDPC/routes/**`.

Ver também: [principios-comuns-alterar-codigo.md](principios-comuns-alterar-codigo.md) · [apidpc-oracle-padroes.md](apidpc-oracle-padroes.md)

## Princípios do projeto

- Manter a organização existente de controllers, repositories, models e rotas.
- Não propor migrações estruturais do backend Laravel nem alterações arquiteturais fora do escopo da tarefa.
- Comentários e mensagens técnicas podem permanecer em português.

## Controllers (`app/Http/Controllers/`)

- Estende `Controller`, namespace `App\Http\Controllers`.
- Métodos recebem `Illuminate\Http\Request`; parâmetros via `$request->all()`.
- Instanciar Repository (ou Service) e delegar a lógica; não colocar regra de negócio no controller.
- Manter nomes de métodos já usados: `showAll`, `store`, `edit`, `show`.
- Resposta: retorno do Repository/Service ou `response()->json()`; não alterar formato existente.

## Repositories (`app/Repositories/`)

- Estende `BaseRepository`, namespace `App\Repositories`.
- Interface padrão: `show($id)`, `showAll($params)`, `store($params)`, `update($params)`.
- Retorno padrão: array com `error` (0 ou 1), `msg` (quando houver), `data` (quando houver).
- Manter padrão de try/catch do arquivo sendo editado; não padronizar tudo de uma vez.

## Rotas (`routes/`)

- Rotas protegidas dentro do grupo com `middleware` `['cors', 'jwt']` e `auth:api` quando aplicável.
- Grupos com `prefix`; registrar novas rotas no grupo e arquivo já usados para aquele recurso.
- Sintaxe: `'ControllerNome@method'` (ex.: `'RecebimentoController@showAll'`).
- Não reorganizar ou renomear grupos/prefixos existentes fora do escopo da tarefa.

## Arquitetura completa

Consultar [apidpc-arquitetura.md](../../arquitetura/apidpc-arquitetura.md).
