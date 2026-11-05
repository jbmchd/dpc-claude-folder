-- ============================================================================
--  MODULO DFe - ROLLBACK DO INSTALADOR 05 (poseidon.dpc_dfe_cte_desacordo)
-- ============================================================================
--  Derruba SO a tabela da trilha de desacordo do CT-e. NAO mexe em dpc_dfe_cte nem em dpc_dfe_cte_evento: o evento
--  610110 que a SEFAZ devolveu pela distribuicao fica la, e e de la que a coluna "Desacordo" da tela de CT-e le.
--
--  ATENCAO: apaga a TRILHA (quem mandou, justificativa, retorno de cada tentativa). Faca a copia antes se houver linhas:
--    create table poseidon.bkp_dpc_dfe_cte_desacordo as select * from poseidon.dpc_dfe_cte_desacordo;
--
--  Conectado como POSEIDON.
-- ============================================================================

declare
  qtd number;
begin
  select count(*) into qtd from all_tables
   where owner = 'POSEIDON' and table_name = 'DPC_DFE_CTE_DESACORDO';
  if qtd > 0 then
    execute immediate 'drop table poseidon.dpc_dfe_cte_desacordo cascade constraints purge';
    dbms_output.put_line('DPC_DFE_CTE_DESACORDO: removida');
  end if;
end;
/
