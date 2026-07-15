# ApiDPC — Convenções de código

> Backend PHP 7.2 / Laravel 5.5. Aplicar em `ApiDPC/app/**/*.php` e `ApiDPC/routes/**`.
> Regras transversais (não refatorar fora de escopo, não alterar `node_modules`, comentários em PT) estão em `CLAUDE.md`.

Ver também: [apidpc-oracle-padroes.md](apidpc-oracle-padroes.md) · [apidpc-arquitetura.md](../../arquitetura/apidpc-arquitetura.md)

## Controllers (`app/Http/Controllers/`)
- Estende `Controller`, namespace `App\Http\Controllers`.
- Recebe `Illuminate\Http\Request`; parâmetros via `$request->all()`.
- Instancia Repository (ou Service) e delega; sem regra de negócio no controller.
- Métodos já em uso: `showAll`, `store`, `edit`, `show`, `destroy`.
- **`response()->json()` é responsabilidade exclusiva do controller.** Em código novo, o controller monta o `$retorno` (`error`, `message`, `data`), faz a validação de entrada e o wrap em JSON; não alterar formato de resposta existente.

## Repositories (`app/Repositories/`)
- Estende `BaseRepository`, namespace `App\Repositories`.
- Interface padrão: `show($id)`, `showAll($params)`, `store($params)`, `update($params)`.
- **Nunca retornar `response()->json()` em método novo** — retornar dados brutos (array/Collection/int) para permitir reuso da consulta em outros contextos. Um repository que devolve JSON trava o consumidor no formato HTTP (má prática detectada no card #3191, corrigida no PR ApiDPC#987). Métodos legados que já devolvem response ficam como estão até serem tocados por outra demanda.
- Retorno padrão dos métodos legados: array `{ error: 0|1, msg?, data? }`.
- Manter o padrão de try/catch do arquivo sendo editado; não padronizar em bloco.

## Rotas (`routes/`)
- Rotas protegidas dentro do grupo `middleware` `['cors', 'jwt']` e `auth:api` quando aplicável.
- Registrar em grupo/arquivo já usados para o recurso; não renomear grupos/prefixos.
- Sintaxe: `'ControllerNome@metodo'` (ex.: `'RecebimentoController@showAll'`).

## Resposta padrão da API
`{ "error": 0|1, "msg": "...", "data": [...], "quantidade": N }`
