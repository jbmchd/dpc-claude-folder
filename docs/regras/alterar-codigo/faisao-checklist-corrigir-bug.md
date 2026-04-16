# Faisao — Checklist: corrigir bug

> Estende [_checklist-base-bug.md](_checklist-base-bug.md).

### Passo 0 — mapeamento cross-project (obrigatório)
- [ ] Identificar no DPC e na ApiDPC as regras de negócio, contratos, validações e inteligências do fluxo com problema.
- [ ] Registrar no `planejamento.md` o mapeamento funcional usado como referência.
- Ver [faisao-convencoes.md](faisao-convencoes.md).

### Camadas a verificar
- Tela (componente), Context, React Query (qual query key), serviço (`api`, `coletaQueueManager`) ou navegação.
- Inspeção de rede: bug é do app ou da API?
- Outras telas que usam o mesmo Context ou query key.
- Fluxos de localização/background → checar `coletaQueueManager` e tarefas registradas.

### Regras específicas
- Manter `api.ts` para HTTP, React Query para server state, Context para estado global, SecureStore para token.
- Cache errado → considerar `invalidateQueries`.

### Validação extra
- Token inválido/expirado (esperado: logout + tela de Login).
- Offline e reenvio ao voltar online quando aplicável.

### Testes e build
- `npm run test` e `npm run lint`.
- Se afetar build nativo ou env → validar EAS build no perfil adequado.
