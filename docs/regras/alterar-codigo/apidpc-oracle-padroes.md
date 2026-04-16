# ApiDPC — Padrões Oracle

> Regras específicas para consultas e escrita Oracle no ApiDPC (driver `yajra/laravel-oci8`).
> Aplicar em `ApiDPC/app/Repositories/**` e em qualquer código que execute SQL contra Oracle.

Ver também: [apidpc-convencoes.md](apidpc-convencoes.md)

---

## 1. Driver e case sensitivity

O driver `yajra/laravel-oci8` usa OCI8 por baixo. Colunas retornadas em `select` bruto (`DB::select`, `selectOne`) vêm com **nomes em UPPERCASE**, porque é o default do Oracle SQL*Net.

- Em queries via query builder (`->table()->get()`) o Laravel normaliza para lowercase.
- Em `DB::select("SELECT ...")` **não** há normalização — acessar como `$row->LICENCA`, `$row->CLIENTE`, etc.

**Padrão de normalização quando o Vue/front consome JSON:**

```php
$dados = DB::connection(env('DB_CONNECTION_ORACLE'))
    ->select("SELECT licenca, MIN(cliente) AS cliente FROM dovemail.dpcv_edi_projeto_licenca GROUP BY licenca ORDER BY 2");

$retorno['data'] = array_map(fn($row) => [
    'licenca' => $row->LICENCA ?? $row->licenca,
    'cliente' => $row->CLIENTE ?? $row->cliente,
], $dados);
```

Usar o fallback `?? $row->lowercase` só por segurança — em prática vem sempre UPPERCASE em `DB::select`.

---

## 2. ORDER BY com alias que colide com coluna

Oracle rejeita `ORDER BY MIN(cliente)` quando existe `AS cliente` no SELECT por ambiguidade sintática. A query executa vazia e o endpoint retorna `error: 1`.

**Regra:** quando o alias coincidir com um nome de coluna real envolvido em função agregada, **ordenar por posição**:

```sql
-- ❌ quebra no oci8
SELECT licenca, MIN(cliente) AS cliente
FROM dovemail.dpcv_edi_projeto_licenca
GROUP BY licenca
ORDER BY MIN(cliente)

-- ✅ funciona
SELECT licenca, MIN(cliente) AS cliente
FROM dovemail.dpcv_edi_projeto_licenca
GROUP BY licenca
ORDER BY 2
```

Alternativa: renomear o alias (`AS nome_cliente`), mas o contrato com o front precisa acompanhar.

---

## 3. Toda query nova passa pelo MCP DPC antes de virar código

Antes de colar um `SELECT` novo em um Repository, **executar via MCP DPC** (`oracle_query` ou equivalente) contra o banco real. Critérios para considerar validado:

- Retornou linhas com o shape esperado.
- Não lançou `ORA-*` de ambiguidade, sintaxe ou permissão.
- Colunas conferidas pelo nome que o PHP vai acessar.

Motivo: queries "escritas de cabeça" já geraram bug silencioso (lista vazia, fallback expõe código no lugar do nome) — ver sessão de diagnóstico em `.claude/temp/sessoes-tarefas-3057-3064`.

---

## 4. Sequences para PK

Padrão do schema `dovemail`: sequence por tabela no formato `dpcs_<tabela>_pk`.

```php
$seq = DB::connection($connection)
    ->selectOne("select dovemail.dpcs_edi_projeto_pk.nextval as cod_projeto from dual");
$dados['cod_projeto'] = $seq->cod_projeto;
DB::connection($connection)->table($table)->insert($dados);
```

- **Nunca** aceitar `cod_projeto` vindo do front em operação de insert — gerar sempre via sequence.
- Devolver o código gerado no retorno do `store()` para o front poder selecionar o registro recém-criado.

---

## 5. Schemas acessíveis via MCP DPC

Schemas atualmente permitidos pelo MCP: `consinco`, `poseidon`, `dovemail`.

- Sempre qualificar tabelas (`dovemail.DPC_EDI_PROJETO`, não `DPC_EDI_PROJETO`).
- Máx 2 tentativas no MCP por dúvida estrutural; depois disso, perguntar ao usuário.

---

## 6. Contrato de resposta

Repository sempre retorna, via `response()->json()`, o shape:

```php
['error' => 0|1, 'message' => '...', 'data' => ...]
```

- Não trocar `error` por `status`, nem `message` por `msg`, nem `data` por `result` sem alinhamento explícito.
- Em erro capturado, `error = 1` + `message` humanizada; não vazar `$e->getMessage()` cru para o front em produção.

---

## 7. Checklist ao adicionar endpoint Oracle

- [ ] Query testada no MCP DPC (shape + ordering + sem ambiguidade).
- [ ] Schema qualificado explicitamente (`dovemail.*`).
- [ ] Case das colunas considerado (normalização `array_map` se usar `DB::select`).
- [ ] Sequence usada para PK em insert.
- [ ] Resposta no contrato `{ error, message, data }`.
- [ ] `try/catch` cobrindo a execução, com mensagem humanizada no `message`.
