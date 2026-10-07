-- ============================================================================
--  PRODUCAO - P1_01 - APAGA AS TABELAS DFe ORFAS DA PRODUCAO
-- ============================================================================
--
--  Banco: Oracle PRODUCAO (instancia dpcdb1)        Schema: poseidon
--  >>> SO PARA A PRODUCAO. Na homolog estas tabelas sao o motor em uso.
--
--  ==========================================================================
--   POR QUE
--  ==========================================================================
--  Existem na producao, desde 25/08/2026, 12 tabelas dpc_dfe_* de uma versao
--  antiga do modulo (dpc_dfe_nota com 26 colunas; a atual tem bem mais), com
--  44 indices, 12 triggers DPCT_DFE_* e 12 sequences DPCS_DFE_*. Ninguem as
--  usa: o motor vive na homolog desde a decisao de 09/09/2026.
--
--  Elas precisam sair ANTES da instalacao: o instalador (ddl/01_01) PULA a
--  tabela que ja existe e so acrescenta coluna. Com estas aqui, a producao
--  ficaria com constraints e indices da versao velha.
--
--  ==========================================================================
--   O QUE SE PERDE (medido em 07/10/2026)
--  ==========================================================================
--    DPC_DFE_EMPRESA   13 linhas  (empresas 1,2,3,4,5,8,14,15,16,17,18,19,30)
--    DPC_DFE_CURSOR    52 linhas  (nenhum movimento: updated_at vazio)
--    as outras 10      vazias
--  Nada disso e dado de verdade: a carga inicial (dfe:replicar) traz da
--  homolog as 15 empresas e os 60 cursores em uso. Nao ha rollback de dado.
--
--  Medido tambem: nenhuma view, procedure, sinonimo, grant ou FK de outra
--  tabela aponta para estas. A SECAO 1 confere de novo antes de apagar.
--
--  ==========================================================================
--   COMO RODAR
--  ==========================================================================
--  Conectado como POSEIDON na PRODUCAO. Secao por secao (Ctrl+Enter):
--    SECAO 0  foto antes
--    SECAO 1  TRAVA - se qualquer conferencia nao bater, PARE
--    SECAO 2  apaga (pode rodar com Alt+X so esta secao)
--    SECAO 3  conferencia - esperado: nenhuma linha
--
--  Sem bloco PL/SQL, pela regra do modulo (o divisor do DBeaver corta bloco).
-- ============================================================================


-- ============================================================================
--  SECAO 0 - FOTO ANTES (esperado: EMPRESA 13, CURSOR 52, demais 0)
-- ============================================================================

select 'DPC_DFE_CTE' as tabela, count(*) as linhas from poseidon.dpc_dfe_cte
union all
select 'DPC_DFE_CTE_NFE' as tabela, count(*) as linhas from poseidon.dpc_dfe_cte_nfe
union all
select 'DPC_DFE_CURSOR' as tabela, count(*) as linhas from poseidon.dpc_dfe_cursor
union all
select 'DPC_DFE_DOCUMENTO' as tabela, count(*) as linhas from poseidon.dpc_dfe_documento
union all
select 'DPC_DFE_EMITENTE' as tabela, count(*) as linhas from poseidon.dpc_dfe_emitente
union all
select 'DPC_DFE_EMPRESA' as tabela, count(*) as linhas from poseidon.dpc_dfe_empresa
union all
select 'DPC_DFE_EVENTO' as tabela, count(*) as linhas from poseidon.dpc_dfe_evento
union all
select 'DPC_DFE_EXECUCAO' as tabela, count(*) as linhas from poseidon.dpc_dfe_execucao
union all
select 'DPC_DFE_MANIFESTACAO' as tabela, count(*) as linhas from poseidon.dpc_dfe_manifestacao
union all
select 'DPC_DFE_NFSE' as tabela, count(*) as linhas from poseidon.dpc_dfe_nfse
union all
select 'DPC_DFE_NOTA' as tabela, count(*) as linhas from poseidon.dpc_dfe_nota
union all
select 'DPC_DFE_NOTA_ITEM' as tabela, count(*) as linhas from poseidon.dpc_dfe_nota_item;


-- ============================================================================
--  SECAO 1 - TRAVA. Rode as quatro consultas. Se alguma nao bater, PARE.
-- ============================================================================

--  1a. Esperado: dpcdb1. Qualquer outro nome = voce NAO esta na producao.
select sys_context('userenv', 'instance_name') as instancia from dual;

--  1b. Esperado: nenhuma linha (nada de fora depende destas tabelas).
select owner, name, type, referenced_name
  from all_dependencies
 where referenced_owner = 'POSEIDON'
   and referenced_name like 'DPC_DFE%'
   and not (owner = 'POSEIDON' and name like 'DPCT_DFE%');

--  1c. Esperado: nenhuma linha (nenhuma FK de outra tabela aponta para elas).
select c.owner, c.table_name, c.constraint_name, r.table_name as referencia
  from all_constraints c
  join all_constraints r on r.owner = c.r_owner and r.constraint_name = c.r_constraint_name
 where c.constraint_type = 'R'
   and r.table_name like 'DPC_DFE%'
   and c.table_name not like 'DPC_DFE%';

--  1d. Esperado: nenhuma linha (nenhum grant concedido a outro usuario).
select grantee, table_name, privilege
  from all_tab_privs
 where table_schema = 'POSEIDON'
   and table_name like 'DPC_DFE%';


-- ============================================================================
--  SECAO 2 - APAGA as 12 tabelas (com indices, triggers e constraints) e as
--  12 sequences. 'purge' nao deixa nada na lixeira.
-- ============================================================================

drop table poseidon.dpc_dfe_nota_item cascade constraints purge;
drop table poseidon.dpc_dfe_cte_nfe cascade constraints purge;
drop table poseidon.dpc_dfe_evento cascade constraints purge;
drop table poseidon.dpc_dfe_manifestacao cascade constraints purge;
drop table poseidon.dpc_dfe_nota cascade constraints purge;
drop table poseidon.dpc_dfe_cte cascade constraints purge;
drop table poseidon.dpc_dfe_nfse cascade constraints purge;
drop table poseidon.dpc_dfe_documento cascade constraints purge;
drop table poseidon.dpc_dfe_execucao cascade constraints purge;
drop table poseidon.dpc_dfe_cursor cascade constraints purge;
drop table poseidon.dpc_dfe_emitente cascade constraints purge;
drop table poseidon.dpc_dfe_empresa cascade constraints purge;

drop sequence poseidon.dpcs_dfe_cte;
drop sequence poseidon.dpcs_dfe_cte_nfe;
drop sequence poseidon.dpcs_dfe_cursor;
drop sequence poseidon.dpcs_dfe_documento;
drop sequence poseidon.dpcs_dfe_emitente;
drop sequence poseidon.dpcs_dfe_empresa;
drop sequence poseidon.dpcs_dfe_evento;
drop sequence poseidon.dpcs_dfe_execucao;
drop sequence poseidon.dpcs_dfe_manifestacao;
drop sequence poseidon.dpcs_dfe_nfse;
drop sequence poseidon.dpcs_dfe_nota;
drop sequence poseidon.dpcs_dfe_nota_item;


-- ============================================================================
--  SECAO 3 - CONFERENCIA. Esperado: nenhuma linha.
-- ============================================================================

select object_type, object_name
  from all_objects
 where owner = 'POSEIDON'
   and (object_name like 'DPC_DFE%' or object_name like 'DPCT_DFE%' or object_name like 'DPCS_DFE%')
 order by 1, 2;
