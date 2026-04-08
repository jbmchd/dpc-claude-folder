# DPC (admin-dpc-vue) – Checklist: corrigir bug

### Reprodução e escopo

- [ ] Reproduzir o bug no ambiente de dev (passos, usuário, dados, rota).
- [ ] Identificar camada: componente Vue, Vuex (qual módulo), rota, ou interceptor/Account/dpcAxios.
- [ ] Verificar se o problema é de frontend (estado, UI, chamada à API) ou se a API retorna dado errado (inspecionar rede).

### Análise de impacto

- [ ] Listar componentes que usam o mesmo store (módulo Vuex) ou o mesmo endpoint.
- [ ] Verificar se o fluxo usa event bus (`bus.$emit`/`$on`); checar outros listeners do mesmo evento.
- [ ] Ver se há outros lugares com lógica parecida que possam ter o mesmo defeito.
- [ ] Rodar testes existentes: `npm run unit`.

### Correção

- [ ] Fazer alteração mínima necessária; evitar refactors grandes na mesma entrega.
- [ ] Manter padrão: dpcAxios para API, Vuex para estado global, formato de resposta da API.
- [ ] Não remover validações ou checagens de permissão sem substituir por alternativa segura.

### Validação

- [ ] Testar de novo o cenário que falhava; confirmar que o bug foi resolvido.
- [ ] Testar cenários de sucesso do mesmo fluxo (outro filtro, outro registro).
- [ ] Navegar por telas relacionadas (mesmo módulo e módulos que compartilham store ou API).
- [ ] Testar com token expirado ou inválido (esperado: logout e redirecionamento).

### Regressão e entrega

- [ ] Rodar `npm run unit`.
- [ ] Rodar `npm run build` e abrir a build de produção localmente se possível.
- [ ] Revisar diff: sem `console.log` desnecessários, sem alteração em arquivos não relacionados.
