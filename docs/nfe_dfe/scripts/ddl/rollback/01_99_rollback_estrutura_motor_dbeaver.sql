-- ============================================================================
--  ROLLBACK - ESTRUTURA DO MOTOR (ddl/rollback/01_99_rollback_estrutura_motor)
-- ============================================================================
--  DESTRUTIVO. Remove as 17 tabelas do motor, as 13 sequences e TODO documento fiscal capturado.
--
--  ==========================================================================
--   LEIA ISTO ANTES
--  ==========================================================================
--  O XML capturado NAO e reconstituivel a vontade. A SEFAZ retem por 90 dias (o ADN guarda mais, sem garantia),
--  e o cursor - a posicao de leitura - existe SOMENTE em dpc_dfe_cursor: nem a SEFAZ nem o ADN guardam onde
--  paramos. Apagar aqui perde as duas coisas de uma vez. Guarda legal do XML de NF-e: 11 anos (Ajuste SINIEF 2/2025).
--
--  Se a intencao for apenas PARAR a captura, nao use este script: pause os cursores (operacao/pausa_empresas).
--
--  Rode ANTES o 02_99_rollback_estrutura_telas se for desfazer o modulo inteiro (as telas nao tem FK para o motor,
--  mas a ordem evita tela apontando para empresa que nao existe mais). Depois o 03_99_rollback_parametros.
--  Este arquivo NAO alcanca o certificado de nenhuma empresa: ele mora em poseidon.dpc_conta_certif_digital_emp,
--  tabela do ERP.
--  Reexecutavel: cada drop e guardado por existencia.
--  Conectado como POSEIDON.
-- ============================================================================


-- ###########################################################################
--  1. O QUE SERA PERDIDO
--  Rode e guarde o resultado. Depois de dropar, ninguem sabe o que havia.
-- ###########################################################################
select 'empresa' as tabela, count(*) as linhas from poseidon.dpc_dfe_empresa
union all select 'cursor' as tabela, count(*) as linhas from poseidon.dpc_dfe_cursor
union all select 'emitente' as tabela, count(*) as linhas from poseidon.dpc_dfe_emitente
union all select 'execucao' as tabela, count(*) as linhas from poseidon.dpc_dfe_execucao
union all select 'documento' as tabela, count(*) as linhas from poseidon.dpc_dfe_documento
union all select 'nota' as tabela, count(*) as linhas from poseidon.dpc_dfe_nota
union all select 'nota_item' as tabela, count(*) as linhas from poseidon.dpc_dfe_nota_item
union all select 'nota_total' as tabela, count(*) as linhas from poseidon.dpc_dfe_nota_total
union all select 'nota_transporte' as tabela, count(*) as linhas from poseidon.dpc_dfe_nota_transporte
union all select 'nota_cobranca' as tabela, count(*) as linhas from poseidon.dpc_dfe_nota_cobranca
union all select 'cte' as tabela, count(*) as linhas from poseidon.dpc_dfe_cte
union all select 'cte_nfe' as tabela, count(*) as linhas from poseidon.dpc_dfe_cte_nfe
union all select 'cte_evento' as tabela, count(*) as linhas from poseidon.dpc_dfe_cte_evento
union all select 'nfse' as tabela, count(*) as linhas from poseidon.dpc_dfe_nfse
union all select 'evento' as tabela, count(*) as linhas from poseidon.dpc_dfe_evento
union all select 'manif_pedido' as tabela, count(*) as linhas from poseidon.dpc_dfe_manif_pedido
union all select 'manifestacao' as tabela, count(*) as linhas from poseidon.dpc_dfe_manifestacao
 order by 2 desc;

-- ###########################################################################
--  2. TRAVA
--  Confira a instancia ANTES de apagar. A producao responde dpcdb1 ou dpcdb2 (RAC); a homolog, homolog.
-- ###########################################################################
select sys_context('userenv', 'instance_name') as instancia from dual;

