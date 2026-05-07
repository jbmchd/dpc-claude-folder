# /tarefa-completa

**Objetivo:** orquestrar o fluxo completo importar → classificar → planejar → executar, alternando modelos por fase e com pausa obrigatória para aprovação antes de alterar código.

**Entrada:** qualquer entrada válida para `/importar-tarefa` (link Trello, `#NNNN`, PDF, texto, etc.).

**Não faz:** pular a pausa de aprovação, commitar, fazer push ou abrir PR.

---

## Fluxo

### Fase 1 — Importar (Haiku)

Acionar `Agente Importar Tarefa` passando a entrada recebida.

- Se `{"status": "erro"}` → exibir motivo e **encerrar**. Orientar a corrigir e rodar `/tarefa-completa` ou `/importar-tarefa` manualmente.
- Se `{"status": "ok"}` → guardar `pasta` e avançar.

### Fase 2 — Classificar (Sonnet)

Acionar `Agente Classificar Tarefa` passando o caminho da pasta.

- Se `{"status": "erro"}` → exibir motivo e **encerrar**.
- Se `{"status": "ok"}` → guardar `complexidade` e `motivo`, avançar.

### Fase 3 — Planejar (Sonnet ou Opus)

Rotear conforme `complexidade`:

- `"simples"` → acionar `Agente Planejar Tarefa Sonnet`
- `"complexa"` → acionar `Agente Planejar Tarefa Opus`

Passar o caminho da pasta. Informar ao usuário qual modelo foi escolhido e o motivo da classificação antes de spawnar.

- Se `{"status": "erro"}` → exibir motivo e **encerrar**. Orientar a corrigir e rodar `/planejar-tarefa` manualmente.
- Se `{"status": "ok"}` → exibir o `resumo` e a **pausa de aprovação**.

### ⏸ Pausa obrigatória

Apresentar ao usuário:

```
Planejamento concluído. [Sonnet|Opus]

[resumo do agente-planejar]

Arquivo completo: <pasta>/planejamento.md

O que deseja fazer?
  1. Aprovar e executar
  2. Ajustar planejamento manualmente e rodar /executar-tarefa depois
  3. Cancelar
```

Aguardar resposta. **Não avançar sem confirmação explícita de opção 1.**

### Fase 4 — Executar (Sonnet) — somente se opção 1 aprovada

Acionar `Agente Executar Tarefa` passando o caminho da pasta.

- Se `{"status": "erro"}` → exibir motivo. Orientar a corrigir e rodar `/executar-tarefa` manualmente.
- Se `{"status": "ok"}` → exibir lista de arquivos alterados e próximos passos (testes manuais, PR, deploy).

---

**Encerramento:** independente da fase final, informar claramente onde o fluxo parou e o próximo passo recomendado.
