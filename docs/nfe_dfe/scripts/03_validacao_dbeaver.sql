-- ============================================================================
--  MODULO DFe - VALIDACAO DA INSTALACAO EM PRODUCAO
-- ============================================================================
--  Somente leitura, com UMA excecao marcada na secao 5 (insert + rollback, que
--  nao deixa rastro). Pode rodar quantas vezes quiser.
--
--  Rode secao por secao com Ctrl+Enter e compare com o ESPERADO de cada uma.
-- ============================================================================


-- ###########################################################################
--  1. CONTAGEM DE OBJETOS
-- ###########################################################################
--  ESPERADO: a coluna diferenca toda em zero.
with esperado as (
  select 'tabelas'      as objeto, 13 as qtd from dual union all
  select 'sequences',      13 from dual union all
  select 'triggers',       13 from dual union all
  select 'constraints',    54 from dual union all
  select 'indices',        48 from dual union all
  select 'colunas',       273 from dual union all
  select 'comentarios de tabela', 13 from dual union all
  select 'comentarios de coluna', 273 from dual
), encontrado as (   -- NAO usar "real": e tipo de dado no Oracle
  select 'tabelas' as objeto, count(*) as qtd
    from all_tables      where owner = 'POSEIDON' and table_name like 'DPC_DFE%'
  union all
  select 'sequences', count(*)
    from all_sequences   where sequence_owner = 'POSEIDON' and sequence_name like 'DPCS_DFE%'
  union all
  select 'triggers', count(*)
    from all_triggers    where owner = 'POSEIDON' and trigger_name like 'DPCT_DFE%'
  union all
  select 'constraints', count(*)
    from all_constraints where owner = 'POSEIDON' and table_name like 'DPC_DFE%'
                           and constraint_name not like 'SYS_%'
  union all
  select 'indices', count(*)
    from all_indexes     where owner = 'POSEIDON' and table_name like 'DPC_DFE%'
  union all
  select 'colunas', count(*)
    from all_tab_columns where owner = 'POSEIDON' and table_name like 'DPC_DFE%'
  union all
  select 'comentarios de tabela', count(*)
    from all_tab_comments where owner = 'POSEIDON' and table_name like 'DPC_DFE%'
                            and comments is not null
  union all
  select 'comentarios de coluna', count(*)
    from all_col_comments where owner = 'POSEIDON' and table_name like 'DPC_DFE%'
                            and comments is not null
)
select e.objeto, e.qtd as esperado, r.qtd as encontrado, r.qtd - e.qtd as diferenca
  from esperado e join encontrado r on r.objeto = e.objeto
 order by case when r.qtd - e.qtd <> 0 then 0 else 1 end, e.objeto;


-- ###########################################################################
--  2. OBJETO INVALIDO
-- ###########################################################################
--  ESPERADO: nenhuma linha.
select object_name, object_type, status
  from all_objects
 where owner = 'POSEIDON' and object_name like '%DFE%' and status <> 'VALID';


-- ###########################################################################
--  3. O QUE NAO PODE EXISTIR
-- ###########################################################################
--  Tres objetos que o script antigo criava e que NAO devem estar aqui. Se
--  aparecer alguma linha, alguem rodou o install/alters antigos em vez do 01.
--
--  ESPERADO: nenhuma linha.
select 'DPC_DFE_EMPRESA_CK1 existe (era sobre status_sincronismo, coluna que saiu desta tabela)' as problema
  from all_constraints
 where owner = 'POSEIDON' and constraint_name = 'DPC_DFE_EMPRESA_CK1'
union all
select 'DPC_DFE_EMPRESA_IX1 existe (era sobre colunas de cursor que sairam desta tabela)'
  from all_indexes
 where owner = 'POSEIDON' and index_name = 'DPC_DFE_EMPRESA_IX1'
union all
select 'DPC_DFE_DOCUMENTO_UK1 existe (UK antiga por empresa+nsu; a correta e UK2 por cursor+nsu)'
  from all_constraints
 where owner = 'POSEIDON' and constraint_name = 'DPC_DFE_DOCUMENTO_UK1'
union all
select 'coluna de cursor sobrou em DPC_DFE_EMPRESA: ' || column_name
  from all_tab_columns
 where owner = 'POSEIDON' and table_name = 'DPC_DFE_EMPRESA'
   and column_name in ('STATUS_SINCRONISMO','NRO_ULTIMO_NSU','NRO_MAXIMO_NSU',
                       'QTD_MIN_ENTRE_CONSULTA','QTD_MIN_EM_DIA','DTA_ULTIMA_CONSULTA',
                       'DTA_LIBERADO_EM','COD_ULTIMO_STATUS','DSC_ULTIMO_MOTIVO')
