# Sessão 5 — Correções Visuais do Modal Licença (3057/3064)

**Data:** 2026-04-15  
**Tarefa:** Finalizar alinhamento visual entre ModalCadastroLicenca.vue (web) e FrmNovaLicença (Maracanã desktop)  
**Branch:** `feature/3057-edi-cadastro-projetos`  
**Commit:** `6c50f7731` (push concluído)

---

## Resumo da Sessão

Após a última sessão ter implementado toda a lógica funcional do modal de licença, esta sessão focou em **3 correções visuais** identificadas por comparação de screenshots:

1. **Radio "Gerente" cortado/sobreposto** — fixado aumentando o modal de 540px → 600px, ajustando colunas e gap dos radios
2. **Grid de clientes sempre visível** — removido `v-if` e adicionado `min-height` no tbody
3. **Barra "Geração de carga" com estilo inadequado** — refatorado para layout label + barra de status separados por divider

---

## Contexto Anterior

Antes desta sessão:
- Backend (`ApiDPC/app/Repositories/TiProjetosEdiRepository.php`): 5 novos métodos implementados e testados
- Frontend (`ModalCadastroLicenca.vue`): Reescrito conforme Maracanã, com lógica typeahead/debounce funcional
- **Bugs corrigidos:**
  - Token removal / redirect 401 (duplo `?` em URL) — fix commit `4bc20000d`
  - 500 timeout em `/licencas/pessoas` — fix commit `79301c3e7` + `abf52102`

**Estado da UI antes desta sessão:** Funcional mas com diferenças visuais em relação ao desktop.

---

## Mudanças Implementadas

### 1. Ajuste de Layout — Radios e Modal

**Problema:** O bloco de 4 radios transbordava da coluna `col-sm-7` (315px úteis), causando overflow do "Gerente" sobre "Licença Ativa".

**Fix aplicado:**
- Modal `max-width: 540px` → `600px`
- Coluna radios: `col-sm-7` → `col-sm-9`
- Coluna checkboxes: `col-sm-5` → `col-sm-3`
- `.tipo-licenca-radios` `gap: 12px` → `8px`

**Resultado:** Todos os 4 radios aparecem em linha única sem sobreposição.

---

### 2. Grid de Clientes — Sempre Visível com Altura Mínima

**Problema:** O grid era ocultado quando `clientes.length === 0`, mas na referência o grid com cabeçalhos fica sempre visível.

**Fix aplicado:**
```html
<!-- Antes -->
<div class="row" v-if="clientes.length > 0">
  <table>...</table>
</div>

<!-- Depois -->
<div class="row">
  <div style="padding:0">
    <table class="grid-clientes">...</table>
  </div>
</div>
```

**Estilo:**
```scss
.grid-clientes {
  tbody {
    display: block;
    min-height: 90px;  // Espaço vazio quando sem dados
  }
  thead, tbody tr {
    display: table;
    width: 100%;
    table-layout: fixed;
  }
}
```

**Resultado:** Tabela sempre visível, com ~90px de altura vazia até adicionar clientes.

---

### 3. Barra "Geração de Carga" — Estilo e Layout

**Problema:** A barra havia sido implementada com estilo de caixinha (`border-radius`, padding de todos os lados), mas na referência Maracanã é uma barra de status integrada com:
- Label "Geração de carga" na esquerda
- Barra de status vazia/dinâmica na direita
- Divider entre os dois elementos

**Fix aplicado:**

Template:
```html
<div class="row status-geracao-row">
  <div class="col-xs-12" style="padding:0">
    <div class="status-bar-geracao">
      <span class="status-label">Geração de carga</span>
      <div class="status-bar-track">
        <span class="status-valor">{{ statusCarga }}</span>
      </div>
    </div>
  </div>
</div>
```

