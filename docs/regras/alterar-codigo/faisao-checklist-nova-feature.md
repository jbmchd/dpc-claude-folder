# Faisao — Checklist: nova feature

> Estende [_checklist-base-feature.md](_checklist-base-feature.md).

### Passo 0 — mapeamento cross-project (obrigatório)
- [ ] Identificar no DPC e na ApiDPC apenas as regras de negócio, contratos, validações e inteligências que servem de referência.
- [ ] Registrar no `planejamento.md` o mapeamento funcional da feature.
- Ver [faisao-convencoes.md](faisao-convencoes.md).

### Planejamento (delta Faisao)
- Definir se é nova tela, nova aba ou extensão de existente.
- Confirmar endpoints na ApiDPC ou Api Atendimento.
- Decidir se o dado é server state (React Query) ou global/local (Context/useState).

### Navegação
- Tela em `src/screens/[NomeFeature]/` (`index.tsx` + auxiliares).
- Registrar rota em Stack ou tab routes.
- Se for stack novo, adicionar tipo em `RootStackParamList`.

### API e estado
- Lista paginada → `useInfiniteQuery` com query key única, `fetchNextPage` e filtros.
- Dado único ou mutação → `useQuery` ou `useMutation`; invalidar queries relacionadas em mutations.
- HTTP via instância de `src/services/api.ts`.
- Tratar loading e erro com componente de erro/retry.

### UI
- Reutilizar componentes de `src/components/` quando fizer sentido.
- NativeWind (`className`) ou styled-components conforme padrão do módulo.
- Feedback visual: loading, estado vazio, erro com retry.

### Testes e build
- `expo start` no dispositivo/emulador.
- Testar sem rede e com 401 (logout esperado).
- `npm run lint` e `npm run test`.

### Revisão final
- PascalCase para telas/componentes; camelCase para funções e serviços.
- Imports com alias `~`.
- Sem URLs hardcoded na feature nova.
