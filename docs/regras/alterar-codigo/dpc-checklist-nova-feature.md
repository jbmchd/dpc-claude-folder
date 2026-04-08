# DPC (admin-dpc-vue) – Checklist: implementar nova feature

### Planejamento

- [ ] Definir se a feature é um novo módulo em `src/app/` ou extensão de um existente.
- [ ] Listar telas (rotas) e dados necessários; conferir se a ApiDPC já expõe os endpoints.
- [ ] Verificar permissões/menus: se o novo fluxo exige novo item de menu ou permissão no backend.

### Estrutura do módulo

- [ ] Criar pasta `src/app/[NomeFeature]/`.
- [ ] Criar `routes.js` no módulo e registrar em `src/app/routes.js`.
- [ ] Se a feature tiver estado próprio, criar `vuex/` e registrar em `src/app/vuex.js`.

### Componentes

- [ ] Criar componentes de tela em `src/app/[NomeFeature]/components/`.
- [ ] Reutilizar componentes de `components/root/` quando fizer sentido.
- [ ] Manter SFC: template, script, style scoped com SCSS.

### API

- [ ] Adicionar constantes de endpoint em `config/api.env.js` se necessário.
- [ ] Usar `dpcAxios.connection()` para chamadas.
- [ ] Tratar resposta no formato padrão (`error`, `msg`, `data`, `quantidade`).

### Estado e navegação

- [ ] Usar módulo Vuex para estado global da feature; `data()` do componente para estado local.
- [ ] Garantir que as novas rotas estejam protegidas pelo `beforeEach`.

### Testes e build

- [ ] Rodar `npm run dev` e navegar pelas novas rotas.
- [ ] Rodar `npm run build` e verificar se não há erros de Webpack.
- [ ] Executar `npm run unit`.

### Revisão final

- [ ] Nomenclatura: PascalCase para componentes e rotas name; camelCase para métodos; constantes de API em UPPER_SNAKE.
- [ ] Sem lógica de negócio pesada no template.
