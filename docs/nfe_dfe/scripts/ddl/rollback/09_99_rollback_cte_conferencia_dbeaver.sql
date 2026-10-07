-- ===========================================================================
--  ROLLBACK DO BLOCO 09_01 - CT-e: colunas do Modelo Conferencia Mensal
-- ===========================================================================
--
--  DERRUBA AS 15 COLUNAS E O DADO DENTRO DELAS. O dado volta pelo
--  reprocessamento dos procCTe (dfe:normalizar), que le o XML ja guardado
--  em dpc_dfe_documento - nao precisa consultar a SEFAZ.
--
--  Nenhuma coluna anterior ao bloco 09 e tocada.
--
--  Tambem sem bloco PL/SQL, pelo mesmo motivo do 09_01: o divisor de
--  statements do DBeaver corta bloco. Rodar com a tabela ja limpa devolve
--  ORA-00904 (invalid identifier), que e inofensivo.
--
--  Rodar no DBeaver com Execute script (Alt+X).
-- ===========================================================================


alter table poseidon.dpc_dfe_cte drop (
  dsc_razao_remetente    ,
  dsc_razao_destinat     ,
  dsc_razao_expedidor    ,
  dsc_razao_recebedor    ,
  num_cnpj_tomador4      ,
  dsc_razao_tomador4     ,
  cod_cst_icms           ,
  vlr_bc_icms            ,
  vlr_icms               ,
  pct_icms               ,
  dta_autorizacao        ,
  chave_cte_complementado,
  vlr_ibs_mun            ,
  vlr_ibs_uf             ,
  vlr_cbs                
);


-- ===========================================================================
--  CONFERENCIA
-- ===========================================================================
--  Esperado: nenhuma linha.

select column_name, data_type, data_length, nullable
  from all_tab_columns
 where owner = 'POSEIDON'
   and table_name = 'DPC_DFE_CTE'
   and column_name in (
         'DSC_RAZAO_REMETENTE', 'DSC_RAZAO_DESTINAT', 'DSC_RAZAO_EXPEDIDOR',
         'DSC_RAZAO_RECEBEDOR', 'NUM_CNPJ_TOMADOR4', 'DSC_RAZAO_TOMADOR4',
         'COD_CST_ICMS', 'VLR_BC_ICMS', 'VLR_ICMS',
         'PCT_ICMS', 'DTA_AUTORIZACAO', 'CHAVE_CTE_COMPLEMENTADO',
         'VLR_IBS_MUN', 'VLR_IBS_UF', 'VLR_CBS'
   )
 order by column_name;
