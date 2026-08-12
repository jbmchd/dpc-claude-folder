# Documentação de domínio Oracle — Convênio / Empresa

> Mapeamento extraído **exclusivamente** do código-fonte VB.NET do Maracanã
> (`Telas/Pessoal/Convenio/Empresa/dalConvenioEmpresa.vb`), conforme
> [migracao-legado.md §3.3](../regras/gerenciar-regras/migracao-legado.md).
> **Nenhum acesso ao banco real foi feito** durante o planejamento (proibido em migração de tela).
> Tipos marcados como *(inferido)* vêm do uso no DAL, não de `DESC` da tabela.

---

## Domínio: `convenio-empresa`

**Schema(s) envolvido(s):** `poseidon` (gravação) + `consinco` (leitura do combo de empresas)
**Escopo funcional:** Cadastro da "Empresa de Convênio" — vincula uma empresa do Consinco (`ge_empresa`) a um código Controller e uma descrição, com status Ativo/Inativo. Registro único por `cod_empresa_consinco`.
**Telas do Maracanã que usam:** `workspace/maracana/Maracana/Maracana/Telas/Pessoal/Convenio/Empresa/`
**Últimas tarefas que tocaram:** #3241
**Data do mapeamento:** 2026-07-30

---

## Diagrama de relacionamento

```
consinco.GE_EMPRESA.NROEMPRESA
        │ (vínculo lógico, sem FK física declarada no DAL)
        ▼
poseidon.DPC_CV_EMPRESA.COD_EMPRESA_CONSINCO
        ▲
        │ PK própria
poseidon.DPC_CV_EMPRESA.COD_EMPRESA  ← sequence poseidon.DPCS_CV_EMPRESA_PK
```

---

## Tabelas e views

### `POSEIDON.DPC_CV_EMPRESA`

- **Tipo:** tabela
- **PK:** `COD_EMPRESA`
- **Sequence associada:** `DPCS_CV_EMPRESA_PK` (usada no legado como `dpcs_cv_empresa_pk.nextval`)
- **Modelo Eloquent existente:** `App\DpcCvEmpresa` (`ApiDPC/app/DpcCvEmpresa.php`) — já mapeia `poseidon.dpc_cv_empresa`

| Coluna | Tipo | Null | Descrição |
|---|---|---|---|
| `COD_EMPRESA` | NUMBER *(inferido)* | NO | PK. Gerada por sequence no insert; usada como `<> ?` nas validações de unicidade. |
| `COD_EMPRESA_CONSINCO` | NUMBER *(inferido)* | NO | Empresa do Consinco (`ge_empresa.nroempresa`). Chave funcional do registro — a tela busca por ela. |
| `CODIGO_EMPRESA_CONTROLLER` | NUMBER *(inferido — input numérico)* | NO | "Cód. Controller". Só dígitos (KeyPress bloqueia não-numéricos). Único (excluindo o próprio registro). |
| `DESCRICAO` | VARCHAR2(50) *(MaxLength=50 no form)* | NO | Descrição em MAIÚSCULAS (CharacterCasing.Upper). Única (excluindo o próprio registro). |
| `STATUS` | CHAR(1) *(inferido)* | NO | `A` = Ativo, `I` = Inativo. Default `A` (checkbox marcado). |

**Observações:** o `preencheCampos` faz `select *` — no ApiDPC preferir listar colunas explícitas do `$fillable` do model, que já bate 1:1 com as colunas acima.

### `CONSINCO.GE_EMPRESA` (somente leitura — alimenta o combo "Empresa Consinco")

- **Tipo:** tabela (Consinco)
- **Colunas usadas no DAL:** `NROEMPRESA` (value do combo), `FANTASIA` (label do combo)
- **Ordenação no legado:** `ORDER BY fantasia`

| Coluna | Tipo | Null | Descrição |
|---|---|---|---|
| `NROEMPRESA` | NUMBER *(inferido)* | NO | Nº da empresa Consinco. Vai para `dpc_cv_empresa.cod_empresa_consinco`. |
| `FANTASIA` | VARCHAR2 *(inferido)* | — | Nome fantasia exibido no dropdown. |

**Observações:** tabela grande do Consinco; o legado carrega a lista inteira sem filtro. Ao migrar, avaliar se compensa filtrar/pesquisar server-side (não é obrigatório para paridade funcional).

---

## Queries canônicas

Todas extraídas de `dalConvenioEmpresa.vb`. `connPoseidon` → schema `poseidon`; `connConsinco` → schema `consinco`.

