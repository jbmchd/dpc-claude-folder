# Planejamento – Card #3064 DPC EDI: Cadastro de Projetos (Correções)

## Branch

> **ATENÇÃO — Pré-condição obrigatória antes de qualquer alteração de código:**
>
> Esta tarefa é **continuidade da tarefa #3057**. A branch já foi criada. Ao iniciar `/executar-tarefa`:
>
> 1. Verificar árvore limpa com `git status` nos projetos `DPC` e `ApiDPC`. Se houver pendências, fazer commit ou stash antes de prosseguir.
> 2. Fazer checkout na branch existente e atualizar:
>    ```bash
>    # Em DPC/
>    git checkout feature/3057-edi-cadastro-projetos && git pull
>    # Em ApiDPC/
>    git checkout feature/3057-edi-cadastro-projetos && git pull
>    ```
> 3. Somente após confirmar que está na branch correta, iniciar a codificação.
> 4. Ao concluir, enviar commits para o **mesmo PR da tarefa #3057** — não abrir novo PR.

- **Branch da tarefa:** `feature/3057-edi-cadastro-projetos`
- **Origem:** indicada explicitamente na descrição do card (#3064 é continuidade de #3057)
- **Base:** `main`
- **Status:** branch existente — fazer checkout e atualizar
- **Projetos afetados:** `DPC` e `ApiDPC`

---

## Objetivo

Aplicar 11 correções e melhorias na tela **Cadastro de Projetos EDI** implementada na tarefa #3057. Os arquivos existem em:
- `DPC/src/app/ti/edi-pedidos/cadastro-projetos/`
- `ApiDPC/app/` (Controller, Repository, Model)

---

## Mapeamento funcional preservado

| Regra/Comportamento | Onde | Observação |
|---|---|---|
| API usa `dpcAxios.connection()` | `Main.vue`, `ModalSalvar.vue` | Manter padrão |
| Resposta da API: `{ error, message, data }` | `TiProjetosEdiRepository.php` | Não alterar contrato |
| Evento `@buscar-dados` ao salvar | `ModalSalvar.vue` | Não remover |
| Evento `@close` ao fechar modal | `ModalSalvar.vue` | Não remover |
| `v-if="showModalSalvar"` destrói modal ao fechar | `Main.vue` | Manter para resetar estado |
| `clearArray` reseta offset na paginação | `Main.vue` | Manter lógica de paginação |

---

## Análise dos 11 itens e diagnóstico

### #1 — Erro ao ordenar coluna (Bug crítico no backend)

**Causa raiz identificada:** `ApiDPC/app/DpcEdiProjeto.php` linha 93:
```php
$dados = $dados->orderByRaw($coluna .' '. $params['orderBy'][0]['ordem']);
```
A variável `$coluna` **não está definida** — deveria ser `$params['orderBy'][0]['coluna']`.

**Correção:**
- Arquivo: `ApiDPC/app/DpcEdiProjeto.php` — linha 93
- Substituir `$coluna` por `$params['orderBy'][0]['coluna']`

---

### #2 — Alinhamento e espaçamento no modal Editar

**Diagnóstico:** O conteúdo do slot `body` do modal não tem padding lateral, os campos colam nas bordas.

**Correção:**
- Arquivo: `DPC/src/app/ti/edi-pedidos/cadastro-projetos/components/modal/ModalSalvar.vue`
- Envolver o conteúdo do slot body em `<div class="container-fluid">` (padrão dos outros modais do projeto) ou adicionar `padding: 0 15px` via SCSS.

---

### #3 — Renomear labels dos inputs (compatibilidade com Maracanã)

**Mapeamento Maracanã → DPC:**

| Label atual (DPC) | Renomear para |
|---|---|
| `Descrição` | `Projeto` |
| `Cód. Projeto Terceiro` | `Cod. do projeto no parceiro` |

**Arquivo:** `ModalSalvar.vue` — apenas as tags `<label>`.

---

### #4 — Converter "Segmento" de input number para select + reposicionar

**Diagnóstico:** O campo `nrosegmento` está como `type="number"`. No Maracanã, é um `<select>` com descrições de texto (ex: "ELETRÔNICO", "COMISSÃO FIXA"). O campo deve ser movido para a primeira seção do modal, ao lado de **Cod. do projeto no parceiro**.

**Tabela identificada:** `consinco.mad_segmento` — campos: `nrosegmento`, `descsegmento`, `status`.
Query já existe no projeto em `DpcComparaProdutoDpc.php::buscarSegmento()`:
```php
SELECT a.nrosegmento, a.descsegmento
FROM consinco.mad_segmento a
WHERE a.status = 'A' ORDER BY a.nrosegmento
```

**Implementação:**
1. **ApiDPC** — Adicionar método `segmentos()` em `TiProjetosEdiController` e em `TiProjetosEdiRepository`, reutilizando a query acima. Adicionar rota `GET /ti/projetos-edi/segmentos`.
2. **DPC** — No `ModalSalvar.vue`: carregar segmentos no `mounted()`, renderizar `<select>` com `nrosegmento` como value e `descsegmento` como label. Mover campo para a seção de campos básicos, ao lado de "Cod. do projeto no parceiro".

---

### #5 — Botão "Nova" para cadastro de licenças

**Diagnóstico:** O campo `licenca` já é um `<select>` (fix #10). O Maracanã tem um botão "Nova" ao lado do select que abre a tela de cadastro de licenças.

**Escopo confirmado:** Botão "Nova" está no escopo desta tarefa, junto com a tela de cadastro de licenças.

**Pré-requisito:** Inspecionar a tela de cadastro de licenças no Maracanã antes de implementar — levantar campos, validações e fluxo de salvamento.

**Tabela alvo:** `dovemail.dpc_dm_licenca` — PK: `licenca` (VARCHAR), campos: `status`, `conexoes`, `tipo`, `permitepedido`, `datacriacao`, `bloqueada`, `carga_sob_demanda`.

**Implementação (a detalhar após inspeção do Maracanã):**
1. **DPC** — Botão "Nova" ao lado do select de `licenca` no `ModalSalvar.vue`, que abre um novo modal de cadastro de licença.
2. **ApiDPC** — Endpoint `POST /ti/projetos-edi/licencas/salvar` para gravar na `dpc_dm_licenca`.
3. Após salvar a nova licença, recarregar o select e selecionar automaticamente a licença criada.

---

### #6 — Ocultar campo "Cód. Projeto" no modal

**Diagnóstico:** O campo `cod_projeto` aparece no modal. Com geração automática (item #7), não deve aparecer.

**Correção:**
- Arquivo: `ModalSalvar.vue`
- Remover o `<div class="form-group">` que contém o input `cod_projeto`.
- Remover a validação `!this.form.cod_projeto` de `verificaCampos()`.

---

### #7 — Gerar código de projeto automaticamente (Backend)

**Diagnóstico:** O `store` insere o `cod_projeto` enviado pelo frontend. Deve ser gerado via sequence Oracle.

**Correção Backend — `ApiDPC/app/Repositories/TiProjetosEdiRepository.php`:**
```php
if ($isNew) {
    $seq = DB::connection($connection)
        ->selectOne("select dovemail.dpcs_edi_projeto_pk.nextval as cod_projeto from dual");
    $dados['cod_projeto'] = $seq->cod_projeto;
    DB::connection($connection)->table($table)->insert($dados);
    $retorno['cod_projeto'] = $dados['cod_projeto'];
} else { ... }
```

**Correção Frontend — `ModalSalvar.vue`:**
- Remover `cod_projeto` do objeto `form` inicial (ou não enviá-lo quando `!codProjeto`).
- Não enviar `cod_projeto` no payload do POST quando for novo registro.

---

### #8 — Implementar seção de pastas do projeto

**Diagnóstico:** O Maracanã tem uma grid de pastas/repositórios FTP vinculadas ao projeto. O DPC não tem essa seção.

**Tabelas identificadas no banco (em `dovemail`):**

| Tabela | Papel | Colunas relevantes |
|---|---|---|
| `DPC_EDI_REPOSITORIO` | Definição do repositório | `COD_REPOSITORIO` (PK), `DESCRICAO`, `ENDERECO`, `TIPO`, `STATUS`, `SSL`, `PASSIVE`, etc. |
| `DPC_EDI_REPOSITORIO_PROJETO` | **Liga projeto ao repositório** | `COD_REPOSITORIO_ARQUIVO` (PK), `COD_PROJETO`, `COD_REPOSITORIO` |
| `DPC_REPOSITORIO_PASTAS` | Liga repositório às pastas | `COD_REPOSITORIO`, `COD_PASTA` |
| `DPC_EDI_ARQUIVO_REPOSI_PASTA` | Detalhes da pasta | `COD_PASTA` (PK), `CAMINHO`, `BACKUP`, `PEDIDO`, `RETORNO_PEDIDO`, `RETORNO_CANCELAMENTO_PEDIDO`, `RETORNO_NF`, `RETORNO_XML`, `RETORNO_PEDIDO_ANALISE`, `SUPORTE`, `ATIVO` |

**Fluxo de dados:**
- `DPC_EDI_PROJETO.COD_PROJETO` → (FK) `DPC_EDI_REPOSITORIO_PROJETO.COD_PROJETO` → `DPC_EDI_REPOSITORIO.COD_REPOSITORIO` → (via `DPC_REPOSITORIO_PASTAS`) → `DPC_ARQUIVO_REPOSI_PASTA` (detalhes da pasta)

**Implementação:**
1. **ApiDPC** — Criar endpoints:
   - `GET /ti/projetos-edi/{cod_projeto}/repositorio` — retorna `DPC_EDI_REPOSITORIO_PROJETO` do projeto
   - `GET /ti/projetos-edi/repositorios` — retorna lista de todos os repositórios (para select)
   - `GET /ti/projetos-edi/{cod_repositorio}/pastas` — retorna pastas do repositório (via `DPC_REPOSITORIO_PASTAS` + `DPC_EDI_ARQUIVO_REPOSI_PASTA`)
2. **DPC** — No `ModalSalvar.vue`:
   - Carregar repositório do projeto no `mounted()` e ao salvar
   - Grid de pastas com colunas: `CAMINHO`, `BACKUP`, `PEDIDO`, `RETORNO_PEDIDO`, `RETORNO_CANCELAMENTO_PEDIDO`, `RETORNO_NF`, `RETORNO_XML`, `RETORNO_PEDIDO_ANALISE`, `SUPORTE`, `ATIVO` (checkboxes)

---

### #9 — Adicionar campo "Repositório"

**Diagnóstico:** O Maracanã tem um campo "Repositório" no formulário. Este campo é um **select** da tabela `DPC_EDI_REPOSITORIO`, obtido via ligação em `DPC_EDI_REPOSITORIO_PROJETO`.

**Tabela identificada:** `dovemail.DPC_EDI_REPOSITORIO` — PK: `COD_REPOSITORIO`, com descrição em `DESCRICAO`.

**Relação:** Via `DPC_EDI_REPOSITORIO_PROJETO` (tabela de ligação): `COD_PROJETO` → `COD_REPOSITORIO`.

**Implementação — `ModalSalvar.vue`:**
- Campo `<select>` carregado via `GET /ti/projetos-edi/repositorios`
- Value: `COD_REPOSITORIO`, Label: `DESCRICAO`
- Ao salvar, gravar a relação em `DPC_EDI_REPOSITORIO_PROJETO` (via endpoint ApiDPC)
- Ao carregar projeto (editar), consultar repositório via `GET /ti/projetos-edi/{cod_projeto}/repositorio`

---

### #10 — Converter "Licença" de input text para select

**Diagnóstico:** Campo `licenca` é input text. No Maracanã, é um select com valores como "REDE MONICA".

**Tabela identificada:** `dovemail.dpc_dm_licenca` — PK: `licenca` (VARCHAR), campos: `status`, `conexoes`, `tipo`, `permitepedido`, `datacriacao`, `bloqueada`, `carga_sob_demanda`.

**Implementação:**
1. **ApiDPC** — Criar `GET /ti/projetos-edi/licencas` que retorna `SELECT licenca FROM dovemail.dpc_dm_licenca WHERE status = 'A' ORDER BY licenca`.
2. **DPC** — No `ModalSalvar.vue`: carregar licenças no `mounted()`, renderizar `<select>` com `licenca` como value e label.

---

### #11 — Bloqueio condicional do Cód. Vendedor por Segmento

**Diagnóstico:** Quando segmento ≠ "COMISSÃO FIXA", o campo `cod_vendedor` deve ficar `null` e `disabled`.

**Tabela identificada:** `consinco.mad_segmento` (mesma do item #4). O `nrosegmento` de "COMISSÃO FIXA" será conhecido após carregar os segmentos no modal.

**Correção — `ModalSalvar.vue`:**
- Usar o array de segmentos já carregado (item #4) para achar o `nrosegmento` de "COMISSÃO FIXA" via `descsegmento`.
- Computed `isSegmentoComissaoFixa`: retorna `true` quando `form.nrosegmento` corresponde ao segmento cujo `descsegmento` é `'COMISSÃO FIXA'`.
- `watch` em `form.nrosegmento`: quando mudar e `!isSegmentoComissaoFixa`, setar `form.cod_vendedor = null`.
- No input de `cod_vendedor`: `:disabled="!isSegmentoComissaoFixa"`.

---

## Escopo dos arquivos a modificar

### ApiDPC
| Arquivo | Mudança |
|---|---|
| `app/DpcEdiProjeto.php` | Corrigir `$coluna` → `$params['orderBy'][0]['coluna']` no `orderByRaw` |
| `app/Repositories/TiProjetosEdiRepository.php` | Gerar `cod_projeto` via sequence no insert; novos métodos: `segmentos()`, `licencas()`, `repositorio()`, `pastas()`, `salvarRepositorio()` |
| `app/Http/Controllers/TiProjetosEdiController.php` | Novos métodos: `segmentos()`, `licencas()`, `repositorio()`, `pastas()`, `salvarRepositorio()` |
| `app/Models/DpcEdiRepositorioProjeto.php` | **Novo model** — representa ligação projeto-repositório |
| `routes/api.php` | Novas rotas: `/segmentos`, `/licencas`, `/licencas/salvar`, `/{cod_projeto}/repositorio`, `/{cod_repositorio}/pastas`, `/{cod_projeto}/repositorio/salvar` |

### DPC
| Arquivo | Mudança |
|---|---|
| `src/app/ti/edi-pedidos/cadastro-projetos/components/Main.vue` | Nenhuma |
| `src/app/ti/edi-pedidos/cadastro-projetos/components/modal/ModalSalvar.vue` | Items #5, #8, #9 pendentes — botão "Nova" + modal de licença, select de repositório, grid de pastas |
| `src/app/ti/edi-pedidos/cadastro-projetos/components/modal/ModalCadastroLicenca.vue` | **Novo modal** — cadastro de licença (item #5, a criar após inspeção do Maracanã) |

---

## Passos de execução

### Fase 1 — Bugfixes rápidos (SEM investigação adicional) ✅ CONCLUÍDO

- [x] **#1** — Corrigir `$coluna` em `DpcEdiProjeto.php` (linha 93)
- [x] **#2** — Adicionar `container-fluid` no slot body do modal
- [x] **#3** — Renomear labels: `Descrição → Projeto`, `Cód. Projeto Terceiro → Cod. do projeto no parceiro`
- [x] **#6** — Remover div do campo Cód. Projeto do modal e remover sua validação
- [x] **#7** — Gerar código via sequence no backend; endpoints `/segmentos` e `/licencas`

### Fase 2 — Melhorias com banco (investigação concluída) 🔄 PENDENTE

- [x] **#4** + **#11** — Select de segmento + bloqueio condicional de Cód. Vendedor ✅ implementado em `ModalSalvar.vue`
- [x] **#10** — Select de licença ✅ implementado em `ModalSalvar.vue`
- [ ] **#9** — Select de Repositório (tabela: `DPC_EDI_REPOSITORIO`, via `DPC_EDI_REPOSITORIO_PROJETO`)
- [ ] **#8** — Grid de pastas (tabelas: `DPC_REPOSITORIO_PASTAS` + `DPC_EDI_ARQUIVO_REPOSI_PASTA`)
- [ ] **#5** — Botão "Nova" ao lado do select de Licença + tela de cadastro de licenças (investigar Maracanã antes de implementar)

### Validação

- [x] Clicar em coluna para ordenar — sem erro (fix #1)
- [x] Abrir modal Editar — campos alinhados com espaço nas bordas (fix #2)
- [x] Labels corretos no modal (fix #3)
- [x] Criar novo projeto — campo Cód. Projeto não aparece, código gerado automaticamente (fix #6 e #7)
- [x] Select de segmento funcional; Cód. Vendedor bloqueado/liberado (fix #4 e #11)
- [x] Select de licença (fix #10)
- [ ] Botão "Nova" ao lado do select de licença; tela de cadastro de licenças abre corretamente (fix #5)
- [ ] Select de Repositório e grid de pastas funcionais (fix #8 e #9)
- [ ] `npm run build` sem erros no DPC

---

## Referências visuais (images/)

| Imagem | Conteúdo |
|---|---|
| `image_69dcd193f032496c736c5368.png` | Cabeçalhos com borda vermelha — bug de ordenação na listagem |
| `image_69dcd1613881fe6983f0eaa9.png` | Segunda captura do bug de ordenação |
| `image_69dccdd33061403c1c0f0e6a.png` | Modal atual sem padding (problema de alinhamento) |
| `image_69dcce1a476cfc94947eb604.png` | Modal com alinhamento correto (esperado) |
| `image_69dcd3c91e4b95f03000c534.png` | Maracanã: nomes dos campos (ex: "Projeto" para descrição) |
| `image_69dcd3de9de19c45931a3795.png` | DPC atual: campo Nº Segmento como input |
| `image_69dcd4900f03b48cb59849e2.png` | Maracanã: Segmento como select, ao lado de Cod. projeto no parceiro |
| `image_69dcd4d615e140f15346fad6.png` | DPC: sem botão Nova para licenças |
| `image_69dcd921d72bb2d7056ab823.png` | Maracanã: botão Nova para licenças |
| `image_69dcd8a783b20f92b5bfa8c2.png` | Campo Cód. Projeto visível no modal (deve ser ocultado) |
| `image_69dccfb9f7fa282c1f7f5c75.png` | Exemplo de geração automática via sequence |
| `image_69dcd95bda30abc24c640c62.png` | Maracanã: grid de pastas do projeto |
| `image_69dcd989c1d51619c175ef70.png` | Maracanã: campo Repositório |
| `image_69dcd9fa13e6e70fb743285a.png` | Comparação Maracanã vs DPC (Licença, Segmento, layout geral) |
| `image_69dcda4d11e70817943bbf0f.png` | Maracanã: Cód. Vendedor habilitado com segmento COMISSÃO FIXA |
| `image_69dcda5a635d76487ed5dd29.png` | Maracanã: Cód. Vendedor bloqueado em outro segmento |
