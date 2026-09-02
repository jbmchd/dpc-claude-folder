# DPC Workspace

## Escopo
- Workspace contém ApiDPC, DPC, Faisao, DpcInventario e ApiNFE. Regras valem para todos os agentes e sessões.

## Regras transversais
- Identificar projeto e área afetados antes de alterar código.
- Preferir mudanças pequenas, aderentes ao padrão existente; evitar refatorações fora do escopo.
- Preservar contratos entre frontend, mobile e API.
- Nunca alterar `node_modules/**` sem pedido explícito na mesma mensagem.
- Dúvida estrutural → consultar `.claude/docs` antes de agir.
- Não copiar conteúdo longo de doc para a resposta quando um link resolve.

## Locais protegidos
- `.claude/docs/**`, `.claude/agents/**`, `.claude/commands/**`, `CLAUDE.md`.
- Só alterar com pedido explícito citando o caminho. Default: leitura; pedir confirmação antes de edit/rename/move/delete.
- **Exceção:** `.claude/docs/glossario-dominio.md` pode ser atualizado sem confirmação quando o `/explicar` estiver em execução (incluindo via `--explicar`), para registrar termos novos. Fora desse contexto, segue protegido.

## MCPs obrigatórios
- Documentação externa → MCP `context7`.
- Banco de dados → MCP DPC.
- Trello → MCP Trello (board `DPC Dev`, card por `idShort` ou link).

### Exceção: domínio fiscal (SEFAZ, NF-e, CT-e, MDF-e)

Para regras operacionais da SEFAZ, **não usar Context7** — ele indexa documentação de bibliotecas, e a `sped-nfe` documenta a *API dela*, não as regras do fisco. Pior: a tabela de cStat da `sped-nfe` chegou a descrever o código 656 de forma incompleta, o que atrasou um diagnóstico.

Consultar, nesta ordem:

1. **Portal oficial da NF-e** — Notas Técnicas e Manual de Orientação do Contribuinte (`nfe.fazenda.gov.br`). É a fonte normativa.
2. **Bases de conhecimento de provedores**, que documentam o comportamento *real* em produção — o que a NT não detalha:
   - `atendimento.tecnospeed.com.br` e `blog.tecnospeed.com.br`
   - `blog.nstecnologia.com.br`
   - `focusnfe.com.br/blog`
   - `oobj.com.br/bc`
   - `qive.com.br/blog`
   - `tributos.io/blog`
   - `acbr.sourceforge.io` (documentação do ACBr)

Motivo: limites de consumo, causas de rejeição e comportamento de bloqueio raramente estão na NT com a precisão necessária. Os provedores operam esses serviços em escala e publicam o que aprenderam em campo.

Caso concreto: a causa do `cStat 656` que travou a implantação da captura de NF-e não estava na NT 2014.002 nem no Context7 — estava numa base de conhecimento de provedor. Ver [12_sefaz-656-consumo-indevido.md](.claude/docs/nfe_dfe/docs/12_sefaz-656-consumo-indevido.md).

## Índice de documentação

| Preciso de… | Arquivo |
|---|---|
| Visão do ecossistema e contratos cross-project | [visao-geral-ecossistema-dpc.md](.claude/docs/arquitetura/visao-geral-ecossistema-dpc.md) |
| Glossário de termos de domínio (dicionário vivo) | [glossario-dominio.md](.claude/docs/glossario-dominio.md) |
| Arquitetura detalhada por projeto | `.claude/docs/arquitetura/<projeto>-arquitetura.md` |
| Arquitetura DpcInventario (WMS) | [dpcInventario-arquitetura.md](.claude/docs/arquitetura/dpcInventario-arquitetura.md) |
| Arquitetura ApiNFE (fiscal: SEFAZ/NF-e/Senig) | [apinfe-arquitetura.md](.claude/docs/arquitetura/apinfe-arquitetura.md) |
| **Módulo DFe** — captura própria de NF-e/CT-e/NFS-e de entrada, que substitui a Qive. Hub com 14 documentos e os scripts de banco | [nfe_dfe/docs/readme.md](.claude/docs/nfe_dfe/docs/readme.md) |
| Convenções de código por projeto | `.claude/docs/regras/alterar-codigo/<projeto>-convencoes.md` |
| Checklist bug / feature por projeto | `.claude/docs/regras/alterar-codigo/<projeto>-checklist-corrigir-bug.md` e `-nova-feature.md` |
| Fluxo de tarefas e Trello | [tarefas.md](.claude/docs/regras/gerenciar-regras/tarefas.md) |
| Branch da tarefa | [git-workflow-branches.md](.claude/docs/regras/gerenciar-regras/git-workflow-branches.md) |
| Criar/alterar regras, commands, agentes, docs | [criar-regras.md](.claude/docs/regras/gerenciar-regras/criar-regras.md) |
| Migração Maracanã → DPC/ApiDPC | [migracao-legado.md](.claude/docs/regras/gerenciar-regras/migracao-legado.md) |
| Padrões Oracle (ApiDPC) | [apidpc-oracle-padroes.md](.claude/docs/regras/alterar-codigo/apidpc-oracle-padroes.md) |
| Padrões async Vue (DPC) | [dpc-padroes-async.md](.claude/docs/regras/alterar-codigo/dpc-padroes-async.md) |

