# Domínio: `dovemail-gestao-licencas`

**Schema(s) envolvido(s):** `dovemail` (principal), `consinco`, `poseidon`
**Escopo funcional:** Gestão de licenças DoveMail — pesquisa, edição de status/bloqueio, sub-grids de detalhe e ações administrativas
**Telas do Maracanã que usam:** `Telas/DoveMail/Gerenciamento/Licencas/Frm_DoveMail_Gestao_Licenca.vb`
**Últimas tarefas que tocaram:** #3080
**Data do mapeamento:** 2026-04-27

---

## Diagrama de relacionamento

```
DOVEMAIL.DPC_DM_LICENCA.licenca (PK)
    ↓ (licenca)
DOVEMAIL.DPCV_GER_INF_CLIENTE (view — leitura principal da tela)
    ↓ (licenca)
DOVEMAIL.DPC_DM_LICENCACLIENTE.licenca → .cod_cliente
    ↓ (cod_cliente)
DOVEMAIL.DPC_DM_CLIENTES.cod_cliente
DOVEMAIL.DPCV_DMM_LICENCASCLIENTES (view — sub-grid clientes)
    ↓ (seqpessoa = cod_cliente)
CONSINCO.MAD_PEDVENDA.seqpessoa (usada no filtro sem-compra)
POSEIDON.DPCV_GER_ULTIMOSPEDIDOS.COD_CLIENTE (sub-grid pedidos)

DOVEMAIL.DPC_DM_GESTAO_LOG.licenca → .id_motivo
    ↓ (id_motivo)
DOVEMAIL.DPC_DM_MOTIVOS.id_motivo
    ↓ (id_motivo)
DOVEMAIL.DPC_DM_MOTIVOS_ESPECIFICACOES.id_motivo

CONSINCO.DPC_USUARIO.idusuario
    ↓
CONSINCO.DPC_USUARIOGRUPO.idusuario → .idgrupo (grupo 462 = ADM Dovemail)

CONSINCO.DPC_UPDT_LICENCAS.licenca → .versao (atualização de versão)
CONSINCO.DPC_UPDT_VERSOES.id → .versao
```

---

## Tabelas e views

### `DOVEMAIL.DPC_DM_LICENCA`

- **Tipo:** tabela
- **PK:** `licenca`

| Coluna | Tipo | Null | Descrição |
|---|---|---|---|
| `licenca` | VARCHAR2 | NO | PK |
| `status` | VARCHAR2 | YES | `'Ativo'` / `'Inativo'` |
| `permitepedido` | VARCHAR2 | YES | `'Sim'` / `'Nao'` |
| `bloqueada` | VARCHAR2 | YES | `'Sim'` / `'Nao'` |
| `carga_sob_demanda` | VARCHAR2 | YES | `'S'` / `'N'` |

**Observações:** UPDATE direto por `AtualizarInformacaoLicenca` no DAL. Os valores são strings legíveis, não flags de 1 char.

---

### `DOVEMAIL.DPCV_GER_INF_CLIENTE`

- **Tipo:** view
- **PK:** `licenca`
- **Origem da view:** agrega dados de `dpc_dm_licenca` com informações do cliente (código, razão, datas, segmento); `lc.*` no DAL indica que a view contém colunas além das selecionadas explicitamente.

| Coluna | Tipo | Null | Descrição |
|---|---|---|---|
| `licenca` | VARCHAR2 | NO | Identificador da licença |
| `datacriacao` | DATE | YES | Data de criação da licença |
| `versao_lib` | VARCHAR2 | YES | Última versão liberada (`'S'`/`'N'`) |
| `status` | VARCHAR2 | YES | `'Ativo'` / `'Inativo'` |
| `bloqueada` | VARCHAR2 | YES | `'Sim'` / `'Nao'` |
| `PermitirPedido` | VARCHAR2 | YES | `'Sim'` / `'Nao'` |
| `carga_sob_demanda` | VARCHAR2 | YES | |
| `nrosegmento` | NUMBER | YES | Nº do segmento; filtro `= 3` quando `chkTodos_segmentos` desmarcado |

**Observações:** usada em todos os modos de busca (`PegarInformacaoLicenca_*`). O `lc.*` indica que pode ter mais colunas.

---

### `DOVEMAIL.DPCV_GER_INF_CLIENTE_SEMCONECT`

- **Tipo:** view
- **Origem da view:** variação de `DPCV_GER_INF_CLIENTE` filtrada por licenças sem conexão recente.

| Coluna | Tipo | Descrição |
|---|---|---|
| `licenca` | VARCHAR2 | |
| `datacriacao` | DATE | |
| `versao_lib` | VARCHAR2 | |
| `status` | VARCHAR2 | |
| `bloqueada` | VARCHAR2 | |
| `PermitirPedido` | VARCHAR2 | |
| `carga_sob_demanda` | VARCHAR2 | |

