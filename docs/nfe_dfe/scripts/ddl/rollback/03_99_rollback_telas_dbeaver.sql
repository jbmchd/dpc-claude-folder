-- ============================================================================
--  MODULO DFe - ROLLBACK DAS TELAS (ARQUIVO 03_99)
-- ============================================================================
--  DESTRUTIVO. Derruba as tres tabelas do bloco de TELAS:
--
--      dpc_dfe_usuario_empresa    quais filiais o usuario ve
--      dpc_dfe_usuario_aba        quais categorias o usuario ve
--      dpc_dfe_painel_alerta      limiar de dias por filial
--
--  ==========================================================================
--   PENSE DUAS VEZES: ISTO APAGA PERMISSAO, NAO DADO DE CAPTURA
--  ==========================================================================
--  O que se perde aqui nao volta rodando o 03_01. Aquele arquivo recria a
--  ESTRUTURA; quem preenche as linhas e uma pessoa, na tela Sefaz > Parametros,
--  uma por uma. Em 09/09/2026 eram 45 linhas de permissao de filial e 16 de
--  categoria, para 4 usuarios.
--
--  E a perda e SILENCIOSA do outro lado: usuario sem linha em
--  dpc_dfe_usuario_empresa nao ve nada nas telas, e nao recebe erro - o
--  repositorio curto-circuita e devolve HTTP 200 com lista vazia, que e
--  indistinguivel de "nao ha nota no periodo". Quem perder essas linhas vai
--  ouvir "a tela parou de mostrar meus dados", nao "deu erro".
--
--  A SECAO 0 GERA O SCRIPT DE VOLTA. Rode, copie o resultado e guarde antes de
--  seguir. E a unica coisa que reconstroi isso sem digitar tudo de novo.
--
--  ==========================================================================
--   ORDEM ENTRE OS ROLLBACKS
--  ==========================================================================
--      03_99_rollback_telas_dbeaver.sql        <- este, o bloco de telas
--      empresas/*_99_rollback_empresa_*.sql    cada empresa
--      01_99_rollback_motor_dbeaver.sql        o motor
--
--  Entre os tres nao ha dependencia de FK: as tres tabelas daqui referenciam
--  filial por nroempresa do ERP, sem constraint para dpc_dfe_empresa. A ordem
--  acima e so do mais especifico para o mais geral.
--
--  Na pratica: para apagar o modulo INTEIRO, rode 97, 98 e 99. Para apagar so
--  o motor e preservar quem ve o que, rode 98 e 99 e NAO rode este.
--
--  ==========================================================================
--   REEXECUTAVEL
--  ==========================================================================
--  Cada drop e guardado por existencia, e cobre os DOIS nomes - o novo e o
--  antigo (dpc_sefaz_*), para o caso de a base nunca ter passado pelo 03_01.
--  Rodar duas vezes seguidas nao devolve erro: a segunda nao acha o que apagar.
--
--  Como POSEIDON, arquivo inteiro com Alt+X. LIGUE O DBMS_OUTPUT.
-- ============================================================================


-- ###########################################################################
--  0. O QUE SERA PERDIDO, E COMO GUARDAR
-- ###########################################################################

--  0a. Contagem. Somente leitura.
select (select count(*) from all_tables where owner = 'POSEIDON'
         and table_name in ('DPC_DFE_USUARIO_EMPRESA', 'DPC_SEFAZ_USUARIO_EMPRESA'))  as tem_usuario_empresa,
       (select count(*) from all_tables where owner = 'POSEIDON'
         and table_name in ('DPC_DFE_USUARIO_ABA', 'DPC_SEFAZ_USUARIO_ABA'))          as tem_usuario_aba,
       (select count(*) from all_tables where owner = 'POSEIDON'
         and table_name in ('DPC_DFE_PAINEL_ALERTA', 'DPC_SEFAZ_EMPRESA_ALERTA'))     as tem_painel_alerta
  from dual;

--  0b. O SCRIPT DE VOLTA. Rode, copie TODAS as linhas do resultado e guarde num
--      arquivo antes de seguir. Depois do drop, isto e o unico caminho de
--      reconstrucao que nao passa por digitar na tela uma por uma.
--
--      Se a sua base ainda esta com os nomes antigos, troque dpc_dfe_ por
--      dpc_sefaz_ no FROM destes tres selects.
select 'insert into poseidon.dpc_dfe_usuario_empresa (nroempresa, usuario, created_by, created_at) values ('
       || nroempresa || ', ''' || usuario || ''', ''' || created_by || ''', to_date('''
       || to_char(created_at, 'dd/mm/yyyy hh24:mi:ss') || ''', ''dd/mm/yyyy hh24:mi:ss''));' as script_de_volta
  from poseidon.dpc_dfe_usuario_empresa
 order by nroempresa, usuario;

select 'insert into poseidon.dpc_dfe_usuario_aba (usuario, aba, created_by, created_at) values ('
       || '''' || usuario || ''', ''' || aba || ''', ''' || created_by || ''', to_date('''
       || to_char(created_at, 'dd/mm/yyyy hh24:mi:ss') || ''', ''dd/mm/yyyy hh24:mi:ss''));' as script_de_volta
  from poseidon.dpc_dfe_usuario_aba
 order by usuario, aba;

select 'insert into poseidon.dpc_dfe_painel_alerta (nroempresa, dias, cor_no_periodo, cor_fora_periodo, created_by, created_at) values ('
       || nroempresa || ', ' || dias || ', '
       || nvl('''' || cor_no_periodo || '''', 'null') || ', '
       || nvl('''' || cor_fora_periodo || '''', 'null') || ', '
       || '''' || created_by || ''', to_date('''
       || to_char(created_at, 'dd/mm/yyyy hh24:mi:ss') || ''', ''dd/mm/yyyy hh24:mi:ss''));' as script_de_volta
  from poseidon.dpc_dfe_painel_alerta
 order by nroempresa;

--  0c. Quem perde acesso, por usuario. Leia antes de apagar: sao estas pessoas
--      que vao dizer "a tela parou de mostrar meus dados".
select usuario,
       count(*)                     as filiais,
       min(nroempresa)              as menor,
       max(nroempresa)              as maior
  from poseidon.dpc_dfe_usuario_empresa
 group by usuario
 order by usuario;


-- ###########################################################################
--  1. DROP
--  Cada bloco cobre o nome NOVO e o ANTIGO, e so age se achar.
-- ###########################################################################

-- ---------- usuario x empresa ----------
declare
  qtd number;
begin
  for t in (select 'DPC_DFE_USUARIO_EMPRESA' as tab from dual union all
            select 'DPC_SEFAZ_USUARIO_EMPRESA'      from dual) loop
    select count(*) into qtd from all_tables
     where owner = 'POSEIDON' and table_name = t.tab;

    if qtd = 1 then
      execute immediate 'drop table poseidon.' || t.tab || ' cascade constraints purge';
      dbms_output.put_line('derrubada: ' || lower(t.tab));
    end if;
  end loop;
end;

-- ---------- usuario x aba ----------
declare
  qtd number;
begin
  for t in (select 'DPC_DFE_USUARIO_ABA' as tab from dual union all
            select 'DPC_SEFAZ_USUARIO_ABA'      from dual) loop
    select count(*) into qtd from all_tables
     where owner = 'POSEIDON' and table_name = t.tab;

    if qtd = 1 then
      execute immediate 'drop table poseidon.' || t.tab || ' cascade constraints purge';
      dbms_output.put_line('derrubada: ' || lower(t.tab));
    end if;
  end loop;
end;

-- ---------- limiar do painel ----------
declare
  qtd number;
begin
  for t in (select 'DPC_DFE_PAINEL_ALERTA' as tab from dual union all
            select 'DPC_SEFAZ_EMPRESA_ALERTA'     from dual) loop
    select count(*) into qtd from all_tables
     where owner = 'POSEIDON' and table_name = t.tab;

    if qtd = 1 then
      execute immediate 'drop table poseidon.' || t.tab || ' cascade constraints purge';
      dbms_output.put_line('derrubada: ' || lower(t.tab));
    end if;
  end loop;
end;


-- ###########################################################################
--  2. CONFERENCIA
-- ###########################################################################
--  ESPERADO: nenhuma linha. Nem com o nome novo, nem com o antigo.
select table_name
  from all_tables
 where owner = 'POSEIDON'
   and table_name in ('DPC_DFE_USUARIO_EMPRESA', 'DPC_DFE_USUARIO_ABA', 'DPC_DFE_PAINEL_ALERTA',
                      'DPC_SEFAZ_USUARIO_EMPRESA', 'DPC_SEFAZ_USUARIO_ABA', 'DPC_SEFAZ_EMPRESA_ALERTA')
 order by table_name;

--  A sequence da identity cai junto com a tabela (o purge cuida disso).
--  ESPERADO: nenhuma linha orfa comecando com ISEQ$$ para estas tabelas.
select object_name, object_type
  from all_objects
 where owner = 'POSEIDON'
   and object_name like 'ISEQ$$%'
   and not exists (select 1 from all_tab_identity_cols i
                    where i.owner = 'POSEIDON'
                      and i.sequence_name = all_objects.object_name)
 order by object_name;

--  O MOTOR fica intacto. ESPERADO: 13 tabelas, 13 sequences, 13 triggers.
select (select count(*) from all_tables
         where owner = 'POSEIDON' and table_name like 'DPC\_DFE\_%' escape '\'
           and table_name not in ('DPC_DFE_USUARIO_EMPRESA', 'DPC_DFE_USUARIO_ABA',
                                  'DPC_DFE_PAINEL_ALERTA'))                       as tabelas_motor,
       (select count(*) from all_sequences
         where sequence_owner = 'POSEIDON' and sequence_name like 'DPCS\_DFE%' escape '\') as sequences_motor,
       (select count(*) from all_triggers
         where owner = 'POSEIDON' and trigger_name like 'DPCT\_DFE%' escape '\')  as triggers_motor
  from dual;
-- ============================================================================
