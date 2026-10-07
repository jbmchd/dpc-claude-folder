-- ===========================================================================
--  ROLLBACK DO BLOCO 12_01 - remove cod_cfop_xml de poseidon.dpc_dfe_nota
-- ===========================================================================
--
--  Perde o CFOP-do-XML gravado. Nao e dado de origem: da para recalcular a
--  qualquer momento a partir de dpc_dfe_nota_item (ajuste unico
--  2026-10-06_nota_cfop_xml.sql), entao o rollback e seguro.
--
--  ORDEM: reverter ANTES o codigo (ApiDPC le a coluna no CASE de categoria e a
--  ApiNFE a grava). Com a coluna removida e o codigo antigo no ar, a tela
--  Gestao de NFe devolve ORA-00904.
--
--  Rodar no DBeaver com Execute script (Alt+X).
-- ===========================================================================


alter table poseidon.dpc_dfe_nota drop column cod_cfop_xml;


-- ===========================================================================
--  CONFERENCIA - esperado: nenhuma linha
-- ===========================================================================

select column_name
  from all_tab_columns
 where owner = 'POSEIDON' and table_name = 'DPC_DFE_NOTA' and column_name = 'COD_CFOP_XML';
