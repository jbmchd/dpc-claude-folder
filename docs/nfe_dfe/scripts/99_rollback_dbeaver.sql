-- ============================================================================
--  MODULO DFe - ROLLBACK DA INSTALACAO EM PRODUCAO
-- ============================================================================
--  DESTRUTIVO. Remove as 13 tabelas, as 13 sequences e, por consequencia, todo
--  documento fiscal capturado.
--
--  ==========================================================================
--   LEIA ISTO ANTES
--  ==========================================================================
--  O XML capturado NAO e reconstituivel a vontade. A SEFAZ retem por 90 dias
--  (o ADN guarda mais, mas nao ha garantia), e o cursor - a posicao de leitura -
--  existe SOMENTE em dpc_dfe_cursor: nem a SEFAZ nem o ADN guardam onde paramos.
--  Apagar aqui perde as duas coisas de uma vez.
--
--  Guarda legal do XML de NF-e: 11 anos (Ajuste SINIEF 2/2025).
--
--  Se a intencao for apenas PARAR a captura, nao use este script. Pause os
--  fluxos, que preserva tudo:
--
--      update poseidon.dpc_dfe_cursor
--         set status_sincronismo = 'P',
--             dsc_ultimo_motivo  = 'pausado: <motivo>',
--             updated_at = sysdate, updated_by = 'MANUAL';
--      commit;
--
--  ==========================================================================
--   ANTES DE APAGAR, MEDIR
--  ==========================================================================
--  Rode a secao 1 e guarde o resultado. Depois de dropar, ninguem sabe o que
--  havia.
-- ============================================================================


-- ###########################################################################
--  1. O QUE SERA PERDIDO
-- ###########################################################################
select 'dpc_dfe_documento (XML bruto)' as tabela, count(*) as linhas from poseidon.dpc_dfe_documento
union all select 'dpc_dfe_empresa', count(*) from poseidon.dpc_dfe_empresa
union all select 'dpc_dfe_cursor', count(*) from poseidon.dpc_dfe_cursor
union all select 'dpc_dfe_emitente', count(*) from poseidon.dpc_dfe_emitente
union all select 'dpc_dfe_nota', count(*) from poseidon.dpc_dfe_nota
union all select 'dpc_dfe_nota_item', count(*) from poseidon.dpc_dfe_nota_item
union all select 'dpc_dfe_evento', count(*) from poseidon.dpc_dfe_evento
union all select 'dpc_dfe_execucao', count(*) from poseidon.dpc_dfe_execucao
union all select 'dpc_dfe_manifestacao', count(*) from poseidon.dpc_dfe_manifestacao
union all select 'dpc_dfe_cte', count(*) from poseidon.dpc_dfe_cte
union all select 'dpc_dfe_cte_nfe', count(*) from poseidon.dpc_dfe_cte_nfe
union all select 'dpc_dfe_cte_evento', count(*) from poseidon.dpc_dfe_cte_evento
union all select 'dpc_dfe_nfse', count(*) from poseidon.dpc_dfe_nfse
order by 2 desc;

--  Cursores em risco: perder estes numeros significa nao saber de onde retomar.
select e.nro_empresa, c.cod_tipo_dfe, c.nro_ultimo_nsu, c.status_sincronismo
  from poseidon.dpc_dfe_cursor c
  join poseidon.dpc_dfe_empresa e on e.cod_dfe_empresa = c.cod_dfe_empresa
 where c.nro_ultimo_nsu > 0
 order by e.nro_empresa, c.cod_tipo_dfe;


-- ###########################################################################
--  2. DROP  (ordem inversa da dependencia)
-- ###########################################################################
--  CASCADE CONSTRAINTS em cada drop: dispensa remover FK antes, e evita a
--  ordem-dependencia virar ORA-02449 no meio.

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
   where owner = 'POSEIDON' and table_name = 'DPC_DFE_CTE_EVENTO';

  if qtd = 1 then
    execute immediate 'drop table poseidon.dpc_dfe_cte_evento cascade constraints purge';
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
   where owner = 'POSEIDON' and table_name = 'DPC_DFE_CTE';

  if qtd = 1 then
    execute immediate 'drop table poseidon.dpc_dfe_cte cascade constraints purge';
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
   where owner = 'POSEIDON' and table_name = 'DPC_DFE_EXECUCAO';

  if qtd = 1 then
    execute immediate 'drop table poseidon.dpc_dfe_execucao cascade constraints purge';
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
   where owner = 'POSEIDON' and table_name = 'DPC_DFE_NOTA_ITEM';

  if qtd = 1 then
    execute immediate 'drop table poseidon.dpc_dfe_nota_item cascade constraints purge';
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
   where owner = 'POSEIDON' and table_name = 'DPC_DFE_DOCUMENTO';

  if qtd = 1 then
    execute immediate 'drop table poseidon.dpc_dfe_documento cascade constraints purge';
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
   where owner = 'POSEIDON' and table_name = 'DPC_DFE_EMPRESA';

  if qtd = 1 then
    execute immediate 'drop table poseidon.dpc_dfe_empresa cascade constraints purge';
  end if;
end;

-- ###########################################################################
--  3. SEQUENCES
-- ###########################################################################

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
   where sequence_owner = 'POSEIDON' and sequence_name = 'DPCS_DFE_CTE';

  if qtd = 1 then
    execute immediate 'drop sequence poseidon.dpcs_dfe_cte';
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
   where sequence_owner = 'POSEIDON' and sequence_name = 'DPCS_DFE_EXECUCAO';

  if qtd = 1 then
    execute immediate 'drop sequence poseidon.dpcs_dfe_execucao';
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
   where sequence_owner = 'POSEIDON' and sequence_name = 'DPCS_DFE_NOTA_ITEM';

  if qtd = 1 then
    execute immediate 'drop sequence poseidon.dpcs_dfe_nota_item';
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
   where sequence_owner = 'POSEIDON' and sequence_name = 'DPCS_DFE_CURSOR';

  if qtd = 1 then
    execute immediate 'drop sequence poseidon.dpcs_dfe_cursor';
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


-- ###########################################################################
--  4. CONFERENCIA
-- ###########################################################################
--  ESPERADO: tudo zero. As triggers caem junto com as tabelas.
select (select count(*) from all_tables
         where owner='POSEIDON' and table_name like 'DPC_DFE%')          as tabelas,
       (select count(*) from all_sequences
         where sequence_owner='POSEIDON' and sequence_name like 'DPCS_DFE%') as sequences,
       (select count(*) from all_triggers
         where owner='POSEIDON' and trigger_name like 'DPCT_DFE%')       as triggers
  from dual;
-- ============================================================================
