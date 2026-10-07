-- ===========================================================================
--  ROLLBACK DO BLOCO 10_01 - volta a CHECK de dsc_tela para NFE/CTE/NFSE
-- ===========================================================================
--
--  APAGA as preferencias de coluna dos relatorios avancados (dsc_tela
--  terminando em _REL) - sem isso o ADD da CHECK antiga falharia com
--  ORA-02293, porque essas linhas nao cabem nela. A preferencia da tela
--  normal (NFE, CTE, NFSE) nao e tocada.
--
--  So faz sentido junto com a reversao do codigo (ApiDPC e DPC) que criou
--  os relatorios avancados.
--
--  Rodar no DBeaver com Execute script (Alt+X).
-- ===========================================================================


delete from poseidon.dpc_dfe_usuario_coluna
 where dsc_tela in ('NFE_REL', 'CTE_REL', 'NFSE_REL');

commit;

alter table poseidon.dpc_dfe_usuario_coluna
  drop constraint DPC_DFE_USUARIO_COLUNA_CK1;

alter table poseidon.dpc_dfe_usuario_coluna
  add constraint DPC_DFE_USUARIO_COLUNA_CK1
  check (dsc_tela in ('NFE', 'CTE', 'NFSE'));


-- ===========================================================================
--  CONFERENCIA - esperado: a condicao so com NFE, CTE, NFSE
-- ===========================================================================

select constraint_name, search_condition_vc
  from all_constraints
 where owner = 'POSEIDON'
   and table_name = 'DPC_DFE_USUARIO_COLUNA'
   and constraint_type = 'C'
   and constraint_name = 'DPC_DFE_USUARIO_COLUNA_CK1';