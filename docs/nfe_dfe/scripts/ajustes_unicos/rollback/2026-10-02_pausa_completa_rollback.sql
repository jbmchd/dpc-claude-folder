-- ============================================================================
--  MODULO DFe - RETOMADA DA PAUSA COMPLETA DE 02/10/2026 (rollback)
-- ============================================================================
--  Devolve as empresas 17, 20, 29 e 30 ao estado da foto do arquivo ao lado:
--  cursores 'A', manifestacao 'S', Ciencia automatica 'S', Confirmacao
--  automatica 'N'.
--
--  Age so no que ainda tem o carimbo da pausa. Se alguem mexeu numa empresa
--  depois dela, aquela linha fica como esta - e a SECAO 1 mostra.
--
--  dta_liberado_em nao e tocado: o cooldown que estava valendo segue valendo,
--  e consultar logo apos retomar nao repete requisicao recente (a ultima foi
--  antes da pausa).
--
--  Conectado como POSEIDON.
-- ============================================================================


-- SECAO 1 - O QUE VAI VOLTAR

select e.nro_empresa, c.cod_tipo_dfe, c.status_sincronismo, c.updated_by
  from poseidon.dpc_dfe_cursor c
  join poseidon.dpc_dfe_empresa e on e.cod_dfe_empresa = c.cod_dfe_empresa
 where e.nro_empresa in (17, 20, 29, 30)
 order by 1, 2;


-- SECAO 2 - RETOMADA

update poseidon.dpc_dfe_cursor
   set status_sincronismo = 'A',
       updated_by = 'RETOMADA PAUSA 2026-10-02',
       updated_at = sysdate
 where updated_by = 'PAUSA COMPLETA 2026-10-02'
   and status_sincronismo = 'P';

update poseidon.dpc_dfe_empresa
   set status_manifestar = 'S',
       status_manif_auto_ciencia = 'S',
       status_manif_auto_confirmacao = 'N',
       updated_by = 'RETOMADA PAUSA 2026-10-02',
       updated_at = sysdate
 where updated_by = 'PAUSA COMPLETA 2026-10-02';

commit;


-- SECAO 3 - CONFERENCIA (esperado: 16 cursores A, 4 empresas S/S/N)

select e.nro_empresa, e.status_manifestar, e.status_manif_auto_ciencia,
       e.status_manif_auto_confirmacao,
       listagg(c.cod_tipo_dfe || '=' || c.status_sincronismo, ' ')
         within group (order by c.cod_tipo_dfe) as cursores
  from poseidon.dpc_dfe_empresa e
  join poseidon.dpc_dfe_cursor c on c.cod_dfe_empresa = e.cod_dfe_empresa
 where e.nro_empresa in (17, 20, 29, 30)
 group by e.nro_empresa, e.status_manifestar, e.status_manif_auto_ciencia,
          e.status_manif_auto_confirmacao
 order by 1;
