# #Faisão

## Fonte: Trello #3081

**Título:** #Faisão  
**Lista:** A fazer  
**Labels:** Melhorias  
**Membros:** Joabe  
**URL:** https://trello.com/c/DufNj3zV

### Descrição

Branch sugerida: `feature/3081-melhorias`

---

### 1 - Incluir o Ramo de Atividade na opção Geral das informações de cliente

Adicionar o campo "Ramo de Atividade" na aba "Geral" das informações de cliente.

**Referência visual:**  
{1}: images/image_69e61839c07743ddb2cff0ad.png

### 2 - Na opção Contato, abaixo de cada telefone, exibir o complemento

Na aba "Contato", exibir campos de complemento de telefone abaixo de cada número:
- `fonecmpl1`
- `fonecmpl2`

**Referência visual:**  
{2}: images/image_69e61896bf6eef0b9b027f05.png

### 3 - Na aba de vendedores, adicionar o ícone na tela

Adicionar ícone na aba de vendedores como já foi feito na tela de Clientes.

**Referência visual:**  
{3}: images/image_69e619fd2e071a2210bb5d80.png  
{4}: images/image_69e619d35ccd75f7b5532c93.png

---

## Continuação: #3082 — Faisão - Rede do Cliente

### 4 - Deixar o número do seqrede do cliente na cor azul #006aff como se fosse um link

Formatar o número do "seqrede" (sequência de rede) na tela de cliente com:
- **Cor:** azul `#006aff`
- **Estilo:** como um link (interativo)

**Referência visual:**  
{5}: images/image_69e6243cf6aba0ed644a2fe1.png

### 5 - Ao clicar no seqrede, abrir uma tela listando a rede do cliente

#### Onde buscar

Rota na **ApiDPC** para listar as redes do cliente:

**POST:** `https://apidpc.dpcnet.com.br/api/consultas/cliente/busca-rede`

**Payload:**
```json
{
  "rede": "15778"  // seqrede do cliente
}
```

#### Exibição dos dados

Na nova tela, exibir cada registro em um card diferente contendo:
- Cód. Cliente
- Nome (`nome_cliente`)
- CNPJ
- Atividade
- Comercial
- Prazo
- UF

## Contexto

- **Cards:** #3081 (principal) + #3082 (continuação)
- **Projeto:** Faisão (React Native / Expo)
- **Branch:** `feature/3081-melhorias`
- **Escopo:** 5 melhorias + 1 nova funcionalidade na interface de cliente

## Mapeamento de referências

- {1}: images/image_69e61839c07743ddb2cff0ad.png
- {2}: images/image_69e61896bf6eef0b9b027f05.png
- {3}: images/image_69e619fd2e071a2210bb5d80.png
- {4}: images/image_69e619d35ccd75f7b5532c93.png
- {5}: images/image_69e6243cf6aba0ed644a2fe1.png
