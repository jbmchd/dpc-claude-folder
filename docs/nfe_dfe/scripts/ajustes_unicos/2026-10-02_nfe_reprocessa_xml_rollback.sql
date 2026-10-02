-- ============================================================================
--  MODULO DFe - ROLLBACK DE 2026-10-02_nfe_reprocessa_xml.sql
-- ============================================================================
--  Tira da fila o que o script colocou e AINDA nao foi processado (carimbo em
--  det_erro), devolvendo ao status anterior.
--
--  O que ja foi reprocessado NAO volta, e nem precisa: o reprocessamento so
--  acrescentou campos que antes eram nulos. Para desfazer a estrutura inteira,
--  usar ddl/08_99_rollback_nfe_satelites_dbeaver.sql.
--
--  Conectado como POSEIDON.
-- ============================================================================

select count(*) as ainda_na_fila
  from poseidon.dpc_dfe_documento
 where det_erro = 'REPROCESSO 2026-10-02 NFE XML'
   and status_process = 'P';

update poseidon.dpc_dfe_documento
   set status_process = 'C',
       det_erro       = null
 where det_erro = 'REPROCESSO 2026-10-02 NFE XML'
   and status_process = 'P';

commit;

--  Esperado: nenhuma linha.
select count(*) as sobraram
  from poseidon.dpc_dfe_documento
 where det_erro = 'REPROCESSO 2026-10-02 NFE XML';
