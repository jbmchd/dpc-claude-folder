-- ============================================================================
--  ROLLBACK - PARAMETROS dfe_* (ddl/rollback/03_99_rollback_parametros)
-- ============================================================================
--  Remove as 11 linhas dfe_* que o 03_parametros carrega. Sem elas o codigo cai nos defaults internos - e dois
--  deles MUDAM comportamento em silencio (o freio de emergencia e o teto de consultas). Nao e "desligar o motor":
--  para parar a captura, pause os cursores (operacao/pausa_empresas).
--
--  Nao toca em dfe_conexao_erp nem em dfe_replicacao_prd (homolog/02_parametros_homolog).
--  Conectado como POSEIDON.
-- ============================================================================


-- ###########################################################################
--  1. FOTO ANTES
-- ###########################################################################
select nome, valor from poseidon.dpc_parametro where lower(nome) like 'dfe%' order by nome;

-- ###########################################################################
--  2. APAGA
-- ###########################################################################
delete from poseidon.dpc_parametro
 where lower(nome) in ('dfe_manifest_fila_max_ciclo',
                       'dfe_manifest_fila_max_pedido',
                       'dfe_manifest_max_ciclo',
                       'dfe_manifest_max_lote',
                       'dfe_manifest_pausa_seg',
                       'dfe_max_bloqueios_cnpj',
                       'dfe_max_bloqueios_dia',
                       'dfe_max_bloqueios_manifest',
                       'dfe_max_consultas',
                       'dfe_min_backoff_656',
                       'dfe_pausa_seg');
commit;

-- ###########################################################################
--  3. CONFERENCIA (esperado: so os que nao sao do 03)
-- ###########################################################################
select nome, valor from poseidon.dpc_parametro where lower(nome) like 'dfe%' order by nome;
