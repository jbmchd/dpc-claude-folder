# Faisao – Checklist: corrigir bug

### Passo 0 – Entender fluxo no DPC e na ApiDPC

- [ ] Aplicar a regra de referencia funcional definida em [faisao-referencia.md](faisao-referencia.md).
- [ ] Identificar no `DPC` e na `ApiDPC` as regras de negocio, contratos, validacoes e inteligencias envolvidas no fluxo com problema.
- [ ] Registrar no `planejamento.md` o mapeamento funcional usado como referencia para a correção no app mobile.

### Reprodução e escopo

- [ ] Reproduzir o bug em dispositivo/emulador (passos, usuário, dados, rede on/off).
- [ ] Identificar camada: tela (componente), Context, React Query (qual query key), serviço (api, coletaQueueManager) ou navegação.
- [ ] Verificar se o problema é do app (estado, UI, chamada) ou da API (resposta errada – inspecionar rede).

### Análise de impacto

- [ ] Listar outras telas que usam o mesmo Context ou a mesma query key.
- [ ] Se o bug for em fluxo de localização/background, checar coletaQueueManager e tarefas registradas.
- [ ] Rodar testes existentes: `npm run test`.

### Correção

- [ ] Fazer alteração mínima necessária; evitar refactors grandes na mesma entrega.
- [ ] Manter padrão: api.ts para HTTP, React Query para server state, Context para estado global, SecureStore para token.
- [ ] Se o bug for de exibição/cache, considerar invalidação de query (`invalidateQueries`).

### Validação

- [ ] Testar de novo o cenário que falhava; confirmar que o bug foi resolvido.
- [ ] Testar cenários de sucesso do mesmo fluxo.
- [ ] Navegar por telas relacionadas (mesma aba e outras que usam o mesmo Context ou queries).
- [ ] Testar com token inválido ou expirado (esperado: logout e tela de Login).
- [ ] Se aplicável: testar offline e novo envio quando voltar online.

### Regressão e entrega

- [ ] Rodar `npm run test` e `npm run lint`.
- [ ] Revisar diff: sem console.log desnecessários, sem alteração em arquivos não relacionados.
- [ ] Se a correção afetar build (native ou env), validar EAS build em perfil adequado.
