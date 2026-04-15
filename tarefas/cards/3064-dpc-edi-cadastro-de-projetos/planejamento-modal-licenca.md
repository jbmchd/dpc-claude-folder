# Planejamento – Modal de Cadastro de Licença (ModalCadastroLicenca.vue)

> Tarefa vinculada às demandas **#3057** e **#3064**  
> Branch: `feature/3057-edi-cadastro-projetos`  
> Referência Maracanã: `Telas/DoveMail/FrmNovaLicença.vb` + `FrmNovaLicença.Designer.vb` + `Dados/dalDM.vb` + `Dados/FuncDM.vb`

---

## Objetivo

Tornar o modal web `ModalCadastroLicenca.vue` uma cópia funcional do form desktop `FrmNovaLicença` do Maracanã — alinhando interface, fluxo de preenchimento e regras de negócio.

---

## Mapeamento de diferenças

| # | Elemento | Web (atual) | Maracanã (referência) | Ação |
|---|---|---|---|---|
| 1 | Radio buttons | 2 linhas (wrap) | 1 linha única | Forçar `flex-nowrap` |
| 2 | Campo Conexões | Visível e editável | `Visible = False` | Ocultar (manter no payload) |
| 3 | SeqPessoa + Nome/Razão + "+" | Ausente | `txtCodigo` + `cboPessoa` + `btnAdd` | Adicionar |
| 4 | DataGrid de clientes | Ausente | `dtgvLicençaClientes` (SeqPessoa / Nome) | Adicionar |
| 5 | Numero da Licença | Editável + obrigatório | Somente leitura (gerado automaticamente) | Tornar `readonly` |
| 6 | Carga sob demanda | Checkbox no corpo | Gerada no `btnSalvar_Click` (não é checkbox) | Remover seção do corpo |

---

## Fluxo de uso (novo)

```
1. Abrir modal
   └─ Tipo default: "Cliente"
   └─ Combo Nome/Razão carrega pessoas SEM licença do tipo CLI
      (view: dpcv_dmm_clientessemlicenca)

2. Trocar Tipo de Licença
   └─ Recarrega combo com pessoas sem licença do novo tipo
   └─ Limpa SeqPessoa, Nome/Razão, Numero da Licença e grid

3. Selecionar pessoa no combo
   └─ SeqPessoa (txtCodigo) preenche automaticamente
   └─ Numero da Licença gerado via GET /licencas/gerar-codigo
   └─ Botão "+" habilitado

   OU digitar código em SeqPessoa + Enter
   └─ Busca pessoa no array local pelo código
   └─ Se inválido: limpa campo

4. Clicar "+"
   ├─ [API] Verifica se cliente já tem licença do mesmo tipo (aviso se sim)
   ├─ Se grid VAZIO (primeira adição):
   │   └─ INSERT dpc_dm_licenca (licenca, status, conexoes, tipo, permitepedido)
   │   └─ INSERT dpc_dm_licenca_pessoa (licenca, codigo, tipo)
   │   └─ INSERT clientes em dpc_dm_licencacliente (por tipo — ver RN-03)
   │   └─ Recarrega grid via dpcv_dmm_licencasclientes
   └─ Se grid JÁ TEM linhas:
       └─ INSERT clientes adicionais em dpc_dm_licencacliente (mesmo por tipo)
       └─ Recarrega grid

5. Botão Salvar habilitado após grid ter ao menos 1 linha
   └─ [API] INSERT consinco.dpc_updt_licencas (trigger de carga)
   └─ Fecha modal + emite 'licenca-criada'
```

> **Nota sobre geração de carga:** no Maracanã, `btnSalvar_Click` faz INSERT em
> `consinco.dpc_updt_licencas` e chama `frmGeraCargaV3.GerarCargas(210, ...)` com
> controle de concorrência via `dpc_dmm_banco_comum`. No web, o INSERT em
> `dpc_updt_licencas` é executável na API; a chamada ao `GerarCargas` (processo
> complexo/assíncrono) fica fora de escopo desta entrega.