**Observações:** O filtro de data/dias é aplicado diretamente sobre esta view (via WHERE na query).

---

### `DOVEMAIL.DPCV_DM_LICENCA_MANTER`

- **Tipo:** view
- **Origem da view:** representa a validade de manutenção da licença.

| Coluna | Tipo | Descrição |
|---|---|---|
| `licenca` | VARCHAR2 | FK → `dpc_dm_licenca.licenca` |
| `data` | DATE | Data limite; licença elegível se `TRUNC(SYSDATE) > TRUNC(data)` |

---

### `DOVEMAIL.DPC_DM_LICENCACLIENTE`

- **Tipo:** tabela

| Coluna | Tipo | Descrição |
|---|---|---|
| `licenca` | VARCHAR2 | FK → `dpc_dm_licenca.licenca` |
| `cod_cliente` | NUMBER | FK → `dpc_dm_clientes.cod_cliente` / `consinco.mad_pedvenda.seqpessoa` |

**Observações:** usada para resolver o N:N entre licença e cliente. `PegarCodigoClientesLicenca` retorna lista CSV de `cod_cliente`.

---

### `DOVEMAIL.DPC_DM_CLIENTES`

- **Tipo:** tabela

| Coluna | Tipo | Descrição |
|---|---|---|
| `cod_cliente` | NUMBER | PK |
| `nome` | VARCHAR2 | Razão social |
| `fantasia` | VARCHAR2 | |
| `status` | VARCHAR2 | `'A'` = Ativo — filtrado nas queries de busca por código/razão |

---

### `DOVEMAIL.DPCV_DMM_LICENCASCLIENTES`

- **Tipo:** view (sub-grid "Clientes da Licença")

| Coluna | Tipo | Descrição |
|---|---|---|
| `LICENCA` | VARCHAR2 | |
| `COD_CLIENTE` | NUMBER | |
| `NOME` | VARCHAR2 | Razão social |
| `situacao_credito` | VARCHAR2 | `'L'`=Liberado / outro=Bloqueado |
| `situacao_comercial` | VARCHAR2 | `'L'`=Liberado / outro=Bloqueado |
| `lim_credito` | NUMBER | Limite de crédito |
| `statuslicencacliente` | VARCHAR2 | `'L'`=Liberado / outro=Bloqueado |
| `STATUS` | VARCHAR2 | `'A'` = Ativo — filtrado na query |

**Observações:** `consinco.fge_VLRCREDUSO(l.COD_CLIENTE)` é função Oracle usada para calcular `cred_Usado` e `cred_restante` — requer chamada via `DB::raw`.

---

### `DOVEMAIL.DPCV_DMM_ATENDIMENTOS`

- **Tipo:** view (sub-grid "Histórico Atendimentos")

| Coluna | Tipo | Descrição |
|---|---|---|
| `id` | NUMBER | PK / ordenação DESC |
| `seqpessoa` | NUMBER | FK → cod_cliente |
| `situacao` | VARCHAR2 | Filtro opcional |
| (demais) | — | `*` — colunas não listadas explicitamente no DAL |

---

### `POSEIDON.DPCV_GER_ULTIMOSPEDIDOS`

- **Tipo:** view (sub-grid "Histórico Pedidos")

| Coluna | Tipo | Descrição |
|---|---|---|
| `COD_CLIENTE` | NUMBER | FK |
| `segmento` | VARCHAR2 | |
| `onde` | VARCHAR2 | |
| `totalpedido` | NUMBER | |
| `inclusao` | DATE | |
| `situacao` | VARCHAR2 | Filtro `= 'F'` |

---

### `DOVEMAIL.DPCV_GER_MAQUINAS_LICENCA`

- **Tipo:** view (sub-grid "Máquinas da Licença")

| Coluna | Tipo | Descrição |
|---|---|---|
| `licenca` | VARCHAR2 | Filtro WHERE |
| `idMaquina` | VARCHAR2 | |
| `status` | VARCHAR2 | Editável (Fase 4) |
| `atualizar` | VARCHAR2 | Editável (Fase 4) |

**Observações:** `ORDER BY status DESC, idmaquina`.

---

### `DOVEMAIL.DPCV_GER_CLIENTE_MOVIMENTACAO`

- **Tipo:** view (sub-grid "Movimentação")

| Coluna | Tipo | Descrição |
|---|---|---|
| `licenca` | VARCHAR2 | Filtro WHERE |
| `data` | DATE | |
| `usuario` | VARCHAR2 | |
| `observacao` | VARCHAR2 | |

---

### `DOVEMAIL.DPCV_GER_HISTORICOCONEXOES`

