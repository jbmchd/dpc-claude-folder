-- ============================================================================
--  MODULO DFe - ROLLBACK DE 2026-10-02_nfse_reprocessa.sql
-- ============================================================================
--  Tira da fila o que o script colocou e AINDA nao foi processado (carimbo
--  em det_erro), devolvendo ao status anterior.
--
--  O que ja foi reprocessado nao volta: o normalizador regravou a NFS-e a
--  partir do bruto, e a situacao antiga era o defeito. Para desfazer as
--  colunas novas, usar ddl/07_99_rollback_nfse_tipo_emissao_dbeaver.sql.
--
--  Conectado como POSEIDON.
-- ============================================================================

select dsc_tipo_doc, count(*) as ainda_na_fila
  from poseidon.dpc_dfe_documento
 where det_erro = 'REPROCESSO 2026-10-02 NFSE'
   and status_process = 'P'
 group by dsc_tipo_doc;

-- adnEvento que estava IGNORADO (evento antes da nota) volta a I; o resto a C.
-- Nao ha como saber qual era qual depois do update, entao o evento orfao volta
-- a C: o proximo reprocessamento manual o recoloca em I sozinho.
update poseidon.dpc_dfe_documento
   set status_process = 'C',
       det_erro       = null
 where det_erro = 'REPROCESSO 2026-10-02 NFSE'
   and status_process = 'P';

commit;