### 1. Empresas Consinco (combo) — `pegaEmpresasConsinco`
**Fonte:** `dalConvenioEmpresa.vb::pegaEmpresasConsinco` (connConsinco)
```sql
SELECT nroempresa, fantasia FROM consinco.ge_empresa ORDER BY fantasia
```

### 2. Buscar cod_empresa por empresa Consinco — `pegaCodEmpresa`
**Fonte:** `dalConvenioEmpresa.vb::pegaCodEmpresa` (connPoseidon) — retorna `0` quando não existe
```sql
SELECT cod_empresa FROM poseidon.dpc_cv_empresa WHERE cod_empresa_consinco = :cod_empresa_consinco
```

### 3. Preencher campos do registro — `preencheCampos`
**Fonte:** `dalConvenioEmpresa.vb::preencheCampos` (connPoseidon)
```sql
SELECT * FROM poseidon.dpc_cv_empresa WHERE cod_empresa_consinco = :cod_empresa_consinco
```

### 4. Validar unicidade do Cód. Controller — `codigoEmpresaControllerValido`
**Fonte:** `dalConvenioEmpresa.vb::codigoEmpresaControllerValido` (connPoseidon) — retorna inválido se houver linha
```sql
SELECT codigo_empresa_controller FROM poseidon.dpc_cv_empresa
WHERE codigo_empresa_controller = :codigo_empresa_controller AND cod_empresa <> :cod_empresa
```

### 5. Validar unicidade da Descrição — `descricaoValida`
**Fonte:** `dalConvenioEmpresa.vb::descricaoValida` (connPoseidon)
```sql
SELECT descricao FROM poseidon.dpc_cv_empresa
WHERE descricao = :descricao AND cod_empresa <> :cod_empresa
```

### 6. Inserir — `gravaEmpresaController`
**Fonte:** `dalConvenioEmpresa.vb::gravaEmpresaController` (connPoseidon)
```sql
SELECT dpcs_cv_empresa_pk.nextval FROM dual;  -- gera COD_EMPRESA

INSERT INTO poseidon.dpc_cv_empresa
  (cod_empresa, cod_empresa_consinco, codigo_empresa_controller, descricao, status)
VALUES (:cod_empresa, :cod_empresa_consinco, :codigo_empresa_controller, :descricao, :status);
```

### 7. Atualizar — `updateEmpresaController`
**Fonte:** `dalConvenioEmpresa.vb::updateEmpresaController` (connPoseidon)
```sql
UPDATE poseidon.dpc_cv_empresa
SET cod_empresa_consinco = :cod_empresa_consinco,
    codigo_empresa_controller = :codigo_empresa_controller,
    descricao = :descricao,
    status = :status
WHERE cod_empresa = :cod_empresa;
```

---

## Pegadinhas conhecidas

- **Chave funcional ≠ PK:** o registro é localizado por `cod_empresa_consinco` (não pela PK `cod_empresa`). As validações de unicidade usam `cod_empresa <> ?` para não colidir consigo mesmo no update.
- **Decisão novo vs. update no legado:** o Maracanã decide por `cod_empresa == 0` (retorno de `pegaCodEmpresa`). No ApiDPC, seguir o padrão do sibling `storeConvenio` (`cod_empresa` nulo/vazio → insert; caso contrário → update).
- **`DESCRICAO` sempre MAIÚSCULA** e `CODIGO_EMPRESA_CONTROLLER` só dígitos — validar/normalizar no front e reforçar no back (`strtoupper`).
- **Dois schemas na mesma tela:** combo lê de `consinco.ge_empresa`; gravação em `poseidon.dpc_cv_empresa`. Qualificar sempre o schema.
- **Sequence:** usar `poseidon.dpcs_cv_empresa_pk.nextval` (mesmo formato do sibling `dpcs_cv_dicionario.nextval` já usado no `ConvenioRepository`). Confirmar o nome exato no MCP DPC **na fase de execução** (não no planejamento).

---

## Referências cruzadas

- Regras Oracle: [../regras/alterar-codigo/apidpc-oracle-padroes.md](../regras/alterar-codigo/apidpc-oracle-padroes.md)
- Fluxo de migração: [../regras/gerenciar-regras/migracao-legado.md](../regras/gerenciar-regras/migracao-legado.md)
- Fonte VB.NET: `workspace/maracana/Maracana/Maracana/Telas/Pessoal/Convenio/Empresa/`
- Infra já existente no ApiDPC: `App\DpcCvEmpresa`, `ConvenioController`, `ConvenioRepository`
