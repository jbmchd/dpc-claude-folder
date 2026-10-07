-- ============================================================================
--  ROLLBACK - CFOP DO XML NAS NOTAS (dpc_dfe_nota.cod_cfop_xml)
-- ============================================================================
--  Zera cod_cfop_xml das linhas que o ajuste 2026-10-06_nota_cfop_xml.sql
--  preencheu (carimbo 'AJUSTE 2026-10-06 CFOP XML' em updated_by).
--
--  NAO toca as notas que a ApiNFE gravou sozinha, depois do deploy: elas nao
--  levam o carimbo. updated_by das linhas desfeitas continua com o carimbo -
--  o valor anterior nao era guardado, e era sempre 'DFE NORMALIZAR' ou nulo.
--
--  Para remover a coluna de vez, use ddl/rollback/12_99_rollback_nota_cfop_xml.
--  Nada aqui e dado de origem: o ajuste pode ser rodado de novo.
--
--  Conectado como POSEIDON.
-- ============================================================================


update poseidon.dpc_dfe_nota
   set cod_cfop_xml = null
 where updated_by = 'AJUSTE 2026-10-06 CFOP XML';

commit;


--  Esperado: nenhuma linha com o carimbo e com a coluna preenchida.
select count(*) as com_carimbo_e_preenchida
  from poseidon.dpc_dfe_nota
 where updated_by = 'AJUSTE 2026-10-06 CFOP XML'
   and cod_cfop_xml is not null;
