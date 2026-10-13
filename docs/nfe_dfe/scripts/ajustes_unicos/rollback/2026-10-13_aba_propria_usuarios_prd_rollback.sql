-- ============================================================================
--  ROLLBACK - ABA "NOTAS PROPRIAS" DA PRODUCAO (13/10/2026)
-- ============================================================================
--  >>> RODAR NA PRODUCAO.
--  Remove a categoria PROPRIAS que 2026-10-13_aba_propria_usuarios_prd deu aos
--  usuarios. Age so nas linhas com o carimbo do ajuste; permissao PROPRIAS
--  concedida depois pela tela fica.
--
--  Conectado como POSEIDON na PRODUCAO.
-- ============================================================================


delete from poseidon.dpc_dfe_usuario_aba
 where aba = 'PROPRIAS'
   and created_by = 'AJUSTE 2026-10-13 ABA PROPRIA PRD';

commit;


--  Esperado: nenhuma linha PROPRIAS (a nao ser as dadas depois pela tela).
select aba, count(*) as usuarios
  from poseidon.dpc_dfe_usuario_aba
 group by aba
 order by 1;
