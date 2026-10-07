-- ============================================================================
--  MODULO DFe - PARAMETRO DA REPLICACAO HOMOLOG -> PRODUCAO
-- ============================================================================
--  >>> RODAR NA HOMOLOG. Na producao este parametro nao existe nem e lido.
--
--  Cria dfe_replicacao_prd em dpc_parametro, lido pelo agendamento do
--  dfe:replicar (ApiNFE, servidor 16). Decisao de 07/10/2026.
--
--    dfe_replicacao_prd   N   'S' liga o sincronismo de 5 em 5 min e a
--                             conferencia noturna das 3h; qualquer outro valor
--                             desliga. Nasce DESLIGADO: ligar e decisao
--                             acompanhada, depois da carga inicial.
--
--  Parar sem deploy: basta UPDATE do valor para 'N'. O comando manual
--  (dfe:replicar --confirmar) nao depende do parametro; so o --agendado.
--
--  Reexecutavel: so insere o que ainda nao existe.
--  Conectado como POSEIDON. Rodar secao por secao (Ctrl+Enter).
-- ============================================================================


-- ============================================================================
--  SECAO 0 - FOTO ANTES (esperado: nenhuma linha)
-- ============================================================================

select nome, valor from poseidon.dpc_parametro where lower(nome) = 'dfe_replicacao_prd';


-- ============================================================================
--  SECAO 1 - CRIAR
-- ============================================================================

insert into poseidon.dpc_parametro (nome, valor, explicacao)
select 'dfe_replicacao_prd', 'N',
       'Modulo DFe (ApiNFE) - liga (S) ou desliga (N) a replicacao agendada homolog -> producao (dfe:replicar --agendado). So existe ate o motor subir em producao. Nasce N: ligar so depois da carga inicial.'
  from dual
 where not exists (select 1 from poseidon.dpc_parametro where lower(nome) = 'dfe_replicacao_prd');

commit;


-- ============================================================================
--  SECAO 2 - CONFERENCIA (esperado: 1 linha, valor N)
-- ============================================================================

select nome, valor from poseidon.dpc_parametro where lower(nome) = 'dfe_replicacao_prd';
