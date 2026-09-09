-- ============================================================================
--  MODULO DFe - VALIDACAO DO MOTOR E DAS TELAS (ARQUIVO 01_04)
-- ============================================================================
--  Somente leitura, com UMA excecao marcada na secao 5 (insert + rollback, que
--  nao deixa rastro). Pode rodar quantas vezes quiser, em qualquer ordem.
--
--  Rode secao por secao com Ctrl+Enter e compare com o ESPERADO de cada uma.
--
--  ==========================================================================
--   ESTE ARQUIVO VALIDA O GERAL, E E AGNOSTICO A EMPRESA ESPECIFICA
--  ==========================================================================
--  Ele roda ANTES dos pares de empresas/, e por isso a secao 6 exige os
--  12 CNPJs do bloco geral e trata qualquer estabelecimento adicional como
--  INFORMACAO, nao como erro. O veredito e o mesmo antes ou depois deles - o
--  que permite rodar este arquivo a qualquer momento, inclusive meses depois,
--  sem ter de lembrar o que mais foi instalado.
--
--  A conferencia da empresa 30 mora na secao 4 do proprio 05.
--
--  ==========================================================================
--   POR QUE NAO HA CONTAGEM GLOBAL AQUI
--  ==========================================================================
--  Ate 09/09/2026 a secao 1 comparava contra oito numeros globais escritos a
--  mao - 13 tabelas, 54 constraints, 273 colunas, e assim por diante. Numero
--  global assim envelhece na primeira coluna nova, e envelhece EM SILENCIO: o
--  proprio 01_estrutura ficou meses esperando 12 tabelas e 242 colunas
--  comentadas, de modo que quem instalasse numa base limpa leria "esperado 12,
--  achado 13" e concluiria que a instalacao falhou.
--
--  Trocado por duas coisas que nao envelhecem sozinhas:
--
--    secao 1   contagem POR TABELA. Treze numeros; coluna nova muda UM deles,
--              o da tabela dela, na mesma edicao em que entra no 01_01.
--    secao 2   INVARIANTES - relacoes que continuam verdadeiras quando o
--              modulo cresce, porque nao citam quantidade nenhuma.
-- ============================================================================


-- ###########################################################################
--  1. ESTRUTURA - COLUNA POR TABELA
-- ###########################################################################
--  ESPERADO: diferenca toda em zero, e nenhuma linha com achado nulo (achado
--  nulo = a tabela nao existe).
--
--  A lista sai dos create table do 01_01_estrutura_dbeaver.sql. Se divergir,
--  compare com a secao 3 (COLUNAS) daquele arquivo: as duas listas sao a mesma,
--  e um numero errado aqui geralmente significa coluna acrescentada em um lugar
--  so.
with esperado as (
  select 'dpc_dfe_empresa'          as tabela,  11 as colunas, 'motor' as bloco from dual union all
  select 'dpc_dfe_cursor'                    ,  16           , 'motor'          from dual union all
  select 'dpc_dfe_emitente'                  ,   8           , 'motor'          from dual union all
  select 'dpc_dfe_documento'                 ,  13           , 'motor'          from dual union all
  select 'dpc_dfe_nota'                      ,  37           , 'motor'          from dual union all
  select 'dpc_dfe_nota_item'                 ,  51           , 'motor'          from dual union all
  select 'dpc_dfe_evento'                    ,  14           , 'motor'          from dual union all
  select 'dpc_dfe_execucao'                  ,  15           , 'motor'          from dual union all
  select 'dpc_dfe_manifestacao'              ,  15           , 'motor'          from dual union all
  select 'dpc_dfe_cte'                       ,  35           , 'motor'          from dual union all
  select 'dpc_dfe_cte_nfe'                   ,   5           , 'motor'          from dual union all
  select 'dpc_dfe_cte_evento'                ,  20           , 'motor'          from dual union all
  select 'dpc_dfe_nfse'                      ,  33           , 'motor'          from dual union all
  select 'dpc_dfe_usuario_empresa'           ,   7           , 'telas'          from dual union all
  select 'dpc_dfe_usuario_aba'               ,   7           , 'telas'          from dual union all
  select 'dpc_dfe_painel_alerta'             ,   9           , 'telas'          from dual
), achado as (
  select lower(table_name) as tabela, count(*) as qtd
    from all_tab_columns
   where owner = 'POSEIDON' and table_name like 'DPC_DFE%'
   group by table_name
)
select e.bloco,
       e.tabela,
       e.colunas as esperado,
       a.qtd     as achado,
       nvl(a.qtd, 0) - e.colunas as diferenca
  from esperado e
  left join achado a on a.tabela = e.tabela
 order by case when nvl(a.qtd, 0) - e.colunas <> 0 then 0 else 1 end, e.bloco, e.tabela;

