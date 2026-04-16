# Template — Documentação de domínio Oracle

> Copiar este arquivo para `.claude/docs/db/<dominio>.md` (ex.: `dovemail-edi-projetos.md`) quando iniciar o mapeamento de um novo domínio.
> Uma vez preenchido, vira cache reutilizável entre sessões e evita re-descoberta via MCP.

Renomear este arquivo não. Sempre copiar, mantendo o `_template-dominio.md` intacto.

---

## Domínio: `<nome-do-dominio>`

**Schema(s) envolvido(s):** `<dovemail | consinco | poseidon>`
**Escopo funcional:** <frase curta, ex.: "Cadastro de Projetos EDI e relação com repositórios/pastas FTP">
**Telas do Maracanã que usam:** <lista com caminhos relativos a `workspace/maracana/`>
**Últimas tarefas que tocaram:** <ex.: #3057, #3064>
**Data do mapeamento:** <YYYY-MM-DD>

---

## Diagrama de relacionamento

```
<TABELA_A>.<PK>
    ↓ (FK <coluna>)
<TABELA_B>.<FK>
    ↓
...
```

(substituir por diagrama real — mermaid opcional quando couber)

---

## Tabelas e views

### `<SCHEMA>.<NOME_DA_TABELA_OU_VIEW>`

- **Tipo:** tabela | view
- **PK:** `<coluna>`
- **Sequence associada:** `<schema>.<nome>_pk` (se houver)
- **Origem da view:** <se view, listar tabelas base e filtros conhecidos>

| Coluna | Tipo | Null | Descrição |
|---|---|---|---|
| `COD_X` | NUMBER | NO | PK |
| `DESCRICAO` | VARCHAR2(100) | NO | |
| `STATUS` | VARCHAR2(1) | NO | `A` = Ativo, `I` = Inativo |

**Índices relevantes:** <se conhecidos>
**Observações:** <comportamento do driver, case, ambiguidades já encontradas>

(repetir o bloco para cada tabela/view)

---

## Queries canônicas

Queries já validadas via MCP DPC que o ApiDPC deve reutilizar (ou manter consistentes com o Maracanã).

### `<nome descritivo>`

**Usado em:** `ApiDPC/app/Repositories/<Arquivo>.php::<metodo>()`
**Fonte no Maracanã:** `<caminho relativo>/dal*.vb::<Metodo>`

```sql
SELECT ...
FROM ...
WHERE ...
ORDER BY ...
```

**Notas:** <ex.: usar ORDER BY posicional por causa de alias; normalizar case em PHP; etc.>

---

## Pegadinhas conhecidas

- <listar armadilhas específicas deste domínio — alias que colide com coluna, view que filtra implicitamente, joins com cardinalidade inesperada, etc.>

---

## Referências cruzadas

- Regras Oracle: [../regras/alterar-codigo/apidpc-oracle-padroes.md](../regras/alterar-codigo/apidpc-oracle-padroes.md)
- Fluxo de migração: [../regras/gerenciar-regras/migracao-legado.md](../regras/gerenciar-regras/migracao-legado.md)
