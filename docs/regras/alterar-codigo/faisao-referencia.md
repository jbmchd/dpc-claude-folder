# Faisao — Referência de Alteração de Código

> App mobile React Native / Expo (TypeScript). Aplicar em `Faisao/src/**`.

Ver também: [principios-comuns-alterar-codigo.md](principios-comuns-alterar-codigo.md)

## Princípios do projeto

- Preservar a organização: `src/screens`, `src/components`, `src/routes`, `src/contexts`, `src/services`, `src/style`.
- Não propor migrações de stack ou de abordagem de estilos fora do escopo.
- Comentários e mensagens ao usuário podem permanecer em português.

## Regra obrigatória — mapeamento funcional cross-project

Antes de planejar ou implementar qualquer feature no Faisao:
1. Verificar se a funcionalidade já existe no DPC e na ApiDPC.
2. Quando existir, mapear: regras de negócio, contratos, validações e inteligências dessas aplicações.
3. Usar esse mapeamento como referência para replicar a mesma lógica no mobile.
4. Extrair apenas a **lógica funcional** — não reutilizar layout, estrutura visual ou padrão de tela do DPC/ApiDPC.
5. Quando o fluxo depender de DPC ou ApiDPC, consultar [visao-geral-ecossistema-dpc.md](../../arquitetura/visao-geral-ecossistema-dpc.md).

## Telas (`src/screens/<Nome>/`)

- Uma pasta por tela/feature (ex.: `Cliente/`, `Pedido/`, `Titulos/`).
- Arquivo principal: `index.tsx`; filtros: `Filter.tsx`; totais: `Totals.tsx`; tipos: `types.ts`; estilos: `styles.ts`.
- Alias `~/` para imports de qualquer coisa em `src/`; relativos para arquivos da mesma pasta.
- Padrão: `React.FC<Props>` e `export default`.
- Manter padrão de estado (useState, useQuery, useInfiniteQuery) das telas existentes.

## Componentes e estilos (`src/components/<Nome>/`)

- Ponto de entrada: `index.tsx`; estilos: `styles.ts` com **styled-components/native**; tipos: `types.ts`.
- Cores: usar `~/style/colors` com `color('primary')`, `color('white')`, etc.
- `React.FC<Props>` e export default; não trocar styled-components por StyleSheet.
- Onde o projeto já mistura NativeWind (`className`) com styled, manter o padrão do componente; não padronizar sem pedido.

## Arquitetura completa

Consultar [faisao-arquitetura.md](../../arquitetura/faisao-arquitetura.md).
