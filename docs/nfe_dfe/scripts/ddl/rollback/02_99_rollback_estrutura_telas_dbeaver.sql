-- ============================================================================
--  ROLLBACK - ESTRUTURA DAS TELAS (ddl/rollback/02_99_rollback_estrutura_telas)
-- ============================================================================
--  DESTRUTIVO para a CONFIGURACAO: remove as 6 tabelas de tela e, com elas, quem ve o que (usuario_empresa,
--  usuario_aba, usuario_permissao), as colunas e os modelos salvos de cada usuario e o limiar do painel de alerta.
--  Nada disso deriva de outro dado: se apagar, e preciso reconfigurar (na producao, a tela Sefaz > Parametros).
--  Sem a permissao, a tela devolve lista VAZIA sem erro - e parece "nao ha nota no periodo".
--  Reexecutavel: cada drop e guardado por existencia. Conectado como POSEIDON.
-- ============================================================================


-- ###########################################################################
--  1. O QUE SERA PERDIDO
--  Rode e guarde o resultado. Depois de dropar, ninguem sabe o que havia.
-- ###########################################################################
select 'usuario_empresa' as tabela, count(*) as linhas from poseidon.dpc_dfe_usuario_empresa
union all select 'usuario_aba' as tabela, count(*) as linhas from poseidon.dpc_dfe_usuario_aba
union all select 'usuario_permissao' as tabela, count(*) as linhas from poseidon.dpc_dfe_usuario_permissao
union all select 'usuario_coluna' as tabela, count(*) as linhas from poseidon.dpc_dfe_usuario_coluna
union all select 'usuario_modelo' as tabela, count(*) as linhas from poseidon.dpc_dfe_usuario_modelo
union all select 'painel_alerta' as tabela, count(*) as linhas from poseidon.dpc_dfe_painel_alerta
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
   where owner = 'POSEIDON' and table_name = 'DPC_DFE_USUARIO_EMPRESA';
  if qtd = 1 then
    execute immediate 'drop table poseidon.dpc_dfe_usuario_empresa cascade constraints purge';
  end if;
end;

declare
  qtd number;
begin
  select count(*) into qtd from all_tables
   where owner = 'POSEIDON' and table_name = 'DPC_DFE_USUARIO_ABA';
  if qtd = 1 then
    execute immediate 'drop table poseidon.dpc_dfe_usuario_aba cascade constraints purge';
  end if;
end;

declare
  qtd number;
begin
  select count(*) into qtd from all_tables
   where owner = 'POSEIDON' and table_name = 'DPC_DFE_USUARIO_PERMISSAO';
  if qtd = 1 then
    execute immediate 'drop table poseidon.dpc_dfe_usuario_permissao cascade constraints purge';
  end if;
end;

declare
  qtd number;
begin
  select count(*) into qtd from all_tables
   where owner = 'POSEIDON' and table_name = 'DPC_DFE_USUARIO_COLUNA';
  if qtd = 1 then
    execute immediate 'drop table poseidon.dpc_dfe_usuario_coluna cascade constraints purge';
  end if;
end;

declare
  qtd number;
begin
  select count(*) into qtd from all_tables
   where owner = 'POSEIDON' and table_name = 'DPC_DFE_USUARIO_MODELO';
  if qtd = 1 then
    execute immediate 'drop table poseidon.dpc_dfe_usuario_modelo cascade constraints purge';
  end if;
end;

declare
  qtd number;
begin
  select count(*) into qtd from all_tables
   where owner = 'POSEIDON' and table_name = 'DPC_DFE_PAINEL_ALERTA';
  if qtd = 1 then
    execute immediate 'drop table poseidon.dpc_dfe_painel_alerta cascade constraints purge';
  end if;
end;

-- ###########################################################################
--  4. CONFERENCIA (esperado: nenhuma linha)
-- ###########################################################################
select object_type, object_name from all_objects
 where owner = 'POSEIDON' and (object_name = 'DPC_DFE_USUARIO_EMPRESA' or object_name = 'DPC_DFE_USUARIO_ABA' or object_name = 'DPC_DFE_USUARIO_PERMISSAO' or object_name = 'DPC_DFE_USUARIO_COLUNA' or object_name = 'DPC_DFE_USUARIO_MODELO' or object_name = 'DPC_DFE_PAINEL_ALERTA' or 1 = 0)
 order by 1, 2;
