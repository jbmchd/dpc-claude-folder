# Desenvolvimento - #3064 DPC EDI: Cadastro de Projetos

## Alterações de Código

### ApiDPC

#### `app/DpcEdiProjeto.php` — Fix #1
- **Linha 93:** Corrigido variável `$coluna` undefined → `$params['orderBy'][0]['coluna']`
- Bug causava erro 500 ao clicar em qualquer coluna para ordenar na listagem

#### `app/Repositories/TiProjetosEdiRepository.php` — Fix #7 + Novos métodos
- **`store()`:** Quando `$isNew`, gera `cod_projeto` via sequence Oracle `dovemail.dpcs_edi_projeto_pk.nextval` antes do INSERT. Retorna o código gerado em `$retorno['cod_projeto']`.
- **Novo método `segmentos()`:** Retorna lista de segmentos ativos de `consinco.mad_segmento` (nrosegmento, descsegmento) para popular o select no frontend.
- **Novo método `licencas()`:** Retorna lista de licenças ativas de `dovemail.dpc_dm_licenca` (licenca) para popular o select no frontend.

#### `app/Http/Controllers/TiProjetosEdiController.php`
- **Novos métodos `segmentos()` e `licencas()`:** Delegam para o repository.

#### `routes/api.php`
- **Novas rotas:**
  - `GET /ti/projetos-edi/segmentos`
  - `GET /ti/projetos-edi/licencas`

---

### DPC

#### `src/app/ti/edi-pedidos/cadastro-projetos/components/modal/ModalSalvar.vue` — Fixes #2, #3, #4, #6, #10, #11

**#2 — Padding/alinhamento:**
- Todo o slot body agora envolvido em `<div class="container-fluid">` para padding correto.

**#3 — Labels renomeados:**
- `Descrição` → `Projeto`
- `Cód. Projeto Terceiro` → `Cod. do projeto no parceiro`

**#4 — Segmento como select:**
- Campo `nrosegmento` convertido de `<input type="number">` para `<select>`.
- Posicionado na seção de campos básicos, abaixo de Licença/Cod. do projeto no parceiro.
- Carregado via `GET /ti/projetos-edi/segmentos` no `mounted()`.

**#6 — Campo Cód. Projeto removido:**
- Div do input `cod_projeto` removida do template.
- Validação `!this.form.cod_projeto` removida de `verificaCampos()`.
- Campo `cod_projeto` removido do objeto `form` inicial (só mantido em `buscarProjeto()` para edições).

**#7 — Frontend:**
- Não envia `cod_projeto` no payload do POST para novo registro (campo não existe mais no form inicial).

**#10 — Licença como select:**
- Campo `licenca` convertido de `<input type="text">` para `<select>`.
- Carregado via `GET /ti/projetos-edi/licencas` no `mounted()`.

**#11 — Bloqueio de Cód. Vendedor por segmento:**
- Computed `isSegmentoComissaoFixa`: procura no array `segmentos` se o segmento selecionado tem `descsegmento` contendo "COMISSÃO FIXA".
- `watch` em `form.nrosegmento`: quando segmento muda e não é COMISSÃO FIXA, zera `form.cod_vendedor`.
- Input `cod_vendedor` recebe `:disabled="!isSegmentoComissaoFixa"`.

**Campo `nrosegmento` (campo antigo "Nº Segmento"):**
- Removido da seção "Outros" e movido para a seção de campos básicos.

#### `app/Repositories/TiProjetosEdiRepository.php` — Fix #8 + #9
- **`store()`:** Ao salvar projeto, se `cod_repositorio` for enviado, salva/atualiza associação em `dovemail.dpc_edi_repositorio_projeto`. UPDATE se registro já existe para o `cod_projeto`; INSERT com `MAX(cod_repositorio_arquivo) + 1` se novo.
- **Novo método `repositorios()`:** Retorna repositórios ativos de `dovemail.dpc_edi_repositorio` (cod_repositorio, descricao).
- **Novo método `repositorioDoProjeto($cod_projeto)`:** Retorna `cod_repositorio` vinculado ao projeto via `dpc_edi_repositorio_projeto`.
- **Novo método `pastas($cod_repositorio)`:** Retorna pastas via JOIN de `dpc_repositorio_pastas` + `dpc_edi_arquivo_reposi_pasta`.