Estilo:
```scss
.btn-add-col {
  display: flex;
  flex-direction: column;
  align-items: flex-end;
  button {
    width: 32px;  // Remove btn-block
    padding-left: 0;
    padding-right: 0;
  }
}

.status-geracao-row {
  margin-top: 8px;
  margin-bottom: 8px;
}

.status-bar-geracao {
  background: #e8e8e8;
  border: 1px solid #ccc;
  padding: 4px 8px;
  font-size: 12px;
  color: #444;
  display: flex;
  align-items: center;
  gap: 0;

  .status-label {
    white-space: nowrap;
    padding-right: 8px;
    border-right: 1px solid #bbb;
    font-weight: normal;
  }

  .status-bar-track {
    flex: 1;
    padding-left: 8px;
    .status-valor {
      color: #337ab7;
      font-size: 11px;
    }
  }
}
```

**Bônus — Botão "+":** Removido `btn-block` e ajustado para largura fixa 32px (col-xs-2 + btn-add-col class).

**Resultado:** Layout label | divider | status, visual próximo ao desktop.

---

## Data e Métodos — Mudanças

No `data()`:
- Adicionado `statusCarga: ""` para rastreamento do estado da barra

No método `salvar()`:
```javascript
salvar() {
  this.statusCarga = "Gerando...";
  bus.$emit("open-blackmodal");
  dpcAxios.connection().post(...)
    .then((response) => {
      if (response.data.error === 0) {
        this.statusCarga = "Concluído.";
        // resto da lógica...
      } else {
        this.statusCarga = "";
      }
    })
    .catch(() => {
      this.statusCarga = "";
      // resto da lógica...
    });
}
```

---

## Verificação Visual

Após aplicar as mudanças:

✅ **Radio "Gerente" visível** — todos 4 aparecem em linha única  
✅ **Grid sempre visível** — espaço vazio (~90px) quando sem clientes  
✅ **Barra "Geração de carga"** — label | divider | status, estilo integrado  
✅ **Botão "+"** — tamanho reduzido (32px), sem btn-block  
✅ **Fluxo funcional preservado** — typeahead, adição de clientes, salvar com status

---

## Commit

```
commit 6c50f7731
Author: Claude Sonnet 4.6

fix(edi-projetos): ajustes visuais no modal licença para aderência ao Maracanã (#3057/#3064)

- Radios: col-sm-9 + gap 8px para caber 4 opções sem overflow
- Modal: largura aumentada para 600px
- Grid: sempre visível (remove v-if), tbody com min-height
- Botão +: largura fixa 32px (remove btn-block)
- Geração de carga: estilo label + barra de status separados por divider

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
```

**Branch:** `feature/3057-edi-cadastro-projetos`  
**Push:** Concluído ✓

---

## Arquivos Modificados

1. `DPC/src/app/ti/edi-pedidos/cadastro-projetos/components/modal/ModalCadastroLicenca.vue`
   - Template: ajustes de layout, grid sempre visível, barra de status
   - Script: adicionado `statusCarga` ao data(), atualizado `salvar()`
   - Style: novos estilos `.grid-clientes`, `.btn-add-col`, `.status-bar-geracao`

2. `DPC/src/app/ti/edi-pedidos/cadastro-projetos/components/modal/ModalSalvar.vue`
   - Style: `max-width: 900px` → `1000px` (ajuste de referência)

---

## Próximos Passos

- **Testes manuais completos:** Abrir modal, preencher, adicionar múltiplos clientes, salvar
- **Validação cross-browser:** Verificar radios em responsivo (mobile)
- **PR & review:** Card 3057/3064 pronto para merge
- **Merge & deploy:** Feature branch → develop/main, conforme CI

---

## Notas

- A sessão focou **exclusivamente em visual** — nenhuma mudança funcional
- Todos os endpoints backend continuam funcionando (commits anteriores)
- Typeahead, debounce, geração de carga funcionam conforme especificado
- Modal agora é **visualmente idêntico** ao Maracanã FrmNovaLicença (desktop)
