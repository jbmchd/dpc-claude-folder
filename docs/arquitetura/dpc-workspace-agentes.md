# DPC Workspace — Contexto para Agentes

Este documento complementa os agentes do workspace DPC. Deve ser consultado antes de qualquer implementação ou correção nos projetos do ecossistema.

## Projetos do workspace

| Projeto | Stack | Pasta |
|---------|-------|-------|
| ApiDPC | PHP 7.2 / Laravel 5.5 | `ApiDPC/` |
| DPC | Vue.js 2 / Vuex | `DPC/src/` |
| Faisao | React Native / Expo / TypeScript | `Faisao/src/` |

## Docs obrigatórios por projeto

Substituir `<projeto>` por `apidpc`, `dpc` ou `faisao`:

- **Checklist de bug:** `.claude/docs/regras/alterar-codigo/<projeto>-checklist-corrigir-bug.md`
- **Checklist de feature:** `.claude/docs/regras/alterar-codigo/<projeto>-checklist-nova-feature.md`
- **Princípios do projeto:** `.claude/docs/regras/alterar-codigo/<projeto>-principios-projeto.md`

## Mudanças cross-project

Consultar [visao-geral-ecossistema-dpc.md](visao-geral-ecossistema-dpc.md) sempre que a mudança envolver mais de um projeto ou alterar contratos entre ApiDPC, DPC e Faisao.
