-- ============================================================================
--  ROLLBACK - PARAMETRO DA REPLICACAO HOMOLOG -> PRODUCAO
-- ============================================================================
--  >>> RODAR NA HOMOLOG.
--  Remove dfe_replicacao_prd, criado por 2026-10-07_param_replicacao_prd.
--  Sem o parametro o agendamento entende "desligado" (so 'S' liga), entao
--  remover tambem PARA a replicacao.
--
--  Conectado como POSEIDON.
-- ============================================================================


delete from poseidon.dpc_parametro where lower(nome) = 'dfe_replicacao_prd';

commit;


--  Esperado: nenhuma linha.
select nome, valor from poseidon.dpc_parametro where lower(nome) = 'dfe_replicacao_prd';