---

## Mapeamento completo de objetos de banco

### Tabelas de escrita

| Tabela | Operação | Colunas envolvidas | Quando |
|---|---|---|---|
| `dovemail.dpc_dm_licenca` | INSERT | `licenca, status, conexoes, tipo, permitepedido` | Primeiro "+" |
| `dovemail.dpc_dm_licenca_pessoa` | INSERT | `licenca, codigo, tipo` | Primeiro "+" |
| `dovemail.dpc_dm_licencacliente` | INSERT | `licenca, cod_cliente, status='L'` | Todo "+" (sem coluna `tipo`) |
| `consinco.dpc_updt_licencas` | INSERT | `id=25, licenca, versao` | Salvar (trigger de carga) |

### Tabelas de leitura (rollback / delete)

| Tabela | Operação | Quando |
|---|---|---|
| `dovemail.dpc_dm_licenca` | DELETE | Rollback (fechar sem salvar / trocar tipo) |
| `dovemail.dpc_dm_licenca_pessoa` | DELETE | Rollback |
| `dovemail.dpc_dm_licencacliente` | DELETE | Rollback |

### Views de leitura

| View | Uso | Colunas relevantes |
|---|---|---|
| `dpcv_dmm_clientessemlicenca` | Pessoas sem licença — tipo CLI | `cod_cliente, nome` |
| `dpcv_dmm_rcasemlicenca` | Pessoas sem licença — tipo RCA | `cod_repres, nome` |
| `dpcv_dmm_supsemlicenca` | Pessoas sem licença — tipo SUP | `codigo, nome` |
| `dpcv_dmm_gersemlicenca` | Pessoas sem licença — tipo GER | `codigo, nome` |
| `dpcv_dmm_licencasclientes` | Grid de clientes associados + check duplicidade | `licenca, cod_cliente, nome, tipo, statuslicencacliente` |
| `dpcv_dmm_licencaspessoas` | Leitura de pessoa associada à licença | `licenca, codigo, nome, tipo, status` |

### Tabela auxiliar para inclusão de clientes (RCA/SUP/GER)

| Tabela | Filtro por tipo | Coluna usada |
|---|---|---|
| `DPC_DM_CLI_RCA_COOR_GER` | RCA | `cod_repres` |
| `DPC_DM_CLI_RCA_COOR_GER` | SUP | `cod_coordenador` |
| `DPC_DM_CLI_RCA_COOR_GER` | GER | `cod_gerente` |

### Tabela auxiliar para versão da carga

| Tabela | Uso |
|---|---|
| `consinco.dpc_updt_versoes` | `SELECT MAX(versao) WHERE id = 25` — usado no INSERT de `dpc_updt_licencas` |

### Tabelas de log (fora do escopo de criação)

| Tabela | Quando é usada |
|---|---|
| `dpc_dm_licenca_log` | Apenas em UPDATE de `dpc_dm_licenca` (não em INSERT) |
| `dpc_dm_licenca_log_motivos` | Apenas em UPDATE com motivo informado |
| `dpc_dm_licencacliente_log` | Apenas em DELETE de `dpc_dm_licencacliente` |
| `dpc_dm_licencacliente_log_mtv` | Apenas em DELETE com motivo informado |

> As tabelas de log **não são tocadas** no fluxo de criação — apenas em edição/remoção.

---

## Interface — mudanças no template

### 1. Radio buttons em linha única

```html
<!-- ANTES -->
<div class="tipo-licenca-radios"> ... </div>

<!-- DEPOIS -->
<div class="tipo-licenca-radios tipo-licenca-radios--nowrap"> ... </div>
```

```scss
.tipo-licenca-radios--nowrap {
  display: flex;
  flex-wrap: nowrap;
  gap: 12px;
}
```

