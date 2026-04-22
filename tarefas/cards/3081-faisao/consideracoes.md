# Considerações — Cards #3081 + #3082 (Consolidadas)

## Entendimento Inicial

- **Projeto:** Faisão (React Native/Expo com TypeScript)
- **Tipo:** Melhorias de UI/UX + nova funcionalidade
- **Escopo:** 5 melhorias na tela de cliente + 1 nova funcionalidade (listagem de redes)
- **Cards:** #3081 (principal) + #3082 (continuação)
- **Branch:** `feature/3081-melhorias` (única)

## Requisitos da Tarefa Principal (#3081)

### 1. Ramo de Atividade — Tela Geral de Cliente

- Adicionar novo campo de exibição
- Local: aba "Geral" nas informações de cliente
- Deve buscar/exibir dados da API ou banco de dados existente

### 2. Complemento de Telefone — Tela Contato

- Exibir campos `fonecmpl1`, `fonecmpl2` abaixo de cada telefone
- Necessário validar se esses campos já existem no modelo de dados
- Pode exigir ajustes no layout para acomodar novos campos

### 3. Ícone em Vendedores

- Implementar padrão visual já existente em "Clientes"
- Definir qual ícone usar (reutilizar o mesmo?)
- Local: aba de vendedores

## Requisitos da Continuação (#3082)

### 4. Estilizar seqrede como link azul

- Campo `seqrede` (sequência de rede) na tela de cliente
- **Cor:** azul `#006aff`
- **Comportamento:** interativo, clicável
- Pode requerer ajuste em componente de texto ou campo dedicado

### 5. Nova tela de Rede do Cliente

- Modal/tela ao clicar em `seqrede`
- Integração com API: **POST** `/api/consultas/cliente/busca-rede` (ApiDPC)
- Exibir cada rede em um card com campos: Cód. Cliente, Nome, CNPJ, Atividade, Comercial, Prazo, UF

## Impactos Potenciais

- **Frontend (Faisão):** 
  - Telas: cliente (geral + contato), vendedores, nova tela de redes
  - Componentes: campo de texto, links, cards, modal/navegação

- **Backend (ApiDPC):** 
  - Validar endpoint `/api/consultas/cliente/busca-rede` (já existe)
  - Possível otimização ou ajuste de resposta

- **Cross-project:** 
  - Verificar contrato API com ApiDPC
  - Confirmar campos retornados pelo endpoint

## Ordem de Implementação (Sugerida)

1. Requisitos #1-3 (melhorias #3081)
2. Requisitos #4-5 (funcionalidade #3082)

Podem ser feitos em paralelo se não tiverem dependências.

## Dependências

- Confirmar campos disponíveis na API para cada tela
- Validar esquema de dados (caso tenha mudado recentemente)
- Revisar padrões de ícone e estilo visual do projeto
- Validar resposta da API `busca-rede` da ApiDPC

## Próximos Passos

1. Consultar convenções de código Faisão
2. Verificar arquitetura de dados e componentes existentes
3. Identificar arquivos a modificar (cross-project)
4. Validar integrações com ApiDPC
