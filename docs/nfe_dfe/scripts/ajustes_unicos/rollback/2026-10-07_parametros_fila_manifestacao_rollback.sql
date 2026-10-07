-- ============================================================================
--  ROLLBACK - PARAMETROS DA FILA DE MANIFESTACAO EM MASSA
-- ============================================================================
--  Remove os dois parametros criados por 2026-10-07_parametros_fila_manifestacao.
--  Sem eles o codigo cai nos defaults (200 por ciclo, 5000 por pedido), entao
--  remover nao desliga a fila: para isso, nao agende o dfe:manifestar --fila.
--
--  Conectado como POSEIDON.
-- ============================================================================


delete from poseidon.dpc_parametro
 where nome in ('dfe_manifest_fila_max_ciclo', 'dfe_manifest_fila_max_pedido');

commit;


--  Esperado: nenhuma linha.
select nome, valor from poseidon.dpc_parametro where nome like 'dfe_manifest_fila%';
