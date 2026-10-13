-- ============================================================================
--  MODULO DFe - PAUSA COMPLETA DE EMPRESAS (operacao/pausa_empresas)
-- ============================================================================
--  Pausa completa = captura E manifestacao, de uma vez:
--    - os 4 cursores de cada empresa (NFE, CTE, MDFE, NFSE) em P
--    - status_manifestar, Ciencia automatica e Confirmacao automatica em N
--
--  O P resiste a uma execucao que ja estava drenando quando a pausa foi gravada: o DfeCursorRepository mantem P como P
--  ao registrar consulta. Para PAUSAR so a captura ou so a manifestacao, edite os updates da secao 2 (so o que o pedido
--  nomear); sem especificar, a pausa e a completa.
--
--  COMO USAR: troque a lista de empresas (nro_empresa) nos QUATRO lugares marcados com "EDITE" (secoes 1, 2 e 3).
--  O carimbo em updated_by leva a data do dia (PAUSA COMPLETA AAAA-MM-DD) e e o que operacao/retomada_empresas usa
--  para devolver as empresas ao estado de antes - so onde o carimbo ainda vale.
--
--  PRAZO QUE CORRE DURANTE A PAUSA: Ciencia = 10 dias da AUTORIZACAO (NT 2020.001); nota que so tem resumo e passa da
--  janela fica sem XML completo (cStat 596). Captura: a SEFAZ segura 90 dias e o ADN guarda historico - nada se perde
--  no curto prazo.
--
--  Roda onde o MOTOR esta (hoje, a homolog). Conectado como POSEIDON, secao por secao (Ctrl+Enter).
-- ============================================================================


-- ###########################################################################
--  1. FOTO ANTES  (guarde o resultado: e o que a retomada devolve)
-- ###########################################################################
select e.nro_empresa, e.status_manifestar, e.status_manif_auto_ciencia, e.status_manif_auto_confirmacao,
       listagg(c.cod_tipo_dfe || '=' || c.status_sincronismo, ' ') within group (order by c.cod_tipo_dfe) as cursores
  from poseidon.dpc_dfe_empresa e
  join poseidon.dpc_dfe_cursor c on c.cod_dfe_empresa = e.cod_dfe_empresa
 where e.nro_empresa in (17, 20, 29, 30)   -- EDITE: lista de empresas
 group by e.nro_empresa, e.status_manifestar, e.status_manif_auto_ciencia, e.status_manif_auto_confirmacao
 order by 1;

-- ###########################################################################
--  2. PAUSA
-- ###########################################################################
update poseidon.dpc_dfe_cursor
   set status_sincronismo = 'P',
       updated_by = 'PAUSA COMPLETA ' || to_char(sysdate, 'YYYY-MM-DD'),
       updated_at = sysdate
 where cod_dfe_empresa in (select cod_dfe_empresa from poseidon.dpc_dfe_empresa
                            where nro_empresa in (17, 20, 29, 30))   -- EDITE: lista de empresas
   and status_sincronismo <> 'P';

update poseidon.dpc_dfe_empresa
   set status_manifestar = 'N',
       status_manif_auto_ciencia = 'N',
       status_manif_auto_confirmacao = 'N',
       updated_by = 'PAUSA COMPLETA ' || to_char(sysdate, 'YYYY-MM-DD'),
       updated_at = sysdate
 where nro_empresa in (17, 20, 29, 30);   -- EDITE: lista de empresas

commit;

-- ###########################################################################
--  3. CONFERENCIA  (esperado: todos os cursores P, manifestacao N/N/N)
-- ###########################################################################
select e.nro_empresa, e.status_manifestar, e.status_manif_auto_ciencia, e.status_manif_auto_confirmacao, e.updated_by,
       listagg(c.cod_tipo_dfe || '=' || c.status_sincronismo, ' ') within group (order by c.cod_tipo_dfe) as cursores
  from poseidon.dpc_dfe_empresa e
  join poseidon.dpc_dfe_cursor c on c.cod_dfe_empresa = e.cod_dfe_empresa
 where e.nro_empresa in (17, 20, 29, 30)   -- EDITE: lista de empresas
 group by e.nro_empresa, e.status_manifestar, e.status_manif_auto_ciencia, e.status_manif_auto_confirmacao, e.updated_by
 order by 1;

--  E na base inteira: quantos cursores seguem ativos (A).
select status_sincronismo, count(*) as cursores from poseidon.dpc_dfe_cursor group by status_sincronismo order by 1;
