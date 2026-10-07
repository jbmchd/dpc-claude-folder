-- ===========================================================================
--  ROLLBACK DO BLOCO 14_01 - dpc_dfe_usuario_aba volta a recusar PROPRIAS
-- ===========================================================================
--
--  APAGA as permissoes PROPRIAS ja concedidas: sem isso a CHECK antiga nao
--  volta (o add constraint falha com ORA-02293 na primeira linha que a
--  violar). Cada usuario perde a aba "Notas proprias - DPC"; nada mais.
--
--  ORDEM: reverter ANTES o codigo (ApiDPC e DPC). Com a CHECK antiga e o codigo
--  novo no ar, conceder a aba pela tela de Parametros da erro.
--
--  Rodar no DBeaver com Execute script (Alt+X).
-- ===========================================================================


delete from poseidon.dpc_dfe_usuario_aba
 where aba = 'PROPRIAS';

commit;

alter table poseidon.dpc_dfe_usuario_aba
  drop constraint DPC_DFE_USUARIO_ABA_CK1;

alter table poseidon.dpc_dfe_usuario_aba
  add constraint DPC_DFE_USUARIO_ABA_CK1
  check (aba in ('DEVOLUCAO', 'COMPRAS', 'SUPRIMENTOS', 'SEM_CLASSIFICACAO'));


-- ===========================================================================
--  CONFERENCIA - esperado: a condicao so com as quatro categorias antigas
-- ===========================================================================

select constraint_name, search_condition_vc
  from all_constraints
 where owner = 'POSEIDON'
   and table_name = 'DPC_DFE_USUARIO_ABA'
   and constraint_type = 'C'
   and constraint_name = 'DPC_DFE_USUARIO_ABA_CK1';
