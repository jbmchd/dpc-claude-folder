-- ============================================================================
--  MODULO DFe - ABA "NOTAS PROPRIAS" PARA OS USUARIOS DA PRODUCAO (13/10/2026)
-- ============================================================================
--  >>> RODAR NA PRODUCAO (versao do 2026-10-07_aba_propria_usuarios, que foi
--  >>> feito para a homolog). Aplicado em producao em 13/10/2026, a pedido.
--
--  Da a categoria PROPRIAS a quem ja tem SEM_CLASSIFICACAO em
--  poseidon.dpc_dfe_usuario_aba. Sem isso, depois do deploy da ApiDPC com a
--  aba nova, a nota de emitente da raiz do grupo (66.471.517 - transferencia
--  entre filiais) SAI de todas as outras abas e o usuario nao ve a aba nova:
--  a tela segue funcionando, so some a nota, sem mensagem de erro.
--
--  FOTO ANTES (producao, 13/10/2026): 16 permissoes de 4 usuarios, todos com
--  COMPRAS, DEVOLUCAO, SEM_CLASSIFICACAO e SUPRIMENTOS e nenhum com PROPRIAS:
--  DOUGLAS, LEONARDO, SERGIOSANTOS, WARLITON.
--
--  Roda DEPOIS de ddl/14_01 (a CHECK precisa aceitar PROPRIAS).
--  O carimbo 'AJUSTE 2026-10-13 ABA PROPRIA PRD' em created_by e o que o
--  rollback usa para achar as linhas: permissao dada depois pela tela nao leva
--  o carimbo e fica.
--  Reexecutavel: so insere para quem ainda nao tem.
--  Conectado como POSEIDON na PRODUCAO. Rodar secao por secao (Ctrl+Enter).
-- ============================================================================


-- ============================================================================
--  SECAO 0 - FOTO ANTES (esperado em producao: nenhuma linha PROPRIAS)
-- ============================================================================

select aba, count(*) as usuarios
  from poseidon.dpc_dfe_usuario_aba
 group by aba
 order by 1;


-- ============================================================================
--  SECAO 1 - LIBERAR
-- ============================================================================

insert into poseidon.dpc_dfe_usuario_aba (usuario, aba, created_by)
select s.usuario, 'PROPRIAS', 'AJUSTE 2026-10-13 ABA PROPRIA PRD'
  from poseidon.dpc_dfe_usuario_aba s
 where s.aba = 'SEM_CLASSIFICACAO'
   and not exists (select 1 from poseidon.dpc_dfe_usuario_aba x
                    where x.usuario = s.usuario and x.aba = 'PROPRIAS');

commit;


-- ============================================================================
--  SECAO 2 - CONFERENCIA
-- ============================================================================
--  Esperado: PROPRIAS com o mesmo numero de usuarios de SEM_CLASSIFICACAO (4).

select aba, count(*) as usuarios
  from poseidon.dpc_dfe_usuario_aba
 group by aba
 order by 1;