Para mudanças que envolvam mais de um projeto, começar sempre pela visão do ecossistema.

## Regras por projeto
- **ApiDPC** (`ApiDPC/app/**`, `ApiDPC/routes/**`): Laravel 5.5 / PHP 7.2 — ver [apidpc-convencoes.md](.claude/docs/regras/alterar-codigo/apidpc-convencoes.md).
- **DPC** (`DPC/src/**`): Vue 2 / Vuex — ver [dpc-convencoes.md](.claude/docs/regras/alterar-codigo/dpc-convencoes.md).
- **Faisao** (`Faisao/src/**`): React Native / Expo / TS — ver [faisao-convencoes.md](.claude/docs/regras/alterar-codigo/faisao-convencoes.md) (**regra obrigatória de mapeamento cross-project**).
- **DpcInventario** (`DpcInventario/src/**`): Vue 3 / Vite — backend próprio (ApiInventario); não usa ApiDPC — ver [dpcInventario-arquitetura.md](.claude/docs/arquitetura/dpcInventario-arquitetura.md).
- **ApiNFE** (`ApiNFE/app/**`, `ApiNFE/routes/**`): **Lumen 10** / PHP 8.2 — API fiscal (SEFAZ, DANFE, Senig); Oracle + certificados digitais — ver [apinfe-convencoes.md](.claude/docs/regras/alterar-codigo/apinfe-convencoes.md). Resposta usa `mensagem` (não `msg`) e token vai em **query string**.

## Bugfix e nova feature
- Consultar o checklist do projeto alvo (`<projeto>-checklist-corrigir-bug.md` ou `-nova-feature.md`).
- Bugfix: reprodução → causa-raiz → menor mudança segura → validação de impacto colateral.
- Feature: validar arquitetura, contratos e impactos cross-project antes de propor mudanças estruturais.

## Tarefas
- Fluxo canônico: [tarefas.md](.claude/docs/regras/gerenciar-regras/tarefas.md) + commands `/importar-tarefa`, `/planejar-tarefa`, `/executar-tarefa`.
- Execução **nunca** faz push ou abre PR automaticamente e, por padrão, **nunca** commita. Exceções, todas restritas ao **fluxo multi-card Modo A** e feitas pelo orquestrador `/tarefa-completa` (não pela execução): (a) auto-commit por card ao montar a integração; (b) **correção em card cujo PR já foi aberto** → commit + push (atualiza o PR) + rebuild da integração, sem perguntar. A primeira abertura de PR e o primeiro push de branch nova seguem **a pedido** do usuário. Ver [tarefas.md §9](.claude/docs/regras/gerenciar-regras/tarefas.md) e [git-workflow-branches.md §8](.claude/docs/regras/gerenciar-regras/git-workflow-branches.md).
- Múltiplos cards do Trello na mesma chamada → o `/tarefa-completa` pergunta se são **separados (Modo A)** ou **mesclados (Modo B)** ([tarefas.md §9](.claude/docs/regras/gerenciar-regras/tarefas.md)).
- Quando o pedido for apenas planejamento ou documentação, não alterar código.

## Documentação
- Toda doc nova fica em `.claude/docs/`, em markdown, com recursos visuais (diagramas/tabelas/imagens) quando possível.
