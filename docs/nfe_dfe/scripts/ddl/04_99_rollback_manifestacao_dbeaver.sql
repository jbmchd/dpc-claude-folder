-- ============================================================================
--  MODULO DFe - ROLLBACK DA MANIFESTACAO (ARQUIVO 04_99)
-- ============================================================================
--  Desfaz SOMENTE o que o 04_01_manifestacao_dbeaver.sql acrescentou: as 6
--  colunas novas de dpc_dfe_manifestacao, as 2 de dpc_dfe_empresa, as 2 check
--  constraints, os 4 parametros, e devolve a UK ao formato antigo.
--
--  NAO apaga a tabela dpc_dfe_manifestacao nem nenhuma linha dela. Quem faz
--  isso e o 01_99_rollback_motor_dbeaver.sql.
--
--  ==========================================================================
--   LEIA ISTO ANTES
--  ==========================================================================
--  As colunas guardam registro de ATO FISCAL ja praticado. A dsc_justificativa
--  e o texto que foi declarado a Receita no evento 210240, e o
--  dta_registro_evento e a hora em que a SEFAZ registrou. Nada disso e
--  reconstituivel: a SEFAZ nao devolve ao destinatario o evento da propria
--  manifestacao (NT 2014.002, tabela de distribuicao). Apagar aqui perde o
--  unico registro que temos do que foi declarado.
--
--  Antes de rodar, meca o que vai embora:
--
--      select count(*) linhas,
--             count(dsc_justificativa) com_justificativa,
--             count(dta_registro_evento) com_hora_sefaz,
--             count(distinct nro_seq_evento) sequencias_distintas
--        from poseidon.dpc_dfe_manifestacao;
--
--  Se a intencao for apenas DESLIGAR a manifestacao, nao use este script.
--  Feche as trancas, que preserva tudo:
--
--      update poseidon.dpc_dfe_empresa
--         set status_manifestar             = 'N',
--             status_manif_auto_ciencia     = 'N',
--             status_manif_auto_confirmacao = 'N',
--             updated_at = sysdate, updated_by = 'MANUAL';
--      commit;
--
--  ==========================================================================
--   A UK VOLTA MENOR, E ISSO PODE FALHAR
--  ==========================================================================
--  A UK antiga e (cod_dfe_nota, cod_tipo_evento). Se ja existir mais de uma
--  sequencia do mesmo evento na mesma nota - exatamente o caso que a coluna
--  nova veio permitir - a UK antiga nao pode ser recriada, e o bloco avisa no
--  DBMS_OUTPUT em vez de estourar. Nesse cenario o rollback fica pela metade
--  de proposito: decidir qual linha descartar e decisao humana, nao de script.
--
--  ==========================================================================
--   COMO RODAR (DBeaver)
--  ==========================================================================
--  Conectado como POSEIDON, arquivo INTEIRO com Alt+X. Sem "/" para terminar
--  bloco. CRLF de proposito. LIGUE O DBMS_OUTPUT.
--
--  Reexecutavel: cada drop e guardado por existencia.
-- ============================================================================


-- ============================================================================
--  SECAO 1 - UK VOLTA AO FORMATO ANTIGO
-- ============================================================================
declare
  qtd  number;
  dup  number;
  cols varchar2(400);
begin
  select count(*) into qtd from all_constraints
   where owner = 'POSEIDON' and constraint_name = 'DPC_DFE_MANIF_UK1';

  if qtd = 0 then
    dbms_output.put_line('DPC_DFE_MANIF_UK1: nao existe, nada a fazer');
  else
    select listagg(column_name, ',') within group (order by position)
      into cols
      from all_cons_columns
     where owner = 'POSEIDON' and constraint_name = 'DPC_DFE_MANIF_UK1';

    if instr(upper(cols), 'NRO_SEQ_EVENTO') = 0 then
      dbms_output.put_line('DPC_DFE_MANIF_UK1: ja esta no formato antigo');
    else
      select count(*) into dup from (
        select cod_dfe_nota, cod_tipo_evento
          from poseidon.dpc_dfe_manifestacao
         group by cod_dfe_nota, cod_tipo_evento
        having count(*) > 1);

      if dup > 0 then
        dbms_output.put_line('DPC_DFE_MANIF_UK1: NAO REVERTIDA - existem '
          || dup || ' par(es) (nota, evento) com mais de uma sequencia. '
          || 'A UK antiga nao comporta. Resolva a mao antes.');
      else
        execute immediate 'alter table poseidon.dpc_dfe_manifestacao drop constraint DPC_DFE_MANIF_UK1 drop index';
        execute immediate q'[alter table poseidon.dpc_dfe_manifestacao add constraint DPC_DFE_MANIF_UK1 unique (cod_dfe_nota, cod_tipo_evento) using index tablespace TSD_POSEIDON]';
        dbms_output.put_line('DPC_DFE_MANIF_UK1: revertida para (cod_dfe_nota, cod_tipo_evento)');
      end if;
    end if;
  end if;
exception
  when others then
    dbms_output.put_line('DPC_DFE_MANIF_UK1: FALHOU -> ' || sqlerrm);
