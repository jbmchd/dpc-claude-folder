-- ============================================================================
--  ROLLBACK - REPROCESSAR OS CT-e (colunas do bloco 09_01)
-- ============================================================================
--  Tira da fila o que este script colocou e que AINDA nao foi processado.
--  O normalizador limpa det_erro ao concluir, entao o carimbo so sobrevive no
--  que esta pendente - e so isso volta para 'C'.
--
--  NAO desfaz o que ja foi gravado nas 15 colunas: para isso, o rollback e o
--  ddl/09_99, que derruba as colunas.
--
--  Rodar bloco a bloco.
-- ============================================================================


-- ============================================================================
--  SECAO 1 - QUANTO AINDA ESTA NA FILA POR CONTA DESTE SCRIPT
-- ============================================================================

select status_process, count(*) as qtd
  from poseidon.dpc_dfe_documento
 where det_erro = 'REPROCESSO 2026-10-03 CTE 09_01'
 group by status_process
 order by 1;


-- ============================================================================
--  SECAO 2 - TIRAR DA FILA
-- ============================================================================

update poseidon.dpc_dfe_documento
   set status_process = 'C',
       det_erro       = null
 where det_erro = 'REPROCESSO 2026-10-03 CTE 09_01'
   and status_process in ('P', 'E');

commit;


-- ============================================================================
--  SECAO 3 - CONFERENCIA (esperado: nenhuma linha)
-- ============================================================================

select status_process, count(*) as qtd
  from poseidon.dpc_dfe_documento
 where det_erro = 'REPROCESSO 2026-10-03 CTE 09_01'
 group by status_process;