# Sessão: Execução Continuada da Tarefa #3064 — Fase 2 (Repositório e Pastas)

**Data:** 2026-04-14  
**Tarefa:** #3064 - DPC EDI: Cadastro de Projetos (Correções)  
**Status:** Fase 1 ✅ concluída; Fase 2 🔄 planejamento atualizado com informações do banco

---

## Contexto

A tarefa #3064 é continuidade da tarefa #3057 (implementação do cadastro de projetos EDI). Esta sessão focou em:

1. **Execução completa da Fase 1** (5 items)
2. **Investigação do banco Oracle** para Fase 2 (items #8 e #9)
3. **Atualização do planejamento** com estrutura de dados confirmada

---

## Fase 1 — Concluída ✅

Todos os 5 items foram implementados:

### #1 — Bug na ordenação (Backend)
- **Arquivo:** `ApiDPC/app/DpcEdiProjeto.php:93`
- **Erro:** Variável `$coluna` undefined no `orderByRaw()`
- **Fix:** `$coluna` → `$params['orderBy'][0]['coluna']`

### #2 — Padding/alinhamento do modal
- **Arquivo:** `DPC/src/.../ModalSalvar.vue`
- **Fix:** Envolver slot body em `<div class="container-fluid">`

### #3 — Renomear labels
- `Descrição` → `Projeto`
- `Cód. Projeto Terceiro` → `Cod. do projeto no parceiro`

### #6 — Remover campo Cód. Projeto
- Removido input do template
- Removida validação de `!form.cod_projeto`

### #7 — Gerar cod_projeto via sequence
- **Backend:** `DpcEdiProjeto.php::store()` chama `dovemail.dpcs_edi_projeto_pk.nextval`
- **Frontend:** Campo removido do form inicial; backend retorna o código gerado
- **Novos endpoints:** 
  - `GET /ti/projetos-edi/segmentos` — retorna segmentos ativos de `consinco.mad_segmento`
  - `GET /ti/projetos-edi/licencas` — retorna licenças ativas de `dovemail.dpc_dm_licenca`

### #4, #10, #11 — Selects + bloqueio condicional
- `nrosegmento` → `<select>` com descrição de segmento (carregado em `mounted()`)
- `licenca` → `<select>` com licenças ativas
- `cod_vendedor` → `disabled` quando segmento ≠ "COMISSÃO FIXA" (computed `isSegmentoComissaoFixa` + watch)

---

## Investigação do Banco Oracle — Items #8 e #9

### Correção do MCP DPC
Houve erro no MCP anterior que não permitia buscas com schema qualificado. Agora funciona corretamente ao passar o schema:
- `dovemail.DPC_EDI_PROJETO` ✅
- `dovemail.DPC_EDI_REPOSITORIO` ✅
- Etc.

### Estrutura de Dados Descoberta

#### **Tabelas envolvidas** (todas em `dovemail`):

| Tabela | Descrição | Colunas PK |
|---|---|---|
| `DPC_EDI_PROJETO` | Projeto EDI | `COD_PROJETO` |
| `DPC_EDI_REPOSITORIO` | Definição do repositório FTP/SFTP | `COD_REPOSITORIO` |
| `DPC_EDI_REPOSITORIO_PROJETO` | **Liga projeto ao repositório** | `COD_REPOSITORIO_ARQUIVO` |
| `DPC_REPOSITORIO_PASTAS` | Liga repositório às pastas | `(COD_REPOSITORIO, COD_PASTA)` |
| `DPC_EDI_ARQUIVO_REPOSI_PASTA` | Detalhes/metadados da pasta | `COD_PASTA` |

#### **Fluxo de dados:**
```
DPC_EDI_PROJETO.COD_PROJETO
    ↓ (FK em DPC_EDI_REPOSITORIO_PROJETO)
DPC_EDI_REPOSITORIO_PROJETO.COD_REPOSITORIO
    ↓ (FK em DPC_REPOSITORIO_PASTAS)
DPC_REPOSITORIO_PASTAS.COD_PASTA
    ↓ (FK em DPC_EDI_ARQUIVO_REPOSI_PASTA)
DPC_EDI_ARQUIVO_REPOSI_PASTA (detalhes: CAMINHO, BACKUP, PEDIDO, RETORNO_*, etc.)
```

#### **Estrutura de `DPC_EDI_ARQUIVO_REPOSI_PASTA`:**
- `COD_PASTA` (PK)
- `CAMINHO` — path do FTP
- `BACKUP`, `PEDIDO`, `RETORNO_PEDIDO`, `RETORNO_CANCELAMENTO_PEDIDO`, `RETORNO_NF`, `RETORNO_XML`, `RETORNO_PEDIDO_ANALISE`, `SUPORTE` — flags booleanas (VARCHAR2, 1 char)
- `ATIVO` — flag VARCHAR2(1)

---

## Planejamento Atualizado

### Item #8 — Seção de Pastas

**Componente:** Grid de pastas do repositório selecionado  
**Carregamento:** Via `GET /ti/projetos-edi/{cod_repositorio}/pastas` após selecionar repositório  
**Colunas:** CAMINHO, BACKUP, PEDIDO, RETORNO_PEDIDO, RETORNO_CANCELAMENTO_PEDIDO, RETORNO_NF, RETORNO_XML, RETORNO_PEDIDO_ANALISE, SUPORTE, ATIVO (checkboxes)

**Endpoints a criar:**
- `GET /ti/projetos-edi/{cod_repositorio}/pastas` — JOIN de `dpc_repositorio_pastas` + `dpc_edi_arquivo_reposi_pasta`

### Item #9 — Campo Repositório

**Componente:** `<select>` de `DPC_EDI_REPOSITORIO`  
**Value:** `COD_REPOSITORIO`  
**Label:** `DESCRICAO`  
**Persistência:** Relação salva em `DPC_EDI_REPOSITORIO_PROJETO` via endpoint `POST /ti/projetos-edi/{cod_projeto}/repositorio`

**Endpoints a criar:**
- `GET /ti/projetos-edi/repositorios` — lista todos os repositórios ativos
- `GET /ti/projetos-edi/{cod_projeto}/repositorio` — retorna `COD_REPOSITORIO` vinculado ao projeto

---

## Mudanças no Backend (Resumo Estrutural)

### Novos models
- `DpcEdiRepositorioProjeto` — representa a ligação projeto-repositório

### Novos métodos em `TiProjetosEdiRepository`
- `repositorios()` — retorna lista de repositórios
- `repositorioDoProjeto($cod_projeto)` — retorna `COD_REPOSITORIO` do projeto
- `pastas($cod_repositorio)` — retorna array de pastas com detalhes
- `salvarRepositorioProjeto($cod_projeto, $cod_repositorio)` — INSERT ou UPDATE em `DPC_EDI_REPOSITORIO_PROJETO`

### Novos métodos no controller
- Delegação para o repository (padrão já usado em #4, #10, #11)

### Novas rotas
- `GET /ti/projetos-edi/repositorios`
- `GET /ti/projetos-edi/{id}/repositorio`
- `GET /ti/projetos-edi/{id}/pastas`
- `POST /ti/projetos-edi/{id}/repositorio/salvar`

---

## Mudanças no Frontend (Resumo Estrutural)

### `ModalSalvar.vue` — Fase 2

**Nova seção:** Select de Repositório (ao lado de Valor máximo bloqueio)
```vue
<select v-model="form.cod_repositorio" @change="buscarPastas()">
  <option v-for="rep in repositorios" :value="rep.cod_repositorio">
    {{ rep.descricao }}
  </option>
</select>
```

**Nova seção:** Grid de pastas (abaixo de Repositório, somente em edição ou após selecionar repositório)
```vue
<table v-if="pastas.length > 0">
  <tr v-for="pasta in pastas">
    <td>{{ pasta.caminho }}</td>
    <td><input type="checkbox" :checked="pasta.backup === 'S'" /></td>
    <!-- etc. -->
  </tr>
</table>
```

**Novos métodos:**
- `buscarRepositorios()` — chamado em `mounted()`
- `buscarRepositorioDoProjeto()` — chamado em `buscarProjeto()` (ao editar)
- `buscarPastas()` — chamado após trocar repositório

**Novos watchers:**
- `form.cod_repositorio` → chama `buscarPastas()`

---

## Arquivos Modificados (Resumo)

### ApiDPC
| Arquivo | Mudanças |
|---|---|
| `app/DpcEdiProjeto.php` | Fix #1 |
| `app/Repositories/TiProjetosEdiRepository.php` | Métodos para #7, #4, #10, #11 |
| `app/Http/Controllers/TiProjetosEdiController.php` | Delegação de métodos novos |
| `routes/api.php` | Novas rotas |

### DPC
| Arquivo | Mudanças |
|---|---|
| `ModalSalvar.vue` | Toda a Fase 1 + preparação para Fase 2 |

---

## Próximos Passos (Fase 2)

1. Implementar endpoints no ApiDPC para #8 e #9
2. Implementar select de Repositório e grid de Pastas no ModalSalvar.vue
3. Testar integração completa
4. Commit e push para o PR da tarefa #3057

---

## Notas Técnicas

### Memória Gravada
- ✅ `feedback_mcp_dpc_schemas.md` — MCP DPC acessa qualquer schema (consinco, poseidon, dovemail)
- ✅ `feedback_mcp_consultas.md` — Máx 2 tentativas antes de perguntar; schemas permitidos: consinco, poseidon, dovemail

### Hook Corrigido
- Hook `validate-protected-paths.py` foi atualizado para caminho absoluto em `.claude/settings.json` (estava relativo, bloqueava edições em ApiDPC)

### Padrões Mantidos
- API usa `dpcAxios.connection()`
- Resposta: `{ error, message, data }`
- Eventos `@buscar-dados` e `@close` preservados
- Validação de campos mantida em `verificaCampos()`

---

## Imagens de Referência

Todas as 17 imagens do Maracanã estão em `.claude/tarefas/cards/3064-dpc-edi-cadastro-de-projetos/images/`  
Especificamente para #8 e #9:
- `image_69dcd95bda30abc24c640c62.png` — Grid de pastas no Maracanã
- `image_69dcd989c1d51619c175ef70.png` — Campo Repositório no Maracanã
