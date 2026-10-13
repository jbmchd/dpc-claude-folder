-- ============================================================================
--  MODULO DFe - RETOMADA DE EMPRESAS PAUSADAS (operacao/retomada_empresas)
-- ============================================================================
--  Devolve as empresas pausadas por operacao/pausa_empresas ao estado de antes: cursores A, manifestacao S, Ciencia
--  automatica S, Confirmacao automatica N (o estado padrao das 4 empresas em uso). Se a FOTO ANTES da pausa era
--  outra, ajuste os valores do update da secao 2.
--
--  Age so no que ainda tem o carimbo "PAUSA COMPLETA ..." em updated_by. Se alguem mexeu numa empresa depois da pausa,
--  aquela linha fica como esta - e a SECAO 1 mostra.
--  dta_liberado_em nao e tocado: o cooldown que estava valendo segue valendo, e consultar logo apos retomar nao repete
--  requisicao recente. Retome UMA empresa por vez quando o fluxo for grande (ver o aviso de drenagem nos arquivos de
--  homolog/empresas). Conectado como POSEIDON, secao por secao (Ctrl+Enter).
-- ============================================================================


-- ###########################################################################
--  1. O QUE VAI VOLTAR
-- ###########################################################################
select e.nro_empresa, c.cod_tipo_dfe, c.status_sincronismo, c.updated_by
  from poseidon.dpc_dfe_cursor c
  join poseidon.dpc_dfe_empresa e on e.cod_dfe_empresa = c.cod_dfe_empresa
 where c.updated_by like 'PAUSA COMPLETA %' and c.status_sincronismo = 'P'
 order by 1, 2;

-- ###########################################################################
--  2. RETOMADA
-- ###########################################################################
update poseidon.dpc_dfe_cursor
   set status_sincronismo = 'A',
       updated_by = 'RETOMADA DA ' || updated_by,
       updated_at = sysdate
 where updated_by like 'PAUSA COMPLETA %' and status_sincronismo = 'P';

update poseidon.dpc_dfe_empresa
   set status_manifestar = 'S',
       status_manif_auto_ciencia = 'S',
       status_manif_auto_confirmacao = 'N',
       updated_by = 'RETOMADA DA ' || updated_by,
       updated_at = sysdate
 where updated_by like 'PAUSA COMPLETA %';

commit;

-- ###########################################################################
--  3. CONFERENCIA  (esperado: cursores A, manifestacao S/S/N nas empresas retomadas)
-- ###########################################################################
select e.nro_empresa, e.status_manifestar, e.status_manif_auto_ciencia, e.status_manif_auto_confirmacao, e.updated_by,
       listagg(c.cod_tipo_dfe || '=' || c.status_sincronismo, ' ') within group (order by c.cod_tipo_dfe) as cursores
  from poseidon.dpc_dfe_empresa e
  join poseidon.dpc_dfe_cursor c on c.cod_dfe_empresa = e.cod_dfe_empresa
 where e.updated_by like 'RETOMADA DA PAUSA%'
 group by e.nro_empresa, e.status_manifestar, e.status_manif_auto_ciencia, e.status_manif_auto_confirmacao, e.updated_by
 order by 1;