-- ###########################################################################
--  3. APAGA
--  'purge' nao deixa nada na lixeira; cascade constraints leva indices, triggers e as FK das filhas.
--  Cada drop e guardado por existencia: reexecutar nao devolve erro.
-- ###########################################################################
declare
  qtd number;
begin
  select count(*) into qtd from all_tables
   where owner = 'POSEIDON' and table_name = 'DPC_DFE_EXECUCAO';
  if qtd = 1 then
    execute immediate 'drop table poseidon.dpc_dfe_execucao cascade constraints purge';
  end if;
end;

declare
  qtd number;
begin
  select count(*) into qtd from all_tables
   where owner = 'POSEIDON' and table_name = 'DPC_DFE_DOCUMENTO';
  if qtd = 1 then
    execute immediate 'drop table poseidon.dpc_dfe_documento cascade constraints purge';
  end if;
end;

declare
  qtd number;
begin
  select count(*) into qtd from all_tables
   where owner = 'POSEIDON' and table_name = 'DPC_DFE_NOTA_ITEM';
  if qtd = 1 then
    execute immediate 'drop table poseidon.dpc_dfe_nota_item cascade constraints purge';
  end if;
end;

declare
  qtd number;
begin
  select count(*) into qtd from all_tables
   where owner = 'POSEIDON' and table_name = 'DPC_DFE_NOTA_TOTAL';
  if qtd = 1 then
    execute immediate 'drop table poseidon.dpc_dfe_nota_total cascade constraints purge';
  end if;
end;

declare
  qtd number;
begin
  select count(*) into qtd from all_tables
   where owner = 'POSEIDON' and table_name = 'DPC_DFE_NOTA_TRANSPORTE';
  if qtd = 1 then
    execute immediate 'drop table poseidon.dpc_dfe_nota_transporte cascade constraints purge';
  end if;
end;

declare
  qtd number;
begin
  select count(*) into qtd from all_tables
   where owner = 'POSEIDON' and table_name = 'DPC_DFE_NOTA_COBRANCA';
  if qtd = 1 then
    execute immediate 'drop table poseidon.dpc_dfe_nota_cobranca cascade constraints purge';
  end if;
end;

declare
  qtd number;
begin
  select count(*) into qtd from all_tables
   where owner = 'POSEIDON' and table_name = 'DPC_DFE_CTE_NFE';
  if qtd = 1 then
    execute immediate 'drop table poseidon.dpc_dfe_cte_nfe cascade constraints purge';
  end if;
end;

declare
  qtd number;
begin
  select count(*) into qtd from all_tables
   where owner = 'POSEIDON' and table_name = 'DPC_DFE_CTE_EVENTO';
  if qtd = 1 then
    execute immediate 'drop table poseidon.dpc_dfe_cte_evento cascade constraints purge';
  end if;
end;

declare
  qtd number;
begin
  select count(*) into qtd from all_tables
   where owner = 'POSEIDON' and table_name = 'DPC_DFE_NFSE';
  if qtd = 1 then
    execute immediate 'drop table poseidon.dpc_dfe_nfse cascade constraints purge';
  end if;
end;

declare
  qtd number;
begin
  select count(*) into qtd from all_tables
   where owner = 'POSEIDON' and table_name = 'DPC_DFE_EVENTO';
  if qtd = 1 then
    execute immediate 'drop table poseidon.dpc_dfe_evento cascade constraints purge';
  end if;
end;

declare
  qtd number;
begin
  select count(*) into qtd from all_tables
   where owner = 'POSEIDON' and table_name = 'DPC_DFE_MANIFESTACAO';
  if qtd = 1 then
    execute immediate 'drop table poseidon.dpc_dfe_manifestacao cascade constraints purge';
  end if;
end;

declare
  qtd number;