- **Tipo:** view (sub-grid "Conexões")

| Coluna | Tipo | Descrição |
|---|---|---|
| `licenca` | VARCHAR2 | Filtro WHERE |
| `idmaquina` | VARCHAR2 | |
| `datahora` | DATE | |
| `datahorafim` | DATE | |
| `versaope` | VARCHAR2 | |
| `cod_pedido` | NUMBER | |
| `status` | VARCHAR2 | |

---

### `DOVEMAIL.DPCV_GER_LICENCASLOG`

- **Tipo:** view (sub-grid "Log")

| Coluna | Tipo | Descrição |
|---|---|---|
| `licenca` | VARCHAR2 | Filtro WHERE |
| `descricao` | VARCHAR2 | |
| `data` | DATE | |
| `usuario` | VARCHAR2 | |
| `observacao` | VARCHAR2 | |

---

### `DOVEMAIL.DPC_DM_GESTAO_LOG`

- **Tipo:** tabela (log de operações — Fase 2)

| Coluna | Tipo | Descrição |
|---|---|---|
| `licenca` | VARCHAR2 | |
| `id_motivo` | NUMBER | FK → `dpc_dm_motivos` |
| `data` | DATE | |
| `usuario` | VARCHAR2 | |
| `observacao` | VARCHAR2 | |
| `bloqueado_licenca` | VARCHAR2 | `'S'` quando é log de bloqueio |
| `status_licenca` | VARCHAR2 | `'I'` quando é log de inativação |

---

### `DOVEMAIL.DPC_DM_MOTIVOS`

- **Tipo:** tabela

| Coluna | Tipo | Descrição |
|---|---|---|
| `id_motivo` | NUMBER | PK |
| `descricao` | VARCHAR2 | |

---

### `DOVEMAIL.DPC_DM_MOTIVOS_ESPECIFICACOES`

- **Tipo:** tabela

| Coluna | Tipo | Descrição |
|---|---|---|
| `id_motivo` | NUMBER | FK → `dpc_dm_motivos` |
| `observacao` | VARCHAR2 | `'S'`/`'N'` — se exige observação ao selecionar este motivo |
| `bloquear_licenca` | VARCHAR2 | |
| `inativar_licenca` | VARCHAR2 | |

---

### `CONSINCO.MAD_PEDVENDA`

- **Tipo:** tabela (schema consinco)

| Coluna | Tipo | Descrição |
|---|---|---|
| `seqpessoa` | NUMBER | FK → `dpc_dm_licencacliente.cod_cliente` |
| `situacaoped` | VARCHAR2 | `'F'` = pedido faturado |
| `datainclusao` | DATE | Data do pedido — alvo do filtro de tempo |

---

### `CONSINCO.DPC_USUARIO` / `CONSINCO.DPC_USUARIOGRUPO`

- **Tipo:** tabelas (controle de grupo admin)

| Coluna | Tipo | Descrição |
|---|---|---|
| `dpc_usuario.idusuario` | NUMBER | PK |
| `dpc_usuario.usuario` | VARCHAR2 | Login |
| `dpc_usuariogrupo.idgrupo` | NUMBER | `462` = grupo ADM Dovemail |

---

### `CONSINCO.DPC_UPDT_LICENCAS` / `CONSINCO.DPC_UPDT_VERSOES`

- **Tipo:** tabelas (controle de versão — Fase 4)

| Coluna | Tipo | Descrição |
|---|---|---|
| `dpc_updt_licencas.id` | NUMBER | `248` = produto DoveMail Cliente |
| `dpc_updt_licencas.licenca` | VARCHAR2 | |
| `dpc_updt_licencas.versao` | VARCHAR2 | |
| `dpc_updt_versoes.id` | NUMBER | |
| `dpc_updt_versoes.versao` | VARCHAR2 | Maior versão disponível |

---

### `CONSINCO.GE_REDEPESSOA` / `CONSINCO.GE_REDE`

- **Tipo:** tabelas (painel de limite de rede — Fase 3)

| Coluna | Tipo | Descrição |
|---|---|---|
| `ge_redepessoa.seqpessoa` | NUMBER | FK → cod_cliente |
| `ge_redepessoa.seqrede` | NUMBER | FK → `ge_rede` |
| `ge_redepessoa.status` | VARCHAR2 | `'A'` = ativo |
| `ge_rede.vlrlimitecredito` | NUMBER | Limite total da rede |

---

## Queries canônicas

### `buscarSemCompra — modo Período`

**Fonte no Maracanã:** `Dal_DoveMail_Gestao.vb::PegarInformacaoLicenca_SemCompra_DataOuPeriodo`

