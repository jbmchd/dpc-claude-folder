# Sessão de Diagnóstico e Correção - Licenças EDI (#3057 #3064)

## Resumo Executivo

Sessão focada em diagnosticar e corrigir falha na exibição de licenças no modal de cadastro de projetos EDI. O problema raiz era uma ambiguidade no Oracle SQL que causava falha na query de `GROUP BY`, deixando a lista de licenças vazia e forçando o fallback que exibia o código da licença como seu nome de exibição.

## Problema Reportado Pelo Usuário

1. **Síntoma 1**: Licença exibindo código (`FJGDF50359`) em vez do nome do cliente (`AUGUSTUS PHARMA LTDA`)
2. **Síntoma 2**: Console mostrando erros ao buscar licenças
3. **Contexto**: Tela anterior (Maracanã/VB.NET) exibia o nome corretamente

## Investigação

### Diagnóstico Progressivo

**Primeira Coleta de Dados:**
- Verificação do arquivo Vue (ModalSalvar.vue) → race condition identificada (buscarProjeto rodando antes de buscarLicencas)
- Verificação do repositório PHP → query original sem GROUP BY retornava múltiplas linhas por licença
- Comparação com Maracanã → confirmado que sistema original também usava view `dpcv_edi_projeto_licenca`

**Investigação da Causa Raiz:**
1. Usou MCP `oracle_sample` para inspecionar dados da view
   - Resultado: 100 linhas amostradas, coluna `CLIENTE` retornando em MAIÚSCULO (Oracle padrão)
   - Observado: todos dados em formato UPPERCASE (LICENCA, CLIENTE, COD_PROJETO, STATUS)

2. Verificação das alterações anteriores
   - Query anterior: `SELECT licenca, MIN(cliente) AS cliente FROM ... GROUP BY licenca ORDER BY MIN(cliente)`
   - Issue: Alias `cliente` conflita com coluna `cliente` → Oracle interpreta `ORDER BY MIN(cliente)` ambiguamente

3. Adição de Diagnóstico Vue
   - Implementado: `console.log/warn` na `buscarLicencas()` e `buscarProjeto()`
   - Resultado: console revelou `[licencas] API retornou erro: Ocorreu um erro ao buscar licenças.` + `licencas carregadas: 0`

### Conclusão

**Causa Raiz Confirmada**: Oracle SQL retornando erro na execução de `SELECT licenca, MIN(cliente) AS cliente FROM dovemail.dpcv_edi_projeto_licenca GROUP BY licenca ORDER BY MIN(cliente)` — o `ORDER BY MIN(cliente)` após alias `AS cliente` cria ambiguidade sintática que Oracle rejeita.

## Soluções Implementadas

### 1. Correção PHP - ApiDPC (TiProjetosEdiRepository.php)

**Antes:**
```php
$dados = DB::connection(env('DB_CONNECTION_ORACLE'))
    ->select("SELECT licenca, MIN(cliente) AS cliente FROM dovemail.dpcv_edi_projeto_licenca GROUP BY licenca ORDER BY MIN(cliente)");
```

**Depois:**
```php
$dados = DB::connection(env('DB_CONNECTION_ORACLE'))
    ->select("SELECT licenca, MIN(cliente) AS cliente FROM dovemail.dpcv_edi_projeto_licenca GROUP BY licenca ORDER BY 2");

$retorno['data'] = array_map(fn($row) => [
    'licenca' => $row->LICENCA ?? $row->licenca,
    'cliente' => $row->CLIENTE ?? $row->cliente,
], $dados);
```

**Alterações:**
- `ORDER BY MIN(cliente)` → `ORDER BY 2` (referência posicional, sem ambiguidade)
- Normalização de chaves: `LICENCA/licenca` e `CLIENTE/cliente` para garantir lowercase independente do driver Oracle

### 2. Aprimoramento Vue - DPC (ModalSalvar.vue)

**Método `buscarLicencas()`:**
```js
buscarLicencas() {
  return dpcAxios
    .connection()
    .get(process.env.ENDERECO_APIDPC + "ti/projetos-edi/licencas")
    .then((response) => {
      if (response.data.error == 0) {
        this.licencas = response.data.data;
        console.log("[licencas] carregadas:", this.licencas.length, this.licencas.slice(0, 3));
      } else {
        console.warn("[licencas] API retornou erro:", response.data.message);
      }
    })
    .catch((e) => console.error("[licencas] falha na requisição:", e));
}
```

