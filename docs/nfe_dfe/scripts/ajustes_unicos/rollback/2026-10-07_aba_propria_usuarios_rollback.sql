-- ============================================================================
--  ROLLBACK - LIBERACAO DA ABA "Notas proprias - DPC"
-- ============================================================================
--  Remove a permissao PROPRIAS que 2026-10-07_aba_propria_usuarios concedeu
--  (carimbo 'AJUSTE 2026-10-07 ABA PROPRIA' em created_by). Permissao que alguem
--  deu depois, pela tela de Parametros, nao leva o carimbo e fica.
--
--  Conectado como POSEIDON.
-- ============================================================================


delete from poseidon.dpc_dfe_usuario_aba
 where aba = 'PROPRIAS'
   and created_by = 'AJUSTE 2026-10-07 ABA PROPRIA';

commit;


--  Esperado: nenhuma linha com o carimbo.
select count(*) as com_carimbo
  from poseidon.dpc_dfe_usuario_aba
 where created_by = 'AJUSTE 2026-10-07 ABA PROPRIA';
