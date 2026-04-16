# DPC — Checklist: nova feature

> Estende [_checklist-base-feature.md](_checklist-base-feature.md).

### Planejamento (delta DPC)
- Definir se é novo módulo em `src/app/` ou extensão de existente.
- Listar telas/rotas e dados; conferir endpoints na ApiDPC.
- Verificar permissões/menus (se exige novo item ou permissão no backend).

### Estrutura do módulo
- Pasta `src/app/[NomeFeature]/` com `components/`, `routes.js` e `vuex/` quando houver estado.
- Registrar `routes.js` em `src/app/routes.js` e Vuex em `src/app/vuex.js`.

### Componentes
- Telas em `src/app/[NomeFeature]/components/`.
- Reutilizar `components/root/` quando fizer sentido.
- SFC com template + script + `<style lang="scss" scoped>`.

### API
- Constantes de endpoint em `config/api.env.js` se necessário.
- Chamadas via `dpcAxios.connection()`.
- Resposta esperada `{ error, msg, data, quantidade }`.
- Modais com carregamento assíncrono dependente → seguir [dpc-padroes-async.md](dpc-padroes-async.md).

### Estado e navegação
- Vuex para estado global da feature; `data()` para estado local.
- Garantir que rotas novas passem pelo `beforeEach`.

### Testes e build
- `npm run dev` e navegar pelos fluxos novos.
- `npm run build` (sem erros Webpack).
- `npm run unit`.

### Revisão final
- PascalCase para componentes/rotas name; camelCase para métodos; UPPER_SNAKE para constantes de API.
- Sem lógica de negócio pesada no template.
