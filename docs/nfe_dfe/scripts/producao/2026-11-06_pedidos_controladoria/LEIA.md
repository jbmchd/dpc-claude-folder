# Pacote de produção — pedidos da controladoria (03/11/2026)

Só as **alterações de banco** dos PRs ApiNFE #18, ApiDPC #1087 e DPC #1312. Comandos avulsos, prontos para o DBeaver, conectado como `POSEIDON`. Os três arquivos rodaram antes na **homologação**.

## Ordem

| # | Arquivo | Quando | O que faz |
|---|---|---|---|
| 1 | `01_check_pedido_massa_4_eventos.sql` | **antes** do deploy da ApiNFE | `CHECK` de `dpc_dfe_manif_pedido` passa a aceitar os 4 eventos (210210, 210200, 210220, 210240) |
| 2 | `02_tabela_desacordo_cte.sql` | **antes** do deploy da ApiNFE | cria `dpc_dfe_cte_desacordo` (trilha do desacordo do CT-e): tabela, PK, FK, CHECK, índice e comentários |
| — | deploy: **ApiNFE → ApiDPC → DPC** | | |
| 3 | `03_backfill_cte_cancelado_e_tomador.sql` | **depois** do deploy da ApiNFE, **só com ordem do Joabe** | corrige os CT-e já gravados: 287 cancelados que aparecem como autorizados e 9.747 de tomador "Outros" em "Não tomados" |

## Cuidados

- **1 e 2** podem rodar sem parar nada: não mexem em dado, só na estrutura. O 2 não é reexecutável (o `CREATE TABLE` falha se a tabela já existir); o 1 pode ser repetido.
- **3** altera dado (2 `update`, secção a secção, com `commit` manual): confira o número de linhas contra a foto da secção 1 antes do `commit`. Cada linha tocada leva um carimbo em `updated_by` (`BACKFILL CTE 2026-11-05 CANC/TOMA/CT`), e o desfazer, comentado no fim, usa esse carimbo. Os números de produção foram medidos em 05/11/2026 e podem ter crescido: o importante é a validação da secção 4 dar 0.
- Cada arquivo traz o **desfazer** no rodapé, comentado.
- **Conferência depois de aplicar 1 e 2:** `dfe:replicar --estrutura` (compara pelo dicionário a estrutura da homologação com a de produção, inclusive a condição das `CHECK`) deve dar **zero diferenças**.

## Onde estão as versões completas

O que **não** é "só a alteração" continua em `../../ddl/`: `01_estrutura_motor_dbeaver.sql` (instalador inteiro, já com o `CHECK` novo) e `05_desacordo_cte_dbeaver.sql` (a mesma tabela, em versão convergente que pode rodar várias vezes), com o `rollback/05_99_...`. O `03_backfill...` desta pasta é cópia de `../operacao/backfill_cte_cancelado_e_tomador_dbeaver.sql`.
