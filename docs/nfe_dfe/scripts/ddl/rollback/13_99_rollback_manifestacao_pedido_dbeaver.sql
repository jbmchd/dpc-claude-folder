-- ===========================================================================
--  ROLLBACK DO BLOCO 13_01 - remove o pedido de manifestacao em massa
-- ===========================================================================
--
--  DESTRUTIVO: apaga TODO o historico de pedidos (quem pediu, quando, as
--  contagens de aceitas e recusadas, os cancelamentos). Esse historico nao
--  deriva de nenhum outro dado - as linhas de manifestacao ficam, mas deixam
--  de dizer de qual pedido vieram.
--
--  NAO apaga linhas de dpc_dfe_manifestacao. Linhas P (na fila) que ainda
--  existam ficam la, e o dfe:manifestar --fila deixa de ser agendado junto com
--  o codigo: se sobrarem P, elas simplesmente nao saem. Cancele os pedidos
--  ativos ANTES, pela tela, ou apague as P na mao.
--
--  ORDEM: reverter ANTES o codigo (ApiNFE grava a coluna e a ApiDPC a le na
--  listagem de NF-e). Com a coluna removida e o codigo novo no ar, a listagem
--  de NF-e da ORA-00904.
--
--  Rodar no DBeaver com Execute script (Alt+X).
-- ===========================================================================


drop index poseidon.DPC_DFE_MANIF_IX2;

alter table poseidon.dpc_dfe_manifestacao drop constraint DPC_DFE_MANIF_FK2;

alter table poseidon.dpc_dfe_manifestacao drop column cod_dfe_manif_pedido;

drop table poseidon.dpc_dfe_manif_pedido purge;


-- ===========================================================================
--  CONFERENCIA - esperado: nenhuma linha
-- ===========================================================================

select 'tabela' tipo, table_name nome
  from all_tables
 where owner = 'POSEIDON' and table_name = 'DPC_DFE_MANIF_PEDIDO'
union all
select 'coluna', column_name
  from all_tab_columns
 where owner = 'POSEIDON' and table_name = 'DPC_DFE_MANIFESTACAO'
   and column_name = 'COD_DFE_MANIF_PEDIDO'
union all
select 'indice', index_name
  from all_indexes
 where owner = 'POSEIDON' and index_name = 'DPC_DFE_MANIF_IX2';