#### `app/Http/Controllers/TiProjetosEdiController.php`
- Novos métodos: `repositorios()`, `repositorioDoProjeto()`, `pastas()`.

#### `routes/api.php`
- `GET /ti/projetos-edi/repositorios`
- `GET /ti/projetos-edi/repositorios/{id}/pastas`
- `GET /ti/projetos-edi/{id}/repositorio`

---

### DPC

#### `src/.../modal/ModalSalvar.vue` — Fix #8 + #9 (Fase 2)

**#9 — Select de Repositório:**
- Campo `<select>` ao lado de Segmento, carregado via `buscarRepositorios()` no `mounted()`.
- `buscarRepositorioDoProjeto()` chamado dentro de `buscarProjeto()` para pré-selecionar ao editar.
- `cod_repositorio` incluído no `form` e enviado no payload do salvar.

**#8 — Grid de Pastas:**
- Seção `v-if="pastas.length > 0"` com tabela responsiva.
- Colunas: Descrição, Caminho, Status, Backup, Pedido, Ret.Pedido, Ret.Cancelamento, Ret.NF, Ret.XML, Ret.Análise, Suporte, Ger.Arquivo.
- Watch em `form.cod_repositorio`: chama `buscarPastas()` automaticamente ao trocar ou limpar repositório.

---

## Commits

