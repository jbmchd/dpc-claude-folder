-- ============================================================================
--  MODULO DFe - ROLLBACK DAS FASES 2 A 4 DA MANIFESTACAO (ARQUIVO 04_98)
-- ============================================================================
--  Desfaz SOMENTE o que o 04_02_manifestacao_fases_2a4_dbeaver.sql acrescentou:
--  a coluna dta_inicio_manif_auto_conf de dpc_dfe_empresa e a tabela
--  dpc_dfe_usuario_permissao inteira.
--
--  NAO mexe nas colunas do 04_01 nem na UK de dpc_dfe_manifestacao. Quem faz
--  isso e o 04_99_rollback_manifestacao_dbeaver.sql.
--
--  ==========================================================================
--   LEIA ISTO ANTES
--  ==========================================================================
--  Apagar dpc_dfe_usuario_permissao apaga quem tinha autorizacao para
--  manifestar manualmente pela tela - e um fato de controle de acesso, nao um
--  ato fiscal, mas ainda assim vale medir antes:
--
--      select usuario, permissao, created_by, created_at
--        from poseidon.dpc_dfe_usuario_permissao order by created_at;
--
--  Se a intencao for apenas DESLIGAR a Confirmacao automatica sem apagar o
--  historico de quem tem permissao manual, nao use este script. Feche so a
--  flag da automacao, que preserva tudo:
--
--      update poseidon.dpc_dfe_empresa
--         set status_manif_auto_confirmacao = 'N',
--             updated_at = sysdate, updated_by = 'MANUAL';
--      commit;
--
--  ==========================================================================
--   COMO RODAR (DBeaver)
--  ==========================================================================
--  Conectado como POSEIDON, arquivo INTEIRO com Alt+X. Sem "/" para terminar
--  bloco. CRLF de proposito. LIGUE O DBMS_OUTPUT.
--
--  Reexecutavel: cada drop e guardado por existencia.
-- ============================================================================


-- ============================================================================
--  SECAO 1 - TABELA DPC_DFE_USUARIO_PERMISSAO
-- ============================================================================
declare
  qtd number;
begin
  select count(*) into qtd from all_tables
   where owner = 'POSEIDON' and table_name = 'DPC_DFE_USUARIO_PERMISSAO';

  if qtd > 0 then
    execute immediate 'drop table poseidon.dpc_dfe_usuario_permissao purge';
    dbms_output.put_line('dpc_dfe_usuario_permissao: removida');
  else
    dbms_output.put_line('dpc_dfe_usuario_permissao: nao existe');
  end if;
exception
  when others then
    dbms_output.put_line('DPC_DFE_USUARIO_PERMISSAO: FALHOU -> ' || sqlerrm);
end;

-- ============================================================================
--  SECAO 2 - COLUNA DE DPC_DFE_EMPRESA
-- ============================================================================
declare
  qtd number;
begin
  select count(*) into qtd from all_tab_columns
   where owner = 'POSEIDON' and table_name = 'DPC_DFE_EMPRESA'
     and column_name = 'DTA_INICIO_MANIF_AUTO_CONF';

  if qtd > 0 then
    execute immediate 'alter table poseidon.dpc_dfe_empresa drop column dta_inicio_manif_auto_conf';
    dbms_output.put_line('DPC_DFE_EMPRESA: removida -> dta_inicio_manif_auto_conf');
  else
    dbms_output.put_line('DPC_DFE_EMPRESA: nao existe -> dta_inicio_manif_auto_conf');
  end if;
exception
  when others then
    dbms_output.put_line('DPC_DFE_EMPRESA: FALHOU em dta_inicio_manif_auto_conf -> ' || sqlerrm);
end;

commit;

-- ============================================================================
--  SECAO 3 - CONFERENCIA (o esperado e NENHUMA linha)
-- ============================================================================
select 'coluna sobrando' as tipo, table_name as objeto, column_name as detalhe
  from all_tab_columns
 where owner = 'POSEIDON' and table_name = 'DPC_DFE_EMPRESA'
   and column_name = 'DTA_INICIO_MANIF_AUTO_CONF'
union all
select 'tabela sobrando', table_name, null
  from all_tables
 where owner = 'POSEIDON' and table_name = 'DPC_DFE_USUARIO_PERMISSAO'
 order by 1, 2, 3;
