-- ============================================================================
--  MODULO DFe - ROLLBACK DO MOTOR (ARQUIVO 01_99)
-- ============================================================================
--  DESTRUTIVO. Remove as 13 tabelas, as 13 sequences, todo documento fiscal
--  capturado e as 5 linhas de parametro do modulo.
--
--  ==========================================================================
--   RODE OS OUTROS DOIS ANTES
--  ==========================================================================
--      03_99_rollback_telas_dbeaver.sql        as telas
--      empresas/*_99_rollback_empresa_*.sql    cada empresa
--      01_99_rollback_motor_dbeaver.sql        <- este, por ultimo
--
--  Este arquivo NAO alcanca o certificado da empresa 30: ele mora em
--  poseidon.dpc_conta_certif_digital_emp, que e tabela do ERP e nao do modulo.
--  Rodar so este deixaria uma linha de certificado apontando para uma empresa
--  que nao existe mais aqui. Quem apaga essa linha e o _99 da empresa, em empresas/.
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
--   REEXECUTAVEL
--  ==========================================================================
--  Cada drop e guardado por existencia, e o delete de parametro por nome. Rodar
--  duas vezes seguidas nao devolve erro: a segunda nao encontra o que apagar.
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
--  4. PARAMETROS
-- ###########################################################################
--  POSEIDON.DPC_PARAMETRO e tabela COMPARTILHADA do ecossistema - tem ~99
--  linhas de outros modulos. Por isso o delete lista os cinco nomes, um a um, e
--  nao usa curinga: um  like 'dfe%'  pegaria qualquer parametro futuro de outro
--  modulo que por azar comece com essas tres letras.
--
--  POR QUE ISTO PRECISA ESTAR AQUI. Ate 09/09/2026 o rollback nao tocava nesta
--  tabela, e "apagar e recriar" deixava as 5 linhas vivas. Reinstalar depois
--  NAO as corrige, porque o 03_parametros e guardado por WHERE NOT EXISTS de
--  proposito - para nao sobrescrever valor que o operador ajustou a mao. O
--  resultado era uma base "nova" carregando parametro velho.
delete from poseidon.dpc_parametro
 where lower(nome) in ('dfe_max_bloqueios_dia',
                       'dfe_max_consultas',
                       'dfe_pausa_seg',
                       'dfe_min_backoff_656',
                       'dfe_conexao_erp');

commit;


-- ###########################################################################
--  5. CONFERENCIA
-- ###########################################################################
--  ESPERADO: tudo zero. As triggers caem junto com as tabelas.
--
--  As TRES tabelas do bloco de telas ficam de fora destas contagens de
--  proposito. Elas compartilham o prefixo DPC_DFE_ desde 09/09/2026, mas nao
--  sao do motor e nao sao apagadas aqui - quem apaga e o
--  03_99_rollback_telas_dbeaver.sql. Sem esta exclusao, este arquivo
--  acusaria as permissoes dos usuarios como "sobra" a cada execucao.
select (select count(*) from all_tables
         where owner='POSEIDON' and table_name like 'DPC_DFE%'
           and table_name not in ('DPC_DFE_USUARIO_EMPRESA', 'DPC_DFE_USUARIO_ABA',
                                  'DPC_DFE_PAINEL_ALERTA'))              as tabelas,
       (select count(*) from all_sequences
         where sequence_owner='POSEIDON' and sequence_name like 'DPCS_DFE%') as sequences,
       (select count(*) from all_triggers
         where owner='POSEIDON' and trigger_name like 'DPCT_DFE%')       as triggers,
       (select count(*) from poseidon.dpc_parametro
         where lower(nome) like 'dfe%')                                  as parametros
  from dual;

--  O que sobra do MOTOR em qualquer lugar do schema. ESPERADO: nenhuma linha.
--  Se aparecer algo, foi objeto criado fora do 01_01 - anote antes de apagar.
--
--  O filtro exclui as tres tabelas de telas e os objetos delas: a PK e a UK de
--  cada uma se chamam DPC_DFE_USUARIO_..._PK / _UK1 desde o rename, e cairiam
--  neste padrao sem serem do motor.
select object_name, object_type
  from all_objects
 where owner = 'POSEIDON'
   and (object_name like 'DPC_DFE%' or object_name like 'DPCS_DFE%'
     or object_name like 'DPCT_DFE%' or object_name like 'DPCI_DFE%')
   and object_name not like 'DPC_DFE_USUARIO_%'
   and object_name not like 'DPC_DFE_PAINEL_%'
 order by object_type, object_name;

--  E o contrario, para nao esconder problema: o bloco de TELAS continua de pe?
--  Informativo. Depois de rodar so o 01_99, ESPERADO: as tres presentes.
select table_name, 'de pe' as situacao
  from all_tables
 where owner = 'POSEIDON'
   and table_name in ('DPC_DFE_USUARIO_EMPRESA', 'DPC_DFE_USUARIO_ABA', 'DPC_DFE_PAINEL_ALERTA')
 order by table_name;

--  Certificado da empresa 30: NAO e apagado por este arquivo (tabela do ERP).
--  ESPERADO 0 se os _99 de empresas/ rodaram antes; diferente de 0 significa
--  certificado orfao - rode o _99 da empresa correspondente.
select count(*) as certificado_emp30_orfao
  from poseidon.dpc_conta_certif_digital_emp
 where cod_empresa = 30;
-- ============================================================================