### 2. Ocultar campo Conexões

Remover o bloco `<!-- CONEXÕES -->` do template.  
Manter `conexoes: 1` em `data.form` (enviado ao API sem exibição).

### 3. Adicionar SeqPessoa + Nome/Razão + botão "+"

```html
<div class="row">
  <div class="form-group col-xs-3 col-sm-2">
    <label>{{ labelCodigo }}</label>
    <input type="text" class="form-control input-sm"
           v-model="form.cod_pessoa"
           @keydown.enter="selecionarPorCodigo" />
  </div>
  <div class="form-group col-xs-7 col-sm-8">
    <label>Nome/Razão</label>
    <select class="form-control input-sm"
            v-model="form.cod_pessoa"
            @change="onPessoaSelecionada">
      <option v-for="p in pessoas" :key="p.codigo" :value="p.codigo">
        {{ p.nome }}
      </option>
    </select>
  </div>
  <div class="form-group col-xs-2">
    <label>&nbsp;</label>
    <button class="btn btn-default btn-sm btn-block"
            :disabled="!btnAddHabilitado"
            @click="adicionarPessoa">+</button>
  </div>
</div>
```

**`labelCodigo`** (computed):
| Tipo | Label |
|---|---|
| CLI | "SeqPessoa" |
| RCA | "Cod RCA" |
| SUP | "SeqPessoa" |
| GER | "SeqPessoa" |

### 4. DataGrid de clientes

Fonte: view `dpcv_dmm_licencasclientes` filtrada por `licenca`.

```html
<div class="row" v-if="clientes.length > 0">
  <div class="col-xs-12">
    <table class="table table-condensed table-bordered">
      <thead>
        <tr><th>SeqPessoa</th><th>Nome</th></tr>
      </thead>
      <tbody>
        <tr v-for="c in clientes" :key="c.cod_cliente">
          <td>{{ c.cod_cliente }}</td>
          <td>{{ c.nome }}</td>
        </tr>
      </tbody>
    </table>
  </div>
</div>
```

### 5. Numero da Licença — somente leitura

```html
<!-- ANTES -->
<label>Numero da Licença <span class="text-danger">*</span></label>
<input type="text" v-model="form.licenca" placeholder="Código da licença" />

<!-- DEPOIS -->
<label>Numero da Licença</label>
<input type="text" class="form-control input-sm" :value="form.licenca" readonly />
```

### 6. Remover seção "Geração de carga"

Remover bloco `<!-- GERAÇÃO DE CARGA -->` inteiro.  
Manter `carga_sob_demanda: 'S'` fixo em `data.form`.

### 7. Botão Salvar — condicional

```html
<button class="btn btn-success" :disabled="clientes.length === 0" @click="salvar()">
  <i class="fa fa-save"></i> Salvar
</button>
```

---

## Estado do componente (data)

```js
data() {
  return {
    licencaAtiva: true,
    form: {
      licenca: null,            // gerado automaticamente, readonly
      tipo: 'CLI',
      conexoes: 1,              // fixo, não exibido
      permitepedido: 'S',
      carga_sob_demanda: 'S',   // fixo, não exibido
      cod_pessoa: null,
    },
    pessoas: [],                // carregado por tipo via API
    clientes: [],               // grid — lido de dpcv_dmm_licencasclientes
    btnAddHabilitado: false,
    licencaSalva: false,        // true após primeiro "+" com sucesso
  };
},
```

---

## Regras de negócio

### RN-01 — Carregamento de pessoas por tipo

Ao montar e ao trocar `form.tipo`, chamar `GET /ti/projetos-edi/licencas/pessoas?tipo=<tipo>`.  
Popula `this.pessoas`. Limpa `form.cod_pessoa`, `form.licenca`, `clientes`.

**Queries Oracle por tipo** (baseadas em `dalDM.vb`):