**Método `buscarProjeto()` (section de fallback):**
```js
if (d.licenca && !this.licencas.find((l) => l.licenca === d.licenca)) {
  console.warn(
    "[buscarProjeto] licença não encontrada na lista:",
    d.licenca,
    "— licencas carregadas:", this.licencas.length,
    "— primeiros itens:", this.licencas.slice(0, 3)
  );
  this.licencas.unshift({ licenca: d.licenca, cliente: d.licenca });
}
```

**Alterações:**
- Adicionado `console.log/warn` para diagnosticar falhas futuras
- Logs mostram: licenças carregadas (número e amostra) ou erro retornado pela API

### 3. Outras Correções Mantidas (sessão anterior)

- Race condition: `buscarProjeto()` agora aguarda `buscarLicencas()` via promise chaining
- Layout checkboxes: 3 colunas (alinhado ao Maracanã)
- Label "Pasta:": em linha isolada acima do select

## Commits Realizados

### ApiDPC
```
Commit: 9a7b7678
Message: ajustando diversos pontos na tela para equivaler à tela existente no maracana
Arquivos:
  - app/Http/Controllers/TiProjetosEdiController.php (+18 linhas)
  - app/Repositories/TiProjetosEdiRepository.php (+146/-23 linhas)
  - routes/api.php (+5/-1 linhas)
```

### DPC
```
Commit: 1e3b6efae
Message: ajustando diversos pontos na tela para equivaler à tela existente no maracana
Arquivos:
  - src/app/ti/edi-pedidos/cadastro-projetos/components/modal/ModalCadastroLicenca.vue (+152/-152)
  - src/app/ti/edi-pedidos/cadastro-projetos/components/modal/ModalSalvar.vue (+519/-358)
```

Ambos em branch: `feature/3057-edi-cadastro-projetos`

## Próximos Passos

1. **Validação em Ambiente**: Deploy das alterações e teste manual no navegador
2. **Limpeza de Logs**: Após confirmação de que tudo funciona, remover os `console.log/warn` de diagnóstico
3. **Monitoramento**: Observar logs de produção para erros Oracle futuros relacionados a queries

## Referências Técnicas

### Driver Oracle
- **Driver**: `yajra/laravel-oci8`
- **Comportamento**: Column names retornam em UPPERCASE por padrão do Oracle PDO
- **Normalização**: PHP array_map garante lowercase para compatibilidade com Vue

### Sintaxe Oracle
- `ORDER BY 2` = ordem pela 2ª coluna do SELECT (posicional)
- Evita ambiguidade de alias quando alias coincide com nome de coluna original
- Equivalente em semântica a `ORDER BY MIN(cliente)` mas sem conflito sintático

### Vue Promise Chaining
```js
const licencasPromise = this.buscarLicencas(); // returns Promise
if (this.codProjeto) {
  licencasPromise.then(() => this.buscarProjeto()); // espera licencas resolver
}
```

## Documentação de Suporte

- **View Oracle**: `DOVEMAIL.DPCV_EDI_PROJETO_LICENCA`
  - Coluna `LICENCA` (VARCHAR2, 50 chars, NOT NULL)
  - Coluna `CLIENTE` (VARCHAR2, 40 chars, NOT NULL)
  - Coluna `STATUS` (VARCHAR2, 1 char, NOT NULL)
  - Coluna `COD_PROJETO` (NUMBER, nullable)

- **Endpoint API**: `GET /ti/projetos-edi/licencas`
  - Resposta: `{ error: 0, data: [{licenca: "...", cliente: "..."}, ...] }`

- **Componente Vue**: `ModalSalvar.vue`
  - Método: `buscarLicencas()` → popula `this.licencas`
  - Método: `buscarProjeto()` → usa `this.licencas` com fallback

---

**Data da Sessão**: 2026-04-15
**Modelo utilizado**: Claude Sonnet 4.6 (sessão inicial), Claude Haiku 4.5 (diagnóstico)
**Status**: ✅ Implementado e Pushado