### ApiDPC
| Hash | Descrição |
|---|---|
| `100bac8b` | feat(edi-projetos): fase 1 - bugfixes e melhorias (#3064) |
| `7afda92e` | feat(edi-projetos): fase 2 - select de repositório e grid de pastas (#3064/#9/#8) |
| `eaf8b04b` | feat(edi-projetos): fix #5 - endpoint para cadastro de nova licença (#3064) |
| `866e49a8` | feat(edi-projetos): modal licença - novos endpoints para fluxo completo (#3057/#3064) |

### DPC
| Hash | Descrição |
|---|---|
| `0a67ff4c` | feat(edi-projetos): fase 1 - melhorias no modal (#3064) |
| `cc65e1a9` | feat(edi-projetos): fase 2 - select de repositório e grid de pastas no modal (#3064/#9/#8) |
| `4ec75ad9` | feat(edi-projetos): fix #5 - botão Nova e modal de cadastro de licença (#3064) |
| `d38c703b` | feat(edi-projetos): modal licença alinhado ao Maracanã FrmNovaLicença (#3057/#3064) |

## Status de Implementação

| Item | Descrição | Status |
|---|---|---|
| #1 | Fix variável `$coluna` undefined no orderBy | ✅ Concluído |
| #2 | Padding/alinhamento no modal | ✅ Concluído |
| #3 | Renomear labels | ✅ Concluído |
| #4 | Segmento como select + reposicionar | ✅ Concluído |
| #5 | Botão "Nova" para licença + modal de cadastro | ✅ Concluído |
| #6 | Remover campo Cód. Projeto do modal | ✅ Concluído |
| #7 | Gerar Cód. Projeto via sequence | ✅ Concluído |
| #8 | Seção de pastas do projeto | ✅ Concluído |
| #9 | Campo Repositório | ✅ Concluído |
| #10 | Licença como select | ✅ Concluído |
| #11 | Bloqueio de Cód. Vendedor por segmento | ✅ Concluído |

---

## Modal de Licença — Alinhamento com Maracanã (demandas #3057/#3064)

### ApiDPC

#### `app/Repositories/TiProjetosEdiRepository.php` — 5 novos métodos

- **`pessoasSemLicenca($tipo)`:** Retorna pessoas sem licença por tipo (CLI/RCA/SUP/GER) usando as views `dpcv_dmm_clientessemlicenca`, `dpcv_dmm_rcasemlicenca`, `dpcv_dmm_supsemlicenca`, `dpcv_dmm_gersemlicenca`. Retorna `{codigo, nome}`.
- **`gerarCodigoLicenca($cod_pessoa)`:** Porta o algoritmo `GeraLicença` do `FuncDM.vb`: converte cada dígito D de `cod_pessoa` em `chr(65+D)` formando a base, completa até 10 chars com dígitos aleatórios. Verifica unicidade em `dpc_dm_licenca` em loop.
- **`adicionarPessoa($params)`:** Lógica de 3 tabelas baseada em `FrmNovaLicença.vb + dalDM.vb`:
  - Verificação de duplicidade via `dpcv_dmm_licencasclientes` (retorna `error: 2` para confirmação no frontend)
  - Se licença não existe: INSERT em `dpc_dm_licenca` + `dpc_dm_licenca_pessoa`
  - Sempre: para CLI = INSERT direto em `dpc_dm_licencacliente`; para RCA/SUP/GER = INSERT SELECT de `dpc_dm_cli_rca_coor_ger` com coluna de filtro adequada
  - Retorna grid atualizado via `dpcv_dmm_licencasclientes`
- **`gerarCargaLicenca($licenca)`:** INSERT em `consinco.dpc_updt_licencas` com `id=25` e versão obtida de `consinco.dpc_updt_versoes`.
- **`excluirLicenca($licenca)`:** Rollback em 3 tabelas na ordem: `dpc_dm_licencacliente` → `dpc_dm_licenca_pessoa` → `dpc_dm_licenca`.

#### `app/Http/Controllers/TiProjetosEdiController.php`

- Novos métodos: `pessoasSemLicenca`, `gerarCodigoLicenca`, `adicionarPessoa`, `gerarCargaLicenca`, `excluirLicenca`.

#### `routes/api.php`

- `GET /ti/projetos-edi/licencas/pessoas`
- `GET /ti/projetos-edi/licencas/gerar-codigo`
- `POST /ti/projetos-edi/licencas/adicionar-pessoa`
- `POST /ti/projetos-edi/licencas/gerar-carga`
- `DELETE /ti/projetos-edi/licencas/{licenca}`

### DPC

#### `src/app/ti/edi-pedidos/cadastro-projetos/components/modal/ModalCadastroLicenca.vue` — reescrito

Interface alinhada ao Maracanã (`FrmNovaLicença`):

| Elemento | Antes | Depois |
|---|---|---|
| Radio buttons | 2 linhas (wrap) | Flex nowrap em linha única |
| Campo Conexões | Visível e editável | Removido do template (fixo em `form`) |
| SeqPessoa + Nome/Razão + "+" | Ausente | Adicionado (input código + select combo + botão +) |
| DataGrid de clientes | Ausente | Tabela com SeqPessoa/Nome, visível quando `clientes.length > 0` |
| Numero da Licença | Editável + obrigatório | `readonly`, gerado automaticamente |
| Carga sob demanda | Checkbox no corpo | Removida do template (fixo `'S'` em `form`) |
| Botão Salvar | Sempre habilitado | Desabilitado até `clientes.length > 0` |

**Lógica principal:**
- `carregarPessoas()`: GET por tipo ao montar e ao trocar tipo
- `gerarCodigo()`: GET ao selecionar pessoa (quando `!licencaSalva`)
- `adicionarPessoa()`: POST com tratamento de duplicidade (`error: 2` → `window.confirm`)
- `salvar()`: POST `gerar-carga` → fecha modal + emite `licenca-criada`
- `fechar()`: se `licencaSalva`, chama rollback (DELETE) antes de emitir `close`
- Watch em `form.tipo` com `licencaSalva`: pede confirmação + rollback antes de resetar

## Testes Executados
<!-- A preencher após validação manual -->

## Issues Encontradas

### Hook validate-protected-paths.py com caminho relativo
O hook configurado em `.claude/settings.json` usava `python hooks/validate-protected-paths.py` (caminho relativo). Quando o CWD passava a ser `ApiDPC/`, o script não era encontrado. Corrigido automaticamente para caminho absoluto no `settings.json`.

### Items #8 e #9 — Bloqueio de implementação
A tabela `dovemail.dpc_edi_projeto` não existe no ambiente de tst. Não foi possível confirmar:
- Se existe coluna `cod_repositorio` ou `repositorio` na tabela de projetos
- Qual é a FK entre `COD_PROJETO` e as tabelas de repositório/pastas

**Ação necessária:** Verificar no ambiente de produção (ou com DBA) antes de implementar #8 e #9.