| Tipo | View | Alias retornado |
|---|---|---|
| CLI | `SELECT cod_cliente AS codigo, nome FROM dpcv_dmm_clientessemlicenca` | `codigo, nome` |
| RCA | `SELECT cod_repres AS codigo, nome FROM dpcv_dmm_rcasemlicenca` | `codigo, nome` |
| SUP | `SELECT codigo, nome FROM dpcv_dmm_supsemlicenca` | `codigo, nome` |
| GER | `SELECT codigo, nome FROM dpcv_dmm_gersemlicenca` | `codigo, nome` |

### RN-02 — Geração do código de licença

Quando pessoa é selecionada **e grid está vazio**, chamar `GET /ti/projetos-edi/licencas/gerar-codigo?cod_pessoa=<cod>`.

**Algoritmo** (`FuncDM.vb:19` — `GeraLicença`):
```
Para cada dígito D do código da pessoa:
    char = chr(65 + intval(D))   → '1'→'B', '2'→'C', '3'→'D', ...
Concatenar chars → Base (tamanho = qtd dígitos do código)
Gerar string aleatória de dígitos com len = 10 - len(Base)
Licença = Base + random_pad  (total: 10 chars)
```
Exemplo: código `123` → Base `BCD` + 7 dígitos aleatórios.

O backend verifica unicidade em `dpc_dm_licenca`; se colisão, gera novo código.  
Se grid já tem linhas (`licencaSalva = true`), não regera o código.

### RN-03 — Ação do botão "+"

**Fonte: `FrmNovaLicença.vb:21-137` e `dalDM.vb`**

**Pré-check — cliente duplicado:**  
Antes de inserir, verificar na view `dpcv_dmm_licencasclientes` se já existe registro com `cod_cliente = ? AND tipo = ?`.  
Se existir: retornar aviso ao frontend ("Esse cliente já está cadastrado a outra licença. Deseja cadastrá-lo assim mesmo?").  
O frontend exibe confirmação; se o usuário aceitar, o backend prossegue.

**Payload:** `{ licenca, tipo, cod_pessoa, permitepedido, status, conexoes, bloqueada, carga_sob_demanda, forcar_duplicidade }`

**Lógica backend — `adicionarPessoa($params)`:**

```
SE licença NÃO existe em dpc_dm_licenca:
    INSERT dpc_dm_licenca (licenca, status, conexoes, tipo, permitepedido)
    INSERT dpc_dm_licenca_pessoa (licenca, codigo=cod_pessoa, tipo)

SEMPRE:
    SE tipo = CLI:
        INSERT dpc_dm_licencacliente (licenca, cod_cliente=cod_pessoa, status='L')

    SE tipo = RCA:
        INSERT INTO dpc_dm_licencacliente
            SELECT DISTINCT :licenca, x.cod_cliente, 'L'
            FROM DPC_DM_CLI_RCA_COOR_GER x
            WHERE x.cod_repres = :cod_pessoa

    SE tipo = SUP:
        INSERT INTO dpc_dm_licencacliente
            SELECT DISTINCT :licenca, x.cod_cliente, 'L'
            FROM DPC_DM_CLI_RCA_COOR_GER x
            WHERE x.cod_coordenador = :cod_pessoa

    SE tipo = GER:
        INSERT INTO dpc_dm_licencacliente
            SELECT DISTINCT :licenca, x.cod_cliente, 'L'
            FROM DPC_DM_CLI_RCA_COOR_GER x
            WHERE x.cod_gerente = :cod_pessoa

RETORNAR: SELECT cod_cliente, nome FROM dpcv_dmm_licencasclientes WHERE licenca = :licenca
```

> **`dpc_dm_licencacliente` não tem coluna `tipo`** — o tipo só é gravado em `dpc_dm_licenca_pessoa`.

**Frontend após sucesso:**
- Preenche `this.clientes` com o array retornado
- `this.licencaSalva = true`
- Limpa `form.cod_pessoa`
- Recarrega `this.pessoas` (sem licença) para refletir nova situação

