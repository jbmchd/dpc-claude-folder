# DPC — Checklist: corrigir bug

> Estende [_checklist-base-bug.md](_checklist-base-bug.md).

### Camadas a verificar
- Componente Vue, módulo Vuex, rota, interceptor, `Account.js`, `dpcAxios`.
- Inspeção de rede: bug é do front (estado/UI/chamada) ou da API (dado errado)?
- Outros componentes que usam o mesmo store/endpoint.
- Event bus (`bus.$emit`/`$on`) — conferir outros listeners do mesmo evento.

### Regras específicas
- Manter `dpcAxios` para API, Vuex para estado global, formato de resposta da API.
- Não remover checagens de permissão sem alternativa segura.
- Se o bug for de cache/exibição, considerar `invalidateQueries` ou reset de state.
- Modais com dependências assíncronas → ver [dpc-padroes-async.md](dpc-padroes-async.md).

### Validação extra
- Testar com token expirado/inválido (esperado: logout e redirecionamento).
- Navegar por telas do mesmo módulo e módulos que compartilham store/API.

### Testes e build
- `npm run unit`.
- `npm run build` e abrir build local se possível.
- Diff sem `console.log` desnecessário.
