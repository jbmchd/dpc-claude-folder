# Planejamento — Cards #3081 + #3082 (Consolidadas)

**Status:** Pendente de detalhamento técnico  
**Branch:** `feature/3081-melhorias` (única para ambas)

## Visão Geral

Implementar 5 melhorias de UI/UX + 1 nova funcionalidade no aplicativo Faisão:

### Tarefa Principal (#3081)
1. Adicionar Ramo de Atividade na aba Geral
2. Exibir complemento de telefone na aba Contato
3. Adicionar ícone na aba Vendedores

### Continuação (#3082)
4. Estilizar seqrede como link azul interativo
5. Nova tela de Rede do Cliente (integrada com API)

## Fases (será detalhado em `/planejar-tarefa`)

### Análise e Preparação
- [ ] **Fase 1:** Análise de arquitetura e convenções (Faisão)
- [ ] **Fase 1.5:** Validar contrato com ApiDPC (`busca-rede`)

### Implementação — Melhorias (#3081)
- [ ] **Fase 2:** Implementação da melhoria 1 (Ramo de Atividade)
- [ ] **Fase 3:** Implementação da melhoria 2 (Complemento de telefone)
- [ ] **Fase 4:** Implementação da melhoria 3 (Ícone em Vendedores)

### Implementação — Funcionalidade (#3082)
- [ ] **Fase 5:** Estilizar seqrede como link azul
- [ ] **Fase 6:** Criar tela/modal de Redes do Cliente
- [ ] **Fase 7:** Integrar navegação (cliente → redes)
- [ ] **Fase 8:** Integração com API `busca-rede`

### Finalização
- [ ] **Fase 9:** Testes e validação visual
- [ ] **Fase 10:** Verificação final cross-project

## Arquivos a Modificar (preliminar)

### Frontend (Faisão)
- `Faisao/src/screens/...` (telas de cliente, contatos, vendedores, redes)
- `Faisao/src/components/...` (componentes, ícones, links)
- `Faisao/src/api/...` ou `services/...` (chamada `busca-rede`)
- Possivelmente: modelos de dados, hooks, tipos TS

### Backend (ApiDPC)
- Validação do endpoint existente `/api/consultas/cliente/busca-rede`

## Validações Necessárias

- [ ] Dados estão disponíveis na API/banco (Ramo, Complemento)?
- [ ] Qual ícone usar para vendedores (reutilizar de Clientes)?
- [ ] Layout permite acomodar novos campos?
- [ ] Endpoint `busca-rede` retorna quais campos?
- [ ] Há paginação ou limite de registros na API?
- [ ] Impactos na ApiDPC?

## Branch

(será preenchido em `/planejar-tarefa` conforme `git-workflow-branches.md`)

---

**Próximo passo:** `/planejar-tarefa`