### RN-04 — Unicidade da licença

Backend valida `SELECT licenca FROM dpc_dm_licenca WHERE licenca = ?` antes do INSERT.  
Se já existir: retornar `error: 1, message: 'Já existe uma licença com este código.'`.

### RN-05 — Botão Salvar

Habilitado apenas quando `clientes.length > 0`.

**Ao clicar, o backend executa:**
```sql
INSERT INTO consinco.dpc_updt_licencas (id, licenca, versao)
VALUES (
    25,
    :licenca,
    (SELECT MAX(versao) FROM consinco.dpc_updt_versoes WHERE id = 25)
)
```

Após sucesso: frontend fecha o modal e emite `licenca-criada` com `this.form.licenca`.

> A chamada ao `frmGeraCargaV3.GerarCargas(210, ...)` e o controle de concorrência via
> `dpc_dmm_banco_comum` estão fora do escopo desta entrega. O INSERT em
> `dpc_updt_licencas` é suficiente para marcar a licença para geração futura.

### RN-06 — Reset ao trocar tipo com grid preenchido

Quando `form.tipo` muda **e `licencaSalva = true`**:
- Frontend exibe confirmação: "Trocar o tipo irá desfazer os dados preenchidos. Continuar?"
- Se confirmar: `DELETE /ti/projetos-edi/licencas/:licenca` (rollback nas 3 tabelas) → reset local
- Se cancelar: reverter o radio para o tipo anterior

Se `licencaSalva = false` (grid vazio), troca de tipo sem confirmação.

### RN-07 — Fechar modal sem Salvar com dados persistidos

Se `licencaSalva = true` e o usuário fechar o modal (botão X ou `@close`):
- Frontend chama `DELETE /ti/projetos-edi/licencas/:licenca`
- Backend executa em ordem:
  1. `DELETE FROM dpc_dm_licencacliente WHERE licenca = :lic`
  2. `DELETE FROM dpc_dm_licenca_pessoa WHERE licenca = :lic`
  3. `DELETE FROM dpc_dm_licenca WHERE licenca = :lic`
- Emitir `close` sem emitir `licenca-criada`

> Não grava nas tabelas de log (`dpc_dm_licencacliente_log`, `dpc_dm_licenca_log`) — essas
> só são usadas em operações de edição/exclusão via tela de gestão, não em rollback de criação.

---

## Novos endpoints necessários (ApiDPC)

| Método | Rota | Método Controller | Método Repository |
|---|---|---|---|
| `GET` | `/ti/projetos-edi/licencas/pessoas` | `pessoasSemLicenca` | `pessoasSemLicenca($tipo)` |
| `GET` | `/ti/projetos-edi/licencas/gerar-codigo` | `gerarCodigoLicenca` | `gerarCodigoLicenca($cod_pessoa)` |
| `POST` | `/ti/projetos-edi/licencas/adicionar-pessoa` | `adicionarPessoa` | `adicionarPessoa($params)` |
| `POST` | `/ti/projetos-edi/licencas/gerar-carga` | `gerarCargaLicenca` | `gerarCargaLicenca($licenca)` |
| `DELETE` | `/ti/projetos-edi/licencas/{licenca}` | `excluirLicenca` | `excluirLicenca($licenca)` |

> Endpoint `GET /licencas/{licenca}/clientes` não precisa ser criado separadamente —
> `adicionarPessoa` já retorna a lista atualizada. Se necessário recarregar sem
> chamar "+", consultar `dpcv_dmm_licencasclientes` diretamente.

> Os endpoints existentes (`POST /licencas/salvar`, `GET /licencas`) **permanecem inalterados**.

---

## Passos de execução

### ApiDPC

