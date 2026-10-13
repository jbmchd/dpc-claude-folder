-- ============================================================================
--  MODULO DFe - PARAMETROS SO DA HOMOLOG (homolog/02_parametros_homolog)
-- ============================================================================
--  >>> RODAR NA HOMOLOG. Na PRODUCAO estes dois parametros NAO podem existir.
--
--   dfe_conexao_erp   nome da conexao do ApiNFE onde mora o ERP que a conciliacao consulta. A homolog aponta para
--                     a de producao porque o clone dela esta congelado (sem ele, TODA nota parece nao lancada).
--   dfe_replicacao_prd  S liga o sincronismo de 5 em 5 min e a conferencia das 3h (dfe:replicar --agendado);
--                     qualquer outro valor desliga. Nasce N. Parar sem deploy: update do valor para N.
--                     Some do mapa quando o motor subir em producao.
--
--  So insere o que falta; nunca atualiza. Conectado como POSEIDON na HOMOLOG.
-- ============================================================================


-- ###########################################################################
--  SECAO 0 - FOTO ANTES
-- ###########################################################################
select nome, valor from poseidon.dpc_parametro where lower(nome) in ('dfe_conexao_erp', 'dfe_replicacao_prd') order by nome;

-- ###########################################################################
--  SECAO 1 - INSERE
-- ###########################################################################
insert into poseidon.dpc_parametro (nome, valor, explicacao)
select 'dfe_conexao_erp', 'oracle',
       'Modulo DFe (ApiNFE) - nome da conexao de banco de onde o dfe:conciliar le as tabelas de recebimento do Consinco (mlf_auxnotafiscal, mlf_notafiscal, rf_notamestre) para descobrir a etapa da nota no ERP'
    || '. Valores validos: os nomes configurados na ApiNFE - oracle (producao) e oracle_tst (homologacao). DEVE APONTAR PARA PRODUCAO mesmo rodando em homologacao: as tabelas do Consinco que valem sao as de p'
    || 'roducao, e homologacao e clone congelado. Sem esta linha o codigo usa a conexao corrente, e em homologacao isso faz TODA nota parecer nao lancada. Consequencia operacional: rodando em homologacao, um '
    || 'job de 30 minutos le producao - e leitura, nunca escrita.'
  from dual
 where not exists (select 1 from poseidon.dpc_parametro where lower(nome) = 'dfe_conexao_erp');

insert into poseidon.dpc_parametro (nome, valor, explicacao)
select 'dfe_replicacao_prd', 'N',
       'Modulo DFe (ApiNFE) - liga (S) ou desliga (N) a replicacao agendada homolog -> producao (dfe:replicar --agendado). So existe ate o motor subir em producao. Nasce N: ligar so depois da carga inicial.'
  from dual
 where not exists (select 1 from poseidon.dpc_parametro where lower(nome) = 'dfe_replicacao_prd');

commit;

-- ###########################################################################
--  SECAO 2 - CONFERENCIA (esperado: 2 linhas)
-- ###########################################################################
select nome, valor from poseidon.dpc_parametro where lower(nome) in ('dfe_conexao_erp', 'dfe_replicacao_prd') order by nome;
