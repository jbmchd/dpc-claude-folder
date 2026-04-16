# ApiDPC — Convenções de código

> Backend PHP 7.2 / Laravel 5.5. Aplicar em `ApiDPC/app/**/*.php` e `ApiDPC/routes/**`.
> Regras transversais (não refatorar fora de escopo, não alterar `node_modules`, comentários em PT) estão em `CLAUDE.md`.

Ver também: [apidpc-oracle-padroes.md](apidpc-oracle-padroes.md) · [apidpc-arquitetura.md](../../arquitetura/apidpc-arquitetura.md)

## Controllers (`app/Http/Controllers/`)
- Estende `Controller`, namespace `App\Http\Controllers`.
- Recebe `Illuminate\Http\Request`; parâmetros via `$request->all()`.
- Instancia Repository (ou Service) e delega; sem regra de negócio no controller.
- Métodos já em uso: `showAll`, `store`, `edit`, `show`, `destroy`.
- Resposta: retorno do Repository/Service ou `response()->json()`; não alterar formato existente.

## Repositories (`app/Repositories/`)
- Estende `BaseRepository`, namespace `App\Repositories`.
- Interface padrão: `show($id)`, `showAll($params)`, `store($params)`, `update($params)`.
- Retorno padrão: array `{ error: 0|1, msg?, data? }`.
- Manter o padrão de try/catch do arquivo sendo editado; não padronizar em bloco.

## Rotas (`routes/`)
- Rotas protegidas dentro do grupo `middleware` `['cors', 'jwt']` e `auth:api` quando aplicável.
- Registrar em grupo/arquivo já usados para o recurso; não renomear grupos/prefixos.
- Sintaxe: `'ControllerNome@metodo'` (ex.: `'RecebimentoController@showAll'`).

## Resposta padrão da API
`{ "error": 0|1, "msg": "...", "data": [...], "quantidade": N }`
