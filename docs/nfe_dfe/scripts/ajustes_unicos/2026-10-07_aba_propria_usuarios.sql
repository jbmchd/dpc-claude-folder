-- ============================================================================
--  MODULO DFe - LIBERA A ABA "Notas proprias - DPC" AOS USUARIOS ATUAIS
-- ============================================================================
--  Da a categoria PROPRIAS a quem ja tem SEM_CLASSIFICACAO em
--  dpc_dfe_usuario_aba. Decisao de 07/10/2026.
--
--  POR QUE ESTES USUARIOS
--  As notas proprias (emitente da raiz do grupo, 66.471.517) saem das demais
--  abas e vao so para a nova. A maior parte delas aparecia em Sem
--  Classificacao (transferencias, 6209 e 2152), entao quem trabalhava la e quem
--  passa a precisar da aba nova. Quem nao receber a permissao NAO ve a aba, e
--  tambem deixa de ver essas notas nas outras: por isso a liberacao automatica.
--  Depois, cada pessoa pode ser ajustada em Sefaz > Parametros.
--
--  Reexecutavel: so insere para quem ainda nao tem. Carimbo unico em
--  created_by ('AJUSTE 2026-10-07 ABA PROPRIA'), que e o que o rollback usa.
--
--  Roda DEPOIS de ddl/14_01 (sem a CHECK nova o insert e recusado).
--  Conectado como POSEIDON. Rodar secao por secao (Ctrl+Enter).
-- ============================================================================


-- ============================================================================
--  SECAO 0 - FOTO ANTES (quantos usuarios por aba)
-- ============================================================================

select aba, count(*) as usuarios
  from poseidon.dpc_dfe_usuario_aba
 group by aba
 order by 1;


-- ============================================================================
--  SECAO 1 - LIBERAR
-- ============================================================================

insert into poseidon.dpc_dfe_usuario_aba (usuario, aba, created_by)
select s.usuario, 'PROPRIAS', 'AJUSTE 2026-10-07 ABA PROPRIA'
  from poseidon.dpc_dfe_usuario_aba s
 where s.aba = 'SEM_CLASSIFICACAO'
   and not exists (select 1 from poseidon.dpc_dfe_usuario_aba x
                    where x.usuario = s.usuario and x.aba = 'PROPRIAS');

commit;


-- ============================================================================
--  SECAO 2 - CONFERENCIA
-- ============================================================================
--  Esperado: PROPRIAS com o mesmo numero de usuarios de SEM_CLASSIFICACAO.

select aba, count(*) as usuarios
  from poseidon.dpc_dfe_usuario_aba
 group by aba
 order by 1;