--  Tabela que existe no banco e NAO esta na lista acima. ESPERADO: nenhuma.
--  Pega objeto criado fora do 01_01 - resto de teste, tabela de backup esquecida.
select table_name
  from all_tables
 where owner = 'POSEIDON' and table_name like 'DPC_DFE%'
   and lower(table_name) not in (
       'dpc_dfe_empresa',
       'dpc_dfe_cursor',
       'dpc_dfe_emitente',
       'dpc_dfe_documento',
       'dpc_dfe_nota',
       'dpc_dfe_nota_item',
       'dpc_dfe_evento',
       'dpc_dfe_execucao',
       'dpc_dfe_manifestacao',
       'dpc_dfe_cte',
       'dpc_dfe_cte_nfe',
       'dpc_dfe_cte_evento',
       'dpc_dfe_nfse',
       'dpc_dfe_usuario_empresa',
       'dpc_dfe_usuario_aba',
       'dpc_dfe_painel_alerta'
 )
 order by table_name;


-- ###########################################################################
--  2. INVARIANTES
-- ###########################################################################
--  Nenhuma delas cita quantidade: continuam valendo quando o modulo cresce.
--  ESPERADO: as seis linhas com qtd = 0.
select 'coluna sem comentario'  as invariante, count(*) as qtd
  from all_tab_columns c
 where c.owner = 'POSEIDON' and c.table_name like 'DPC_DFE%'
   and not exists (select 1 from all_col_comments m
                    where m.owner = c.owner
                      and m.table_name = c.table_name
                      and m.column_name = c.column_name
                      and m.comments is not null)
union all
select 'tabela sem comentario', count(*)
  from all_tables t
 where t.owner = 'POSEIDON' and t.table_name like 'DPC_DFE%'
   and not exists (select 1 from all_tab_comments m
                    where m.owner = t.owner
                      and m.table_name = t.table_name
                      and m.comments is not null)
union all
select 'tabela sem PK', count(*)
  from all_tables t
 where t.owner = 'POSEIDON' and t.table_name like 'DPC_DFE%'
   and not exists (select 1 from all_constraints k
                    where k.owner = t.owner
                      and k.table_name = t.table_name
                      and k.constraint_type = 'P')
union all
select 'tabela sem PK automatica', count(*)
  from all_tables t
 where t.owner = 'POSEIDON' and t.table_name like 'DPC_DFE%'
   and not exists (select 1 from all_triggers g
                    where g.table_owner = t.owner
                      and g.table_name = t.table_name)
   and not exists (select 1 from all_tab_identity_cols i
                    where i.owner = t.owner
                      and i.table_name = t.table_name)
union all
select 'sequence sem tabela', count(*)
  from all_sequences q
 where q.sequence_owner = 'POSEIDON' and q.sequence_name like 'DPCS_DFE%'
   and not exists (select 1 from all_tables t
                    where t.owner = 'POSEIDON'
                      and t.table_name = 'DPC_' || substr(q.sequence_name, 6))
union all
select 'objeto invalido', count(*)
  from all_objects
 where owner = 'POSEIDON' and object_name like '%DFE%' and status <> 'VALID';

--  Se a linha "objeto invalido" vier diferente de zero, aqui esta quem e.
select object_name, object_type, status
  from all_objects
 where owner = 'POSEIDON' and object_name like '%DFE%' and status <> 'VALID';


-- ###########################################################################
--  3. O QUE NAO PODE EXISTIR
-- ###########################################################################
--  Tres objetos que o script antigo criava e que NAO devem estar aqui. Se
--  aparecer alguma linha, alguem rodou o install/alters antigos em vez do 01_01.
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
--  6. DADOS DO MOTOR  (o que o 01_02 carrega)
-- ###########################################################################
--  ESPERADO: 12 estabelecimentos gerais, 48 fluxos, todos pausados, 0 ativo.
--
--  A contagem e POR CNPJ, de proposito: assim o veredito nao muda quando um
--  estabelecimento for instalado depois (um par de empresas/). O total
--  da base vem ao lado como informacao.
with gerais as (
  select cod_dfe_empresa from poseidon.dpc_dfe_empresa
   where num_cnpj in ('66471517000177', '66471517000258', '66471517000339',
                 '66471517000924', '66471517001149', '66471517000843',
                 '66471517001491', '66471517002544', '66471517001653',
                 '66471517001734', '66471517001815', '66471517001904')
)
select (select count(*) from gerais)                                       as estabelecimentos_gerais,
       (select count(*) from poseidon.dpc_dfe_empresa)                     as total_na_base,
       (select count(*) from poseidon.dpc_dfe_cursor c
         where c.cod_dfe_empresa in (select cod_dfe_empresa from gerais))  as fluxos_gerais,
       (select count(*) from poseidon.dpc_dfe_cursor c
         where c.cod_dfe_empresa in (select cod_dfe_empresa from gerais)
           and c.status_sincronismo = 'P')                                 as pausados,
       (select count(*) from poseidon.dpc_dfe_cursor c
         where c.cod_dfe_empresa in (select cod_dfe_empresa from gerais)
           and c.status_sincronismo <> 'P')                                as ativos_ou_bloqueados
  from dual;

