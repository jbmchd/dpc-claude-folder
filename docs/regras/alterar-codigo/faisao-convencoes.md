# Faisao — Convenções de código

> App mobile React Native / Expo (TypeScript). Aplicar em `Faisao/src/**`.
> Regras transversais estão em `CLAUDE.md`.

Ver também: [faisao-arquitetura.md](../../arquitetura/faisao-arquitetura.md)

## Regra obrigatória — mapeamento funcional cross-project

Antes de planejar ou implementar qualquer feature/bug no Faisao:
1. Verificar se o fluxo já existe no DPC e na ApiDPC.
2. Mapear regras de negócio, contratos, validações e inteligências desses sistemas.
3. Usar esse mapeamento para replicar a **lógica funcional** — sem reaproveitar layout ou estrutura visual do DPC.
4. Registrar o mapeamento em `planejamento.md` da tarefa.
5. Quando o fluxo depender de DPC/ApiDPC, consultar [visao-geral-ecossistema-dpc.md](../../arquitetura/visao-geral-ecossistema-dpc.md).

## Telas (`src/screens/<Nome>/`)
- Uma pasta por tela/feature (`Cliente/`, `Pedido/`, `Titulos/`, etc.).
- Arquivo principal: `index.tsx`; filtros: `Filter.tsx`; totais: `Totals.tsx`; tipos: `types.ts`; estilos: `styles.ts`.
- Alias `~/` para imports de `src/`; relativos dentro da mesma pasta.
- Padrão: `React.FC<Props>` + `export default`.
- Estado: `useState`, `useQuery`, `useInfiniteQuery` seguindo o padrão das telas existentes.

## Componentes e estilos (`src/components/<Nome>/`)
- Ponto de entrada: `index.tsx`; estilos: `styles.ts` com **styled-components/native**; tipos: `types.ts`.
- Cores: `~/style/colors` via `color('primary')`, `color('white')`, etc.
- Onde o projeto já mistura NativeWind (`className`) com styled, manter o padrão do arquivo — não padronizar sem pedido.
- URLs nunca hardcoded em feature nova.