union all
select 'DPC_DFE_NOTA.SEQ_NOTA_FISCAL existe (foi renomeada para SEQ_NF_ERP no v4)'
  from all_tab_columns
 where owner = 'POSEIDON' and table_name = 'DPC_DFE_NOTA' and column_name = 'SEQ_NOTA_FISCAL';


-- ###########################################################################
--  4. PONTOS QUE JA CUSTARAM DIAGNOSTICO
-- ###########################################################################
--  Cada linha aqui existe porque o valor errado gerou um problema real. Todas
--  devem dizer OK.
select 'chave_nf de DPC_DFE_DOCUMENTO tem 50' as verificacao,
       case when data_length = 50 then 'OK'
            else 'ERRADO: ' || data_length || ' - chave de NFS-e tem 50 digitos e seria truncada' end as situacao
  from all_tab_columns
 where owner='POSEIDON' and table_name='DPC_DFE_DOCUMENTO' and column_name='CHAVE_NF'
union all
select 'chave_nfse tem 50',
       case when data_length = 50 then 'OK' else 'ERRADO: ' || data_length end
  from all_tab_columns
 where owner='POSEIDON' and table_name='DPC_DFE_NFSE' and column_name='CHAVE_NFSE'
union all
select 'chave_nf de DPC_DFE_NOTA tem 44',
       case when data_length = 44 then 'OK' else 'ERRADO: ' || data_length end
  from all_tab_columns
 where owner='POSEIDON' and table_name='DPC_DFE_NOTA' and column_name='CHAVE_NF'
union all
select 'DPC_DFE_CURSOR_CK1 aceita os 4 tipos',
       case when search_condition_vc like '%NFE%' and search_condition_vc like '%CTE%'
             and search_condition_vc like '%MDFE%' and search_condition_vc like '%NFSE%'
            then 'OK' else 'ERRADO: ' || search_condition_vc end
  from all_constraints
 where owner='POSEIDON' and constraint_name='DPC_DFE_CURSOR_CK1'
union all
select 'DPC_DFE_EVENTO.COD_DFE_NOTA aceita nulo (evento orfao nao pode ser descartado)',
       case when nullable = 'Y' then 'OK' else 'ERRADO: not null perderia evento de nota ainda nao capturada' end
  from all_tab_columns
 where owner='POSEIDON' and table_name='DPC_DFE_EVENTO' and column_name='COD_DFE_NOTA'
union all
select 'DPC_DFE_DOCUMENTO.BIN_DOCUMENTO e BLOB (gzip, nao texto)',
       case when data_type = 'BLOB' then 'OK' else 'ERRADO: ' || data_type end
  from all_tab_columns
 where owner='POSEIDON' and table_name='DPC_DFE_DOCUMENTO' and column_name='BIN_DOCUMENTO'
union all
select 'chave_nf de DPC_DFE_NOTA_ITEM nao existe (item liga por FK, nao por chave)',
       case when count(*) = 0 then 'OK'
            else 'ERRADO: item nao deve repetir a chave da nota' end
  from all_tab_columns
 where owner='POSEIDON' and table_name='DPC_DFE_NOTA_ITEM' and column_name='CHAVE_NF'
union all
select 'DPC_DFE_NOTA_ITEM.COD_EAN e VARCHAR (vem a string SEM GTIN)',
       case when data_type = 'VARCHAR2' then 'OK' else 'ERRADO: ' || data_type end
  from all_tab_columns
 where owner='POSEIDON' and table_name='DPC_DFE_NOTA_ITEM' and column_name='COD_EAN'
union all
select 'DPC_DFE_NOTA_ITEM.VLR_UNIT_COM sem escala fixa (layout usa 10 decimais)',
       case when data_scale is null then 'OK'
            else 'ERRADO: escala ' || data_scale || ' arredonda e o total deixa de fechar' end
  from all_tab_columns
 where owner='POSEIDON' and table_name='DPC_DFE_NOTA_ITEM' and column_name='VLR_UNIT_COM'
union all
select 'DPC_DFE_NOTA_CK3 aceita INDEF e OUTRO (nao sao a mesma coisa)',
       case when search_condition_vc like '%INDEF%' and search_condition_vc like '%OUTRO%'
            then 'OK' else 'ERRADO: ' || search_condition_vc end
  from all_constraints
 where owner='POSEIDON' and constraint_name='DPC_DFE_NOTA_CK3'
