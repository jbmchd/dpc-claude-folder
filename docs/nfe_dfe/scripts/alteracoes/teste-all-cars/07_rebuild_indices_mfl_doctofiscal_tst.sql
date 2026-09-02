-- Rebuild dos indices de consinco.MFL_DOCTOFISCAL em HOMOLOGACAO (tst)
-- Gerado em 20/08/2026. Tarefa de DBA.
--
-- Os 25 indices da tabela estao UNUSABLE, o que bloqueia QUALQUER DML nela
-- (ORA-01502) e, por tabela, o delete de consinco.ge_pessoa: ha 3 FKs NO ACTION
-- apontando de MFL_DOCTOFISCAL para GE_PESSOA (SEQPESSOA, SEQPAGADOR,
-- SEQTRANSPORTADOR), e a verificacao dessas FKs precisa dos indices.
--
-- Unicos primeiro: sao os que a verificacao de FK usa.
-- ONLINE evita bloquear a tabela. Sao 19,6 MILHOES de linhas - reserve janela,
-- espaco de tablespace e redo. Nao e operacao instantanea.

-- ============================================================================
--  CAUSA RAIZ - apurado em 20/08/2026, com evidencia
-- ============================================================================
--  consinco.MFL_DOCTOFISCAL e PARTICIONADA (51 particoes mensais,
--  P_DPC_CONTAC_ABR2021 .. P_DPC_CONTAC_SET2024) e TODOS os seus 25 indices sao
--  GLOBAIS (partitioned = NO sobre tabela particionada).
--
--  Indice GLOBAL fica UNUSABLE quando se executa DDL de particao sem a clausula
--  UPDATE GLOBAL INDEXES. E a unica causa que explica os 25 de uma vez.
--
--  O QUE A EVIDENCIA DESCARTA:
--
--   - NAO foi DROP de particao: tst e prd tem as MESMAS 51 particoes, com os
--     mesmos nomes. Nenhuma falta de um lado nem do outro.
--   - NAO foi TRUNCATE nem perda de dado: tst tem 19.590.775 linhas reais
--     (contagem com full scan); a estatistica de prd aponta 19.662.804. A
--     diferenca e o movimento normal entre a data do clone e hoje.
--   - NAO e manutencao em curso: confirmado pela equipe.
--   - NAO afeta producao: la os mesmos 25 indices estao VALID, e o schema
--     CONSINCO inteiro tem ZERO indice inutilizavel.
--
--  O QUE SOBRA COMO EXPLICACAO: operacao de particao que preserva conteudo -
--  tipicamente ALTER TABLE ... MOVE PARTITION (reorganizacao ou troca de
--  tablespace) - ou alguem ter marcado os indices UNUSABLE de proposito para
--  acelerar uma carga em massa e nao ter feito o rebuild depois.
--
--  O QUE NAO FOI POSSIVEL DETERMINAR: QUANDO. O last_ddl_time dos indices esta
--  espalhado entre 2022 e 2026 porque registra a ultima criacao/rebuild de cada
--  um, nao a mudanca de status para UNUSABLE. Datar o evento exige alert log ou
--  trilha de auditoria, que e acesso de DBA.
--
--  PREVENCAO, que vale mais que este rebuild: toda DDL de particao nesta tabela
--  precisa de UPDATE GLOBAL INDEXES. Sem isso, os 25 quebram de novo na proxima
--  vez, e do mesmo jeito silencioso - nada falha na hora, so a proxima gravacao.
-- ============================================================================


alter index consinco.XPKMFL_DOCTOFISCAL                 rebuild online;   -- UNIQUE
alter index consinco.MFL_DOCTOFISCALIE14                rebuild online;   -- NONUNIQUE
alter index consinco.MFL_DOCTOFISCALIE15                rebuild online;   -- NONUNIQUE
alter index consinco.MFL_DOCTOFISCALIE17                rebuild online;   -- NONUNIQUE
alter index consinco.MFL_DOCTOFISCALIE5                 rebuild online;   -- NONUNIQUE
alter index consinco.MFL_DOCTOFISCALIE6                 rebuild online;   -- NONUNIQUE
alter index consinco.MFL_DOCTOFISCALIE7                 rebuild online;   -- NONUNIQUE
alter index consinco.MFL_DOCTOFISCALIE8                 rebuild online;   -- NONUNIQUE
alter index consinco.MFL_DOCTOFISCALIEDTAEMP            rebuild online;   -- NONUNIQUE
alter index consinco.MFL_DOCTOFISCALIF1                 rebuild online;   -- NONUNIQUE
alter index consinco.MFL_DOCTOFISCALIF2                 rebuild online;   -- NONUNIQUE
alter index consinco.MFL_DOCTOFISCALSEQNOTA             rebuild online;   -- NONUNIQUE
alter index consinco.MFL_DOCTOFISCAL_SEQNF              rebuild online;   -- NONUNIQUE
alter index consinco.RN_IDX$$_273210004                 rebuild online;   -- NONUNIQUE
alter index consinco.SKY_56B4B0001                      rebuild online;   -- NONUNIQUE
alter index consinco.SKY_56B4B0002                      rebuild online;   -- NONUNIQUE
alter index consinco.SKY_56B4B0008                      rebuild online;   -- NONUNIQUE
alter index consinco.XIE1MFL_DOCTOFISCAL                rebuild online;   -- NONUNIQUE
alter index consinco.XIE2MFL_DOCTOFISCAL                rebuild online;   -- NONUNIQUE
alter index consinco.XIE3MFL_DOCTOFISCAL                rebuild online;   -- NONUNIQUE
alter index consinco.XIE4MFL_DOCTOFISCAL                rebuild online;   -- NONUNIQUE
alter index consinco.XIE_MFL_DOCTOFISCAL_GNRE           rebuild online;   -- NONUNIQUE
alter index consinco.XIE_MFL_DOCTOFISCAL_NFE            rebuild online;   -- NONUNIQUE
alter index consinco.XIE_MFL_DOCTOFISCAL_RECEB          rebuild online;   -- NONUNIQUE
alter index consinco.XIE_MFL_DOCTOFISCAL_REF            rebuild online;   -- NONUNIQUE

-- Conferencia: deve devolver ZERO linhas
select index_name, status from all_indexes
 where owner='CONSINCO' and table_name='MFL_DOCTOFISCAL' and status='UNUSABLE';

-- ---------------------------------------------------------------------------
--  Depois do rebuild
-- ---------------------------------------------------------------------------
--  1. Reexecutar a secao 3 do 06_reverter_consinco_all_cars_tst.sql (o delete de
--     consinco.ge_pessoa que ficou barrado).
--  2. Recolher estatistica da tabela: a ultima e de 16/07/2026.
--
--     begin
--       dbms_stats.gather_table_stats('CONSINCO','MFL_DOCTOFISCAL',
--         cascade => true, degree => 4);
--     end;
--     /
-- ---------------------------------------------------------------------------
