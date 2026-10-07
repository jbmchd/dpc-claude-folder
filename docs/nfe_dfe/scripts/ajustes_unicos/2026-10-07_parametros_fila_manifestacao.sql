-- ============================================================================
--  MODULO DFe - PARAMETROS DA FILA DE MANIFESTACAO EM MASSA
-- ============================================================================
--  Cria dois parametros em dpc_parametro, lidos por dfe:manifestar --fila e
--  pela rota de pedido. Decisao de 07/10/2026: vazao moderada.
--
--    dfe_manifest_fila_max_ciclo    200   notas por ciclo da fila. O ciclo roda
--                                         a cada 10 min (Kernel.php), ou seja
--                                         ~1.200 notas/h: 5.000 em ~4h.
--    dfe_manifest_fila_max_pedido   5000  maximo de chaves num unico pedido
--                                         (o teto que a Qive oferece).
--
--  A vazao e parametro de proposito: nao se sabe se o RecepcaoEvento tolera
--  um volume maior sem 656 (que trava o CNPJ por 1h). Sobe-se aos poucos,
--  medindo os bloqueios, SEM deploy: basta atualizar o VALOR.
--
--  Reexecutavel: so insere o que ainda nao existe.
--  Conectado como POSEIDON. Rodar secao por secao (Ctrl+Enter).
-- ============================================================================


-- ============================================================================
--  SECAO 0 - FOTO ANTES (esperado: nenhuma linha)
-- ============================================================================

select nome, valor from poseidon.dpc_parametro where nome like 'dfe_manifest_fila%';


-- ============================================================================
--  SECAO 1 - CRIAR
-- ============================================================================

insert into poseidon.dpc_parametro (nome, valor, explicacao)
select 'dfe_manifest_fila_max_ciclo', '200',
       'Notas que a fila de manifestacao em massa envia por ciclo (a cada 10 min). Faixa 1-2000. Subir aos poucos medindo os 656.'
  from dual
 where not exists (select 1 from poseidon.dpc_parametro where nome = 'dfe_manifest_fila_max_ciclo');

insert into poseidon.dpc_parametro (nome, valor, explicacao)
select 'dfe_manifest_fila_max_pedido', '5000',
       'Maximo de chaves em um unico pedido de manifestacao em massa. Faixa 1-20000.'
  from dual
 where not exists (select 1 from poseidon.dpc_parametro where nome = 'dfe_manifest_fila_max_pedido');

commit;


-- ============================================================================
--  SECAO 2 - CONFERENCIA (esperado: 2 linhas, 200 e 5000)
-- ============================================================================

select nome, valor from poseidon.dpc_parametro where nome like 'dfe_manifest_fila%' order by nome;
