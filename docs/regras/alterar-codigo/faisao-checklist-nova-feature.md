# Faisao – Checklist: implementar nova feature

### Planejamento – espelhar DPC + ApiDPC

- [ ] Aplicar a regra de referencia funcional definida em [faisao-referencia.md](faisao-referencia.md).
- [ ] Identificar no `DPC` e na `ApiDPC` apenas as regras de negocio, contratos, validacoes e inteligencias que servem de referencia para a feature.
- [ ] Registrar no `planejamento.md` o mapeamento funcional da feature.

### Planejamento

- [ ] Definir se é nova tela, nova aba ou extensão de tela existente.
- [ ] Confirmar se a ApiDPC (ou Api Atendimento) já expõe os endpoints necessários.
- [ ] Decidir se o dado é estado do servidor (React Query) ou apenas global/local (Context/useState).

### Navegação

- [ ] Criar tela em `src/screens/[NomeFeature]/` (ex.: `index.tsx` e componentes auxiliares).
- [ ] Registrar rota no Stack ou nas tab routes.
- [ ] Se for stack novo, adicionar tipo em `RootStackParamList`.

### API e estado

- [ ] Se for lista paginada: usar `useInfiniteQuery` com query key única, `fetchNextPage` e filtros.
- [ ] Se for dado único ou mutação: usar `useQuery` ou `useMutation`; em mutations, invalidar queries relacionadas.
- [ ] Chamar sempre a instância de `api` de `src/services/api.ts`.
- [ ] Tratar loading e erro (estados do React Query + componente de erro/retry).

### UI

- [ ] Reutilizar componentes de `src/components/` quando fizer sentido.
- [ ] Usar NativeWind (className) ou styled-components conforme padrão do módulo.
- [ ] Exibir feedback: loading durante fetch, estado vazio, erro com opção de retry.

### Testes e build

- [ ] Rodar `expo start` e testar no dispositivo/emulador.
- [ ] Testar fluxo sem rede e com 401 (logout esperado).
- [ ] Rodar `npm run lint` e `npm run test`.

### Revisão final

- [ ] Nomenclatura: PascalCase para telas/componentes, camelCase para funções e arquivos de serviço.
- [ ] Imports com alias `~`.
- [ ] Sem URLs hardcoded na nova feature.