- [ ] Adicionar `pessoasSemLicenca($tipo)` em `TiProjetosEdiRepository`
- [ ] Adicionar `gerarCodigoLicenca($cod_pessoa)` em `TiProjetosEdiRepository` (algoritmo VB portado para PHP)
- [ ] Adicionar `adicionarPessoa($params)` em `TiProjetosEdiRepository` (lógica 3 tabelas + `DPC_DM_CLI_RCA_COOR_GER`)
- [ ] Adicionar `gerarCargaLicenca($licenca)` em `TiProjetosEdiRepository` (INSERT em `consinco.dpc_updt_licencas`)
- [ ] Adicionar `excluirLicenca($licenca)` em `TiProjetosEdiRepository` (DELETE nas 3 tabelas em ordem)
- [ ] Adicionar métodos correspondentes em `TiProjetosEdiController`
- [ ] Registrar novas rotas em `routes/api.php`

### DPC (ModalCadastroLicenca.vue)

- [ ] Radios: adicionar classe `nowrap` + CSS `flex-wrap: nowrap`
- [ ] Remover bloco `<!-- CONEXÕES -->` do template
- [ ] Adicionar row SeqPessoa + combo Nome/Razão + botão "+"
- [ ] Adicionar tabela de clientes (visível quando `clientes.length > 0`)
- [ ] Tornar "Numero da Licença" `readonly`, remover asterisco e placeholder
- [ ] Remover bloco `<!-- GERAÇÃO DE CARGA -->` do template
- [ ] Atualizar `data()`: adicionar `pessoas`, `clientes`, `licencaSalva`, `btnAddHabilitado`
- [ ] Implementar computed `labelCodigo` por tipo
- [ ] Implementar `watch` em `form.tipo` → `carregarPessoas()` + reset (com confirmação se `licencaSalva`)
- [ ] Implementar `onPessoaSelecionada()` → chamar `gerarCodigo()` se `!licencaSalva`
- [ ] Implementar `selecionarPorCodigo()` → buscar em `this.pessoas` por código (keydown Enter)
- [ ] Implementar `adicionarPessoa()` → POST + tratar aviso de duplicidade + reload grid
- [ ] Implementar rollback ao fechar modal com `licencaSalva = true` (RN-07)
- [ ] Desabilitar botão Salvar quando `clientes.length === 0`
- [ ] Atualizar `salvar()` → POST gerar-carga + fechar + emitir `licenca-criada`

### Validação

- [ ] Selecionar tipo CLI → combo carrega clientes sem licença
- [ ] Selecionar tipo RCA/SUP/GER → label SeqPessoa muda corretamente
- [ ] Selecionar pessoa → SeqPessoa preenche + licença gerada automaticamente
- [ ] Clicar "+" com grid vazio → salva licença, associa pessoa, popula grid
- [ ] Clicar "+" com grid não vazio → acrescenta clientes sem recriar licença
- [ ] Cliente já vinculado a outra licença → aviso de confirmação exibido
- [ ] Trocar tipo com `licencaSalva=true` → confirmação + rollback no backend
- [ ] Fechar modal com `licencaSalva=true` sem Salvar → rollback automático
- [ ] Campo Conexões não aparece na tela
- [ ] Campo Carga sob demanda não aparece na tela
- [ ] Numero da Licença é `readonly`
- [ ] Botão Salvar desabilitado enquanto `clientes.length === 0`
- [ ] Clicar Salvar → INSERT em `consinco.dpc_updt_licencas` + modal fecha + evento emitido

---

## Arquivos afetados

| Arquivo | Tipo de mudança |
|---|---|
| `DPC/src/app/ti/edi-pedidos/cadastro-projetos/components/modal/ModalCadastroLicenca.vue` | Modificar |
| `ApiDPC/app/Repositories/TiProjetosEdiRepository.php` | Modificar (adicionar 5 métodos) |
| `ApiDPC/app/Http/Controllers/TiProjetosEdiController.php` | Modificar (adicionar 5 métodos) |
| `ApiDPC/routes/api.php` | Modificar (adicionar 5 rotas) |