end;

-- ============================================================================
--  SECAO 2 - CHECK CONSTRAINTS DE DPC_DFE_EMPRESA
-- ============================================================================
declare
  qtd number;
begin
  for c in (
    select 'DPC_DFE_EMPRESA_CK3' as nome from dual union all
    select 'DPC_DFE_EMPRESA_CK4'         from dual
  ) loop
    begin
      select count(*) into qtd from all_constraints
       where owner = 'POSEIDON' and constraint_name = c.nome;

      if qtd > 0 then
        execute immediate 'alter table poseidon.dpc_dfe_empresa drop constraint ' || c.nome;
        dbms_output.put_line(c.nome || ': removida');
      else
        dbms_output.put_line(c.nome || ': nao existe');
      end if;
    exception
      when others then
        dbms_output.put_line(c.nome || ': FALHOU -> ' || sqlerrm);
    end;
  end loop;
end;

-- ============================================================================
--  SECAO 3 - COLUNAS DE DPC_DFE_EMPRESA
-- ============================================================================
declare
  qtd number;
begin
  for c in (
    select 'status_manif_auto_ciencia' as nome from dual union all
    select 'status_manif_auto_confirmacao'     from dual
  ) loop
    begin
      select count(*) into qtd from all_tab_columns
       where owner = 'POSEIDON' and table_name = 'DPC_DFE_EMPRESA'
         and column_name = upper(c.nome);

      if qtd > 0 then
        execute immediate 'alter table poseidon.dpc_dfe_empresa drop column ' || c.nome;
        dbms_output.put_line('DPC_DFE_EMPRESA: removida -> ' || c.nome);
      else
        dbms_output.put_line('DPC_DFE_EMPRESA: nao existe -> ' || c.nome);
      end if;
    exception
      when others then
        dbms_output.put_line('DPC_DFE_EMPRESA: FALHOU em ' || c.nome || ' -> ' || sqlerrm);
    end;
  end loop;
end;

-- ============================================================================
--  SECAO 4 - COLUNAS DE DPC_DFE_MANIFESTACAO
-- ============================================================================
-- nro_seq_evento vai por ultimo: a UK da secao 1 precisa ter saido antes.
declare
  qtd number;
begin
  for c in (
    select 'dsc_justificativa' as nome from dual union all
    select 'dta_registro_evento'       from dual union all
    select 'cod_dfe_empresa'           from dual union all
    select 'dsc_id_lote'               from dual union all
    select 'dta_proxima_tentativa'     from dual union all
    select 'nro_seq_evento'            from dual
  ) loop
    begin
      select count(*) into qtd from all_tab_columns
       where owner = 'POSEIDON' and table_name = 'DPC_DFE_MANIFESTACAO'
         and column_name = upper(c.nome);

      if qtd > 0 then
        execute immediate 'alter table poseidon.dpc_dfe_manifestacao drop column ' || c.nome;
        dbms_output.put_line('DPC_DFE_MANIFESTACAO: removida -> ' || c.nome);
      else
        dbms_output.put_line('DPC_DFE_MANIFESTACAO: nao existe -> ' || c.nome);
      end if;
    exception
      when others then
        dbms_output.put_line('DPC_DFE_MANIFESTACAO: FALHOU em ' || c.nome || ' -> ' || sqlerrm);
    end;
  end loop;
end;

-- ============================================================================
--  SECAO 5 - PARAMETROS
-- ============================================================================
delete from poseidon.dpc_parametro
 where lower(nome) in ('dfe_manifest_max_lote','dfe_manifest_max_ciclo',
                       'dfe_manifest_pausa_seg','dfe_max_bloqueios_manifest');

commit;

-- ============================================================================
--  SECAO 6 - CONFERENCIA (o esperado e NENHUMA linha)
-- ============================================================================
select 'coluna sobrando' as tipo, table_name as objeto, column_name as detalhe
  from all_tab_columns
 where owner = 'POSEIDON'
   and ( (table_name = 'DPC_DFE_MANIFESTACAO'
          and column_name in ('NRO_SEQ_EVENTO','DSC_JUSTIFICATIVA','DTA_REGISTRO_EVENTO',
                              'COD_DFE_EMPRESA','DSC_ID_LOTE','DTA_PROXIMA_TENTATIVA'))
      or (table_name = 'DPC_DFE_EMPRESA'
          and column_name in ('STATUS_MANIF_AUTO_CIENCIA','STATUS_MANIF_AUTO_CONFIRMACAO')) )
union all
select 'constraint sobrando', table_name, constraint_name
  from all_constraints
 where owner = 'POSEIDON'
   and constraint_name in ('DPC_DFE_EMPRESA_CK3','DPC_DFE_EMPRESA_CK4')
union all
select 'parametro sobrando', 'DPC_PARAMETRO', nome
  from poseidon.dpc_parametro
 where lower(nome) in ('dfe_manifest_max_lote','dfe_manifest_max_ciclo',
                       'dfe_manifest_pausa_seg','dfe_max_bloqueios_manifest')
 order by 1, 2, 3;