```sql
SELECT ic.licenca, ic.datacriacao, ic.versao_lib, ic.status,
       ic.bloqueada, ic.PermitirPedido, ic.carga_sob_demanda
FROM DOVEMAIL.DPCV_GER_INF_CLIENTE ic
LEFT JOIN DOVEMAIL.DPCV_DM_LICENCA_MANTER m ON m.licenca = ic.licenca
WHERE ic.licenca NOT IN (
    SELECT DISTINCT b.licenca
    FROM CONSINCO.MAD_PEDVENDA p
    INNER JOIN DOVEMAIL.DPC_DM_LICENCACLIENTE b ON b.cod_cliente = p.seqpessoa
        AND TRUNC(p.datainclusao) BETWEEN :data_inicio AND :data_fim
        AND p.situacaoped = 'F'
)
AND ic.status = 'Ativo'
AND ic.PermitirPedido = 'Sim'
AND ic.bloqueada = 'Nao'
AND TRUNC(SYSDATE) > TRUNC(m.data)
-- quando todos_segmentos = false: AND ic.nrosegmento = 3
ORDER BY licenca
```

### `buscarSemCompra — modo Dias`

```sql
-- idem acima, mas substituir filtro do subquery por:
-- AND TRUNC(p.datainclusao) >= TRUNC(SYSDATE - :dias)
```

### `buscarSemConexao`

**Fonte no Maracanã:** `Dal_DoveMail_Gestao.vb::PegarInformacaoLicenca_SemConexao_DataOuPeriodo`

```sql
SELECT s.licenca, s.datacriacao, s.versao_lib, s.status,
       s.bloqueada, s.PermitirPedido, s.carga_sob_demanda
FROM DOVEMAIL.DPCV_GER_INF_CLIENTE_SEMCONECT s
-- filtro de período: WHERE TRUNC(s.datacriacao) BETWEEN :data_inicio AND :data_fim
-- filtro de dias:    WHERE TRUNC(s.datacriacao) >= TRUNC(SYSDATE - :dias)
ORDER BY licenca
```

**Notas:** A view provavelmente já filtra licenças sem conexão; o filtro de data aplica sobre `datacriacao` da view.

### `buscarPorCodigoOuRazao`

**Fonte no Maracanã:** `Dal_DoveMail_Gestao.vb::PegarInformacaoLicenca_CodigoOuRazao`

```sql
SELECT DISTINCT ic.*
FROM DOVEMAIL.DPCV_GER_INF_CLIENTE ic
INNER JOIN DOVEMAIL.DPC_DM_LICENCACLIENTE lc ON ic.licenca = lc.licenca
INNER JOIN DOVEMAIL.DPC_DM_CLIENTES c ON c.cod_cliente = lc.cod_cliente
    AND c.status = 'A'
-- por código(s): AND c.cod_cliente IN (:cod1, :cod2, ...)
-- por razão:     AND UPPER(c.nome) LIKE UPPER('%:razao%')
ORDER BY ic.licenca
```

### `buscarPorLicenca`

**Fonte no Maracanã:** `Dal_DoveMail_Gestao.vb::PegarInformacaoLicenca_Licenca`

```sql
SELECT lc.*
FROM DOVEMAIL.DPCV_GER_INF_CLIENTE lc
WHERE lc.licenca IN (:lic1, :lic2, ...)
-- ou: WHERE lc.licenca = :licenca (busca exata)
ORDER BY licenca
```

---

## Pegadinhas conhecidas

- `DPCV_GER_INF_CLIENTE` retorna `lc.*` — pode ter colunas além das listadas aqui; inspecionar no MCP antes de usar `SELECT *` no PHP.
- Os valores de `status`, `bloqueada`, `PermitirPedido` são strings legíveis (`'Ativo'`, `'Sim'`, `'Nao'`), não flags de 1 char.
- `nrosegmento = 3` é o segmento padrão; o filtro só entra quando o checkbox "Todos os Segmentos" está desmarcado.
- `consinco.fge_VLRCREDUSO` é uma função Oracle — requer `DB::raw` ao usar em SELECT.
- `PegarCodigoClientesLicenca` retorna CSV de `cod_cliente`; no PHP usar `whereIn` em vez de concatenação.
- O grupo ADM Dovemail é `idgrupo = 462` em `consinco.dpc_usuariogrupo`.

---

## Referências cruzadas

- Regras Oracle: [../regras/alterar-codigo/apidpc-oracle-padroes.md](../regras/alterar-codigo/apidpc-oracle-padroes.md)
- Fluxo de migração: [../regras/gerenciar-regras/migracao-legado.md](../regras/gerenciar-regras/migracao-legado.md)
- Planejamento da tarefa: [d:/.claude-work-items/cards/3080-gestao-licencas/planejamento.md](../../../../.claude-work-items/cards/3080-gestao-licencas/planejamento.md)
