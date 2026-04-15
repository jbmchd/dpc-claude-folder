# Conteúdo do Card #3064 - DPC EDI: Cadastro de Projetos

## Branch Sugerida
```
feature/3057-edi-cadastro-projetos
```

---

## Descrição e Requisitos

### 1. Erro ao clicar em coluna para ordenar
**Problema:** Ao clicar em uma coluna para ordenar, retorna um erro.

![Erro de ordenação 1](images/image_69dcd193f032496c736c5368.png)
![Erro de ordenação 2](images/image_69dcd1613881fe6983f0eaa9.png)

---

### 2. Modal Editar - Alinhamento e espaçamento
**Problema:** No modal Editar, os itens não estão alinhados e com espaço entre as bordas.

**Esperado:** Deixar igual ao exemplo abaixo.

![Modal atual desalinhado](images/image_69dccdd33061403c1c0f0e6a.png)

**Exemplo do esperado:**
![Modal alinhado (esperado)](images/image_69dcce1a476cfc94947eb604.png)

---

### 3. Alterar nomes dos inputs - Compatibilidade com Maracanã
**Problema:** Os nomes dos inputs na tela diferem do Maracanã, dificultando migração do usuário.

**Ação:** Alterar para ficar igual ao Maracanã.

**Exemplo:** O campo descrição no Maracanã está como "Projeto" → manter **Projeto** no DPC Aplicativos.

![Exemplo de campo no Maracanã](images/image_69dcd3c91e4b95f03000c534.png)

---

### 4. Alterar "Segmento" de input para select
**Problema:** Campo segmento é um input text, deveria ser select.

![Campo segmento atual](images/image_69dcd3de9de19c45931a3795.png)

**Ação:** Converter para `<select />` e movê-lo para ficar ao lado do **Cod. do projeto no parceiro**, como no Maracanã:

![Exemplo no Maracanã](images/image_69dcd4900f03b48cb59849e2.png)

---

### 5. Faltou botão "Nova" para cadastro de licenças
**Problema:** Não há botão para criar novas licenças.

![Tela atual sem botão](images/image_69dcd4d615e140f15346fad6.png)

**Esperado:** Incluir botão "Nova" como exemplo:
![Exemplo com botão Nova](images/image_69dcd921d72bb2d7056ab823.png)

---

### 6. Não exibir input "Cód. Projeto" no modal
**Ação:** Ocultar o campo **Cód. Projeto** no modal (Novo/Editar).

![Campo Cód. Projeto](images/image_69dcd8a783b20f92b5bfa8c2.png)

---

### 7. Gerar código de projeto automaticamente (Backend)
**Problema:** Usuário precisa digitar o código manualmente ao criar um projeto.

**Ação:** Alterar para gerar automaticamente no backend usando a sequence:
```sql
select dovemail.dpcs_edi_projeto_pk.nextval cod_projeto
from dual
```

**Exemplo de implementação:**
![Exemplo de geração automática](images/image_69dccfb9f7fa282c1f7f5c75.png)

---

### 8. Inclusão de pastas do projeto
**Problema:** Faltou implementar a parte de inclusão de pastas do projeto.

![Tela de inclusão de pastas](images/image_69dcd95bda30abc24c640c62.png)

---

### 9. Input "Repositório" faltando
**Problema:** Não há campo para Repositório.

![Campo Repositório esperado](images/image_69dcd989c1d51619c175ef70.png)

---

### 10. Alterar "Licença" para select
**Problema:** Campo Licença deveria ser um select como no Maracanã.

![Campo Licença como select](images/image_69dcd9fa13e6e70fb743285a.png)

---

### 11. Código do vendedor - Bloqueio condicional
**Problema:** Código do vendedor não é gerenciado corretamente.

**Ação:** 
- Deixar null quando segmento ≠ "COMISSÃO FIXA"
- Bloquear (disabled) quando segmento ≠ "COMISSÃO FIXA"

![Comportamento esperado 1](images/image_69dcda4d11e70817943bbf0f.png)
![Comportamento esperado 2](images/image_69dcda5a635d76487ed5dd29.png)

---

## Referência do Card
- **ID Trello:** 3064
- **URL:** https://trello.com/c/wNd2cKAg/3064-dpc-edi-cadastro-de-projetos
- **Atribuído a:** Joabe
- **Labels:** Correções, Erros