begin
  select count(*) into qtd from all_tables
   where owner = 'POSEIDON' and table_name = 'DPC_DFE_CURSOR';
  if qtd = 1 then
    execute immediate 'drop table poseidon.dpc_dfe_cursor cascade constraints purge';
  end if;
end;

declare
  qtd number;
begin
  select count(*) into qtd from all_tables
   where owner = 'POSEIDON' and table_name = 'DPC_DFE_NOTA';
  if qtd = 1 then
    execute immediate 'drop table poseidon.dpc_dfe_nota cascade constraints purge';
  end if;
end;

declare
  qtd number;
begin
  select count(*) into qtd from all_tables
   where owner = 'POSEIDON' and table_name = 'DPC_DFE_CTE';
  if qtd = 1 then
    execute immediate 'drop table poseidon.dpc_dfe_cte cascade constraints purge';
  end if;
end;

declare
  qtd number;
begin
  select count(*) into qtd from all_tables
   where owner = 'POSEIDON' and table_name = 'DPC_DFE_MANIF_PEDIDO';
  if qtd = 1 then
    execute immediate 'drop table poseidon.dpc_dfe_manif_pedido cascade constraints purge';
  end if;
end;

declare
  qtd number;
begin
  select count(*) into qtd from all_tables
   where owner = 'POSEIDON' and table_name = 'DPC_DFE_EMPRESA';
  if qtd = 1 then
    execute immediate 'drop table poseidon.dpc_dfe_empresa cascade constraints purge';
  end if;
end;

declare
  qtd number;
begin
  select count(*) into qtd from all_tables
   where owner = 'POSEIDON' and table_name = 'DPC_DFE_EMITENTE';
  if qtd = 1 then
    execute immediate 'drop table poseidon.dpc_dfe_emitente cascade constraints purge';
  end if;
end;

declare
  qtd number;
begin
  select count(*) into qtd from all_sequences
   where sequence_owner = 'POSEIDON' and sequence_name = 'DPCS_DFE_CTE';
  if qtd = 1 then
    execute immediate 'drop sequence poseidon.dpcs_dfe_cte';
  end if;
end;

declare
  qtd number;
begin
  select count(*) into qtd from all_sequences
   where sequence_owner = 'POSEIDON' and sequence_name = 'DPCS_DFE_CTE_EVENTO';
  if qtd = 1 then
    execute immediate 'drop sequence poseidon.dpcs_dfe_cte_evento';
  end if;
end;

declare
  qtd number;
begin
  select count(*) into qtd from all_sequences
   where sequence_owner = 'POSEIDON' and sequence_name = 'DPCS_DFE_CTE_NFE';
  if qtd = 1 then
    execute immediate 'drop sequence poseidon.dpcs_dfe_cte_nfe';
  end if;
end;

declare
  qtd number;
begin
  select count(*) into qtd from all_sequences
   where sequence_owner = 'POSEIDON' and sequence_name = 'DPCS_DFE_CURSOR';
  if qtd = 1 then
    execute immediate 'drop sequence poseidon.dpcs_dfe_cursor';
  end if;
end;

declare
  qtd number;
begin
  select count(*) into qtd from all_sequences
   where sequence_owner = 'POSEIDON' and sequence_name = 'DPCS_DFE_DOCUMENTO';
  if qtd = 1 then
    execute immediate 'drop sequence poseidon.dpcs_dfe_documento';
  end if;
end;

declare
  qtd number;
begin
  select count(*) into qtd from all_sequences
   where sequence_owner = 'POSEIDON' and sequence_name = 'DPCS_DFE_EMITENTE';
  if qtd = 1 then
    execute immediate 'drop sequence poseidon.dpcs_dfe_emitente';
  end if;
end;

declare
  qtd number;
begin
  select count(*) into qtd from all_sequences
   where sequence_owner = 'POSEIDON' and sequence_name = 'DPCS_DFE_EMPRESA';
  if qtd = 1 then
    execute immediate 'drop sequence poseidon.dpcs_dfe_empresa';
  end if;
