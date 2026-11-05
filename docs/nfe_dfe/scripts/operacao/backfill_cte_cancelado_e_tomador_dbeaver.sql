-- ============================================================================
--  MODULO DFe - CORRECAO UNICA DE CT-e: CANCELADO COMO AUTORIZADO + TOMADOR "OUTROS"
--  (operacao/backfill_cte_cancelado_e_tomador)
-- ============================================================================
--  Dois defeitos do dfe:normalizar, achados em 05/11/2026 a pedido da controladoria. O codigo ja foi corrigido na
--  ApiNFE (DfeCteRepository + DfeCteEventoRepository); este script conserta o que ja estava gravado.
--
--  1) CT-e CANCELADO QUE APARECE COMO AUTORIZADO (coluna Status da tela de CT-e)
--     O evento 110111 chegou ANTES do CT-e (em todos os casos, nro_nsu do evento < nro_nsu do CT-e). O CT-e nasceu com o
--     cStat 100 do protocolo de autorizacao e nada aplicou o cancelamento. A "Data de Cancelamento" da grade vem do
--     evento, por isso aparecia certa com o Status errado. Medido em prd: 287 CT-e em 12 empresas.
--
--  2) CT-e EM "NAO TOMADOS" COM TOMADOR = A PROPRIA EMPRESA
--     Tomador "Outros" (cod_tomador = 4, grupo toma4) nao era comparado ao CNPJ da empresa: o papel saia OUTRO. Medido em
--     prd: 9.747 CT-e (empresas DFe 7, 24, 1 e 21). So vale o CNPJ INTEIRO; toma4 de outra filial da mesma raiz (11.654
--     em prd) continua OUTRO, de proposito.
--
--  QUEM RODA E ONDE: SO COM ORDEM EXPLICITA DO JOABE para producao. Roda primeiro na homolog (mesmo script, sem mudar
--  nada) e depois em prd, conectado como POSEIDON, secao por secao (Ctrl+Enter). As secoes 1 e 4 so leem.
--
--  O CARIMBO (updated_by) diz o que cada linha recebeu, e e o que a secao 5 (desfazer) usa para devolver so o que este
--  script mexeu:   'BACKFILL CTE 2026-11-05 CANC'  = so o cancelamento
--                  'BACKFILL CTE 2026-11-05 TOMA'  = so o papel
--                  'BACKFILL CTE 2026-11-05 CT'    = os dois (o CT-e estava nas duas listas)
--  O desfazer NAO restaura updated_at/updated_by anteriores (nao ha foto delas).
-- ============================================================================


-- ###########################################################################
--  1. FOTO ANTES  (somente leitura)
-- ###########################################################################
select 'cancelado como autorizado' as problema, count(*) as qtd
  from poseidon.dpc_dfe_cte c
 where c.cod_situacao <> 3
   and exists (select 1 from poseidon.dpc_dfe_cte_evento e
                where e.chave_cte = c.chave_cte and e.cod_tipo_evento = '110111');

select 'toma4 = CNPJ da empresa e papel <> TOMA' as problema, count(*) as qtd
  from poseidon.dpc_dfe_cte c
  join poseidon.dpc_dfe_empresa e on e.cod_dfe_empresa = c.cod_dfe_empresa
 where c.cod_tomador = '4'
   and c.num_cnpj_tomador4 = e.num_cnpj
   and c.sig_papel_empresa <> 'TOMA';


-- ###########################################################################
--  2. CANCELADO COMO AUTORIZADO  (mesma regra do motor: so avanca para cancelado, nunca volta)
-- ###########################################################################
update poseidon.dpc_dfe_cte c
   set c.cod_situacao = 3,
       c.dsc_situacao = 'Cancelado',
       c.updated_at   = sysdate,
       c.updated_by   = 'BACKFILL CTE 2026-11-05 CANC'
 where c.cod_situacao <> 3
   and exists (select 1 from poseidon.dpc_dfe_cte_evento e
                where e.chave_cte = c.chave_cte and e.cod_tipo_evento = '110111');
-- Confira o numero de linhas afetadas contra a foto da secao 1 e so entao: commit;


-- ###########################################################################
--  3. TOMADOR "OUTROS" = A EMPRESA  (papel passa a TOMA; so o CNPJ inteiro)
-- ###########################################################################
update poseidon.dpc_dfe_cte c
   set c.sig_papel_empresa = 'TOMA',
       c.updated_at        = sysdate,
       c.updated_by        = case when c.updated_by = 'BACKFILL CTE 2026-11-05 CANC'
                                  then 'BACKFILL CTE 2026-11-05 CT'
                                  else 'BACKFILL CTE 2026-11-05 TOMA' end
 where c.cod_tomador = '4'
   and c.sig_papel_empresa <> 'TOMA'
   and c.num_cnpj_tomador4 = (select e.num_cnpj
                                from poseidon.dpc_dfe_empresa e
                               where e.cod_dfe_empresa = c.cod_dfe_empresa);
-- Confira o numero de linhas afetadas contra a foto da secao 1 e so entao: commit;


-- ###########################################################################
--  4. VALIDACAO  (somente leitura; os dois primeiros devem dar 0)
-- ###########################################################################
select 'cancelado como autorizado' as problema, count(*) as qtd
  from poseidon.dpc_dfe_cte c
 where c.cod_situacao <> 3
   and exists (select 1 from poseidon.dpc_dfe_cte_evento e
                where e.chave_cte = c.chave_cte and e.cod_tipo_evento = '110111')
union all
select 'toma4 = CNPJ da empresa e papel <> TOMA', count(*)
  from poseidon.dpc_dfe_cte c
  join poseidon.dpc_dfe_empresa e on e.cod_dfe_empresa = c.cod_dfe_empresa
 where c.cod_tomador = '4'
   and c.num_cnpj_tomador4 = e.num_cnpj
   and c.sig_papel_empresa <> 'TOMA'
union all
select 'linhas com o carimbo (tocadas por este script)', count(*)
  from poseidon.dpc_dfe_cte
 where updated_by like 'BACKFILL CTE 2026-11-05%';


-- ###########################################################################
--  5. DESFAZER  (devolve so as linhas com o carimbo certo; um CT-e que ja estava cancelado antes do script e so
--     recebeu o papel tem carimbo TOMA e NAO e tocado por 5a)
--     5a: o cancelamento volta a AUTORIZADO;  5b: o papel volta a OUTRO (era OUTRO em todas as linhas da foto)
-- ###########################################################################
-- 5a)
-- update poseidon.dpc_dfe_cte
--    set cod_situacao = 1, dsc_situacao = 'AUTORIZADO'
--  where updated_by in ('BACKFILL CTE 2026-11-05 CANC', 'BACKFILL CTE 2026-11-05 CT')
--    and cod_situacao = 3;
-- 5b)
-- update poseidon.dpc_dfe_cte
--    set sig_papel_empresa = 'OUTRO'
--  where updated_by in ('BACKFILL CTE 2026-11-05 TOMA', 'BACKFILL CTE 2026-11-05 CT')
--    and cod_tomador = '4'
--    and sig_papel_empresa = 'TOMA';