union all
select 'DPCI_DFE_NOTA_PAPEL comeca por cod_dfe_empresa (a tela sempre filtra empresa)',
       case when column_name = 'COD_DFE_EMPRESA' then 'OK'
            else 'ERRADO: comeca por ' || column_name end
  from all_ind_columns
 where index_owner='POSEIDON' and index_name='DPCI_DFE_NOTA_PAPEL' and column_position=1
union all
select 'FK sem indice (causa lock de tabela no pai)',
       case when count(*) = 0 then 'OK' else 'ERRADO: ' || count(*) || ' FK sem indice' end
  from (
    select c.constraint_name
      from all_constraints c
      join all_cons_columns cc on cc.owner=c.owner and cc.constraint_name=c.constraint_name
     where c.owner='POSEIDON' and c.constraint_type='R' and c.table_name like 'DPC_DFE%'
       and not exists (
             select 1 from all_ind_columns ic
              where ic.index_owner='POSEIDON' and ic.table_name=c.table_name
                and ic.column_name=cc.column_name and ic.column_position=1)
  );


-- ###########################################################################
--  5. TESTE FUNCIONAL - trigger e sequence  (ALTERA e DESFAZ)
-- ###########################################################################
--  A UNICA secao que escreve. Faz insert sem informar a PK, confere que a
--  trigger preencheu, e da ROLLBACK. Nao deixa linha nem consome sequence de
--  forma visivel (o numero e gasto, o que e inofensivo).
--
--  Vale porque contagem de objeto nao prova que a trigger FUNCIONA: trigger
--  compilada mas apontando para sequence errada passa em toda checagem acima.
declare
  v_cod  number;
  v_nome varchar2(30) := 'TESTE_VALIDACAO_' || to_char(systimestamp, 'ssff');
begin
  insert into poseidon.dpc_dfe_empresa
    (nro_empresa, num_cnpj, dsc_razao_social, sig_uf, created_by)
  values
    (999999, '00000000000000', v_nome, 'MG', 'VALIDACAO')
  returning cod_dfe_empresa into v_cod;

  if v_cod is null then
    dbms_output.put_line('FALHOU: a trigger DPCT_DFE_EMPRESA nao preencheu a PK');
  else
    dbms_output.put_line('OK: trigger preencheu cod_dfe_empresa = ' || v_cod);
  end if;

  -- e o cursor, que depende da FK recem-criada
  insert into poseidon.dpc_dfe_cursor
    (cod_dfe_empresa, cod_tipo_dfe, status_sincronismo, created_by)
  values (v_cod, 'NFSE', 'P', 'VALIDACAO');
  dbms_output.put_line('OK: FK e check de cod_tipo_dfe aceitaram NFSE');

  rollback;
  dbms_output.put_line('ROLLBACK feito - nada foi gravado');
exception
  when others then
    rollback;
    dbms_output.put_line('FALHOU: ' || sqlerrm);
    dbms_output.put_line('ROLLBACK feito - nada foi gravado');
end;


-- ###########################################################################
--  6. IMPRESSAO DIGITAL - para comparar com HOMOLOGACAO
-- ###########################################################################
--  Rode esta consulta NOS DOIS ambientes e compare os resultados. E o unico
--  jeito de provar que producao ficou igual ao que foi testado: contagem por si
--  nao pega coluna com tamanho diferente nem check divergente.
--
--  DIFERENCA CONHECIDA E ACEITA: as sequences DPCS_DFE_CURSOR, _CTE, _CTE_NFE e
--  _NFSE estao NOCACHE em homologacao e CACHE 20 aqui. Foi uniformizado de
--  proposito na instalacao nova. Qualquer outra diferenca merece investigacao.
select table_name, column_name, data_type,
       data_length, nullable, data_default
  from all_tab_columns
 where owner = 'POSEIDON' and table_name like 'DPC_DFE%'
 order by table_name, column_id;

select table_name, constraint_name, constraint_type,
       search_condition_vc, r_constraint_name, delete_rule
  from all_constraints
 where owner = 'POSEIDON' and table_name like 'DPC_DFE%'
   and constraint_name not like 'SYS_%'
 order by table_name, constraint_name;

select i.table_name, i.index_name, i.uniqueness,
       listagg(ic.column_name || decode(ic.descend,'DESC',' DESC',''), ', ')
         within group (order by ic.column_position) as colunas
  from all_indexes i
  join all_ind_columns ic on ic.index_owner = i.owner and ic.index_name = i.index_name
 where i.owner = 'POSEIDON' and i.table_name like 'DPC_DFE%'
 group by i.table_name, i.index_name, i.uniqueness
 order by i.table_name, i.index_name;
-- ============================================================================