end;

declare
  qtd number;
begin
  select count(*) into qtd from all_sequences
   where sequence_owner = 'POSEIDON' and sequence_name = 'DPCS_DFE_EVENTO';
  if qtd = 1 then
    execute immediate 'drop sequence poseidon.dpcs_dfe_evento';
  end if;
end;

declare
  qtd number;
begin
  select count(*) into qtd from all_sequences
   where sequence_owner = 'POSEIDON' and sequence_name = 'DPCS_DFE_EXECUCAO';
  if qtd = 1 then
    execute immediate 'drop sequence poseidon.dpcs_dfe_execucao';
  end if;
end;

declare
  qtd number;
begin
  select count(*) into qtd from all_sequences
   where sequence_owner = 'POSEIDON' and sequence_name = 'DPCS_DFE_MANIFESTACAO';
  if qtd = 1 then
    execute immediate 'drop sequence poseidon.dpcs_dfe_manifestacao';
  end if;
end;

declare
  qtd number;
begin
  select count(*) into qtd from all_sequences
   where sequence_owner = 'POSEIDON' and sequence_name = 'DPCS_DFE_NFSE';
  if qtd = 1 then
    execute immediate 'drop sequence poseidon.dpcs_dfe_nfse';
  end if;
end;

declare
  qtd number;
begin
  select count(*) into qtd from all_sequences
   where sequence_owner = 'POSEIDON' and sequence_name = 'DPCS_DFE_NOTA';
  if qtd = 1 then
    execute immediate 'drop sequence poseidon.dpcs_dfe_nota';
  end if;
end;

declare
  qtd number;
begin
  select count(*) into qtd from all_sequences
   where sequence_owner = 'POSEIDON' and sequence_name = 'DPCS_DFE_NOTA_ITEM';
  if qtd = 1 then
    execute immediate 'drop sequence poseidon.dpcs_dfe_nota_item';
  end if;
end;

-- ###########################################################################
--  4. CONFERENCIA (esperado: nenhuma linha)
-- ###########################################################################
select object_type, object_name from all_objects
 where owner = 'POSEIDON' and (object_name = 'DPC_DFE_EMPRESA' or object_name = 'DPC_DFE_CURSOR' or object_name = 'DPC_DFE_EMITENTE' or object_name = 'DPC_DFE_EXECUCAO' or object_name = 'DPC_DFE_DOCUMENTO' or object_name = 'DPC_DFE_NOTA' or object_name = 'DPC_DFE_NOTA_ITEM' or object_name = 'DPC_DFE_NOTA_TOTAL' or object_name = 'DPC_DFE_NOTA_TRANSPORTE' or object_name = 'DPC_DFE_NOTA_COBRANCA' or object_name = 'DPC_DFE_CTE' or object_name = 'DPC_DFE_CTE_NFE' or object_name = 'DPC_DFE_CTE_EVENTO' or object_name = 'DPC_DFE_NFSE' or object_name = 'DPC_DFE_EVENTO' or object_name = 'DPC_DFE_MANIF_PEDIDO' or object_name = 'DPC_DFE_MANIFESTACAO' or object_name = 'DPCS_DFE_CTE' or object_name = 'DPCS_DFE_CTE_EVENTO' or object_name = 'DPCS_DFE_CTE_NFE' or object_name = 'DPCS_DFE_CURSOR' or object_name = 'DPCS_DFE_DOCUMENTO' or object_name = 'DPCS_DFE_EMITENTE' or object_name = 'DPCS_DFE_EMPRESA' or object_name = 'DPCS_DFE_EVENTO' or object_name = 'DPCS_DFE_EXECUCAO' or object_name = 'DPCS_DFE_MANIFESTACAO' or object_name = 'DPCS_DFE_NFSE' or object_name = 'DPCS_DFE_NOTA' or object_name = 'DPCS_DFE_NOTA_ITEM')
 order by 1, 2;
