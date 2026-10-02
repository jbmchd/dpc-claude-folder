-- ============================================================================
--  MODULO DFe - PAUSA COMPLETA DAS EMPRESAS 17, 20, 29 E 30
-- ============================================================================
--  >>> JA APLICADO em homolog em 02/10/2026, a pedido. Este arquivo
--  >>> registra o que foi feito; a retomada e o _rollback ao lado.
--
--  Pausa completa = captura E manifestacao, de uma vez:
--    - os 4 cursores de cada empresa (NFE, CTE, MDFE, NFSE) em 'P'
--    - status_manifestar, Ciencia automatica e Confirmacao automatica em 'N'
--
--  O 'P' resiste a uma execucao que ja estava drenando quando a pausa foi
--  gravada: DfeCursorRepository mantem P como P ao registrar consulta.
--
--  ==========================================================================
--   FOTO ANTES (medida no momento da pausa)
--  ==========================================================================
--    16 cursores, todos 'A'.
--    empresa  status_manifestar  auto_ciencia  auto_confirmacao  updated_by
--      17            S                S              N           REATIVACAO MANUAL
--      20            S                S              N           REATIVACAO MANUAL
--      29            S                S              N           REATIVACAO MANUAL
--      30            S                S              N           REATIVACAO MANUAL
--
--  ==========================================================================
--   PRAZO QUE CORRE DURANTE A PAUSA
--  ==========================================================================
--  Ciencia: 10 dias da AUTORIZACAO (NT 2020.001). Nota que so tem resumo e
--  passa da janela fica sem XML completo (cStat 596). Captura: a SEFAZ
--  segura 90 dias e o ADN guarda historico - nada se perde no curto prazo.
--
--  Resultado: 16 cursores pausados, 4 empresas com manifestacao desligada,
--  0 cursores ativos na base.
-- ============================================================================

update poseidon.dpc_dfe_cursor
   set status_sincronismo = 'P',
       updated_by = 'PAUSA COMPLETA 2026-10-02',
       updated_at = sysdate
 where cod_dfe_empresa in (select cod_dfe_empresa from poseidon.dpc_dfe_empresa
                            where nro_empresa in (17, 20, 29, 30))
   and status_sincronismo <> 'P';

update poseidon.dpc_dfe_empresa
   set status_manifestar = 'N',
       status_manif_auto_ciencia = 'N',
       status_manif_auto_confirmacao = 'N',
       updated_by = 'PAUSA COMPLETA 2026-10-02',
       updated_at = sysdate
 where nro_empresa in (17, 20, 29, 30);

commit;