--  CNPJ geral que FALTA na base. ESPERADO: nenhuma linha.
select cnpj as cnpj_geral_ausente
--  Lista por UNION ALL, e nao por table(sys.odcivarchar2list(...)): aquele tipo
--  depende de grant de execucao em SYS, e a validacao nao deve parar por
--  privilegio que ninguem lembrou de conceder. Mesma razao da secao 2 do
--  01_02_estabelecimentos_dbeaver.sql.
  from (
         select '66471517000177' as cnpj from dual union all
         select '66471517000258' from dual union all
         select '66471517000339' from dual union all
         select '66471517000924' from dual union all
         select '66471517001149' from dual union all
         select '66471517000843' from dual union all
         select '66471517001491' from dual union all
         select '66471517002544' from dual union all
         select '66471517001653' from dual union all
         select '66471517001734' from dual union all
         select '66471517001815' from dual union all
         select '66471517001904' from dual
       ) l
 where not exists (select 1 from poseidon.dpc_dfe_empresa e
                    where e.num_cnpj = l.cnpj);

--  ESTABELECIMENTO ESPECIFICO, fora da carga geral. E INFORMACAO, nao erro:
--  depois de rodar os pares de empresas/ aqui aparecem a 29 e a 30, pausadas.
select e.nro_empresa,
       e.num_cnpj,
       e.sig_uf,
       e.created_by,
       count(c.cod_dfe_cursor)                                    as fluxos,
       sum(case when c.status_sincronismo = 'P' then 1 else 0 end) as pausados
  from poseidon.dpc_dfe_empresa e
  left join poseidon.dpc_dfe_cursor c on c.cod_dfe_empresa = e.cod_dfe_empresa
 where e.num_cnpj not in ('66471517000177', '66471517000258', '66471517000339',
                 '66471517000924', '66471517001149', '66471517000843',
                 '66471517001491', '66471517002544', '66471517001653',
                 '66471517001734', '66471517001815', '66471517001904')
 group by e.nro_empresa, e.num_cnpj, e.sig_uf, e.created_by
 order by e.nro_empresa;

--  Fluxo orfao - cursor apontando para empresa que nao existe. ESPERADO: 0.
select count(*) as cursor_orfao
  from poseidon.dpc_dfe_cursor c
 where not exists (select 1 from poseidon.dpc_dfe_empresa e
                    where e.cod_dfe_empresa = c.cod_dfe_empresa);

--  Fluxo por tipo. ESPERADO: 4 tipos, e a soma dos gerais = 48.
select cod_tipo_dfe, status_sincronismo, count(*) as qtd
  from poseidon.dpc_dfe_cursor
 group by cod_tipo_dfe, status_sincronismo
 order by cod_tipo_dfe, status_sincronismo;


-- ###########################################################################
--  7. PARAMETROS  (o que o 01_03 carrega)
-- ###########################################################################
--  ESPERADO: as 5 linhas, uma vez cada, com estes valores. Se faltar alguma, o
--  motor cai no default interno - e dois desses defaults MUDAM comportamento em
--  silencio (ver o cabecalho do 01_03_parametros_dbeaver.sql).
with esperado as (
  select 'dfe_max_bloqueios_dia' as nome, '10'     as valor from dual union all
  select 'dfe_max_consultas',          '200'              from dual union all
  select 'dfe_pausa_seg',              '30'               from dual union all
  select 'dfe_min_backoff_656',        '60'               from dual union all
  select 'dfe_conexao_erp',            'oracle'           from dual
), achado as (
  select lower(nome) as nome, valor, count(*) over (partition by lower(nome)) as vezes
    from poseidon.dpc_parametro
   where lower(nome) like 'dfe%'
)
select e.nome,
       e.valor as esperado,
       a.valor as achado,
       nvl(a.vezes, 0) as vezes,
       case when a.nome is null            then 'AUSENTE - o motor usa o default interno'
            when nvl(a.vezes, 0) > 1       then 'DUPLICADO - a tabela nao tem PK; apague a linha extra'
            when a.valor <> e.valor        then 'valor ajustado a mao (pode ser intencional)'
            else 'ok' end as situacao
  from esperado e
  left join achado a on a.nome = e.nome
 order by case when a.nome is null or nvl(a.vezes, 0) > 1 then 0 else 1 end, e.nome;

--  Parametro dfe_* que existe na base e NAO esta na lista acima. ESPERADO:
--  nenhuma linha. Se aparecer, ou e parametro novo que ninguem documentou, ou e
--  nome escrito errado - e nome errado o codigo nao le, cai no default.
select nome, valor
  from poseidon.dpc_parametro
 where lower(nome) like 'dfe%'
   and lower(nome) not in ('dfe_max_bloqueios_dia', 'dfe_max_consultas',
                           'dfe_pausa_seg', 'dfe_min_backoff_656',
                           'dfe_conexao_erp')
 order by nome;


-- ###########################################################################
--  8. IMPRESSAO DIGITAL - para comparar com HOMOLOGACAO
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
