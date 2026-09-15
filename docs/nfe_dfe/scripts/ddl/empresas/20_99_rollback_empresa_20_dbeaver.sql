-- ============================================================================
--  MODULO DFe - ROLLBACK DA EMPRESA 20 (ARQUIVO empresas/20_99)
-- ============================================================================
--  DESTRUTIVO, mas de escopo estreito: apaga o que o
--  29_01_empresa_20_dbeaver.sql criou, e nada mais. As outras empresas, a
--  estrutura e os parametros ficam intactos.
--
--  Como POSEIDON, arquivo inteiro com Alt+X. LIGUE O DBMS_OUTPUT: cada bloco
--  informa quantas linhas apagou, e e por ali que se ve o que aconteceu.
--
--  ==========================================================================
--   ORDEM: O ESPECIFICO ANTES DO GERAL
--  ==========================================================================
--      03_99_rollback_telas_dbeaver.sql        as telas, se for apagar tudo
--      29_99_rollback_empresa_20_dbeaver.sql   <- este
--      01_99_rollback_motor_dbeaver.sql        o motor, por ultimo
--
--  Por que nesta ordem: o certificado da empresa 20 mora em
--  poseidon.dpc_conta_certif_digital_emp, que e tabela do ERP. O 99 derruba as
--  13 tabelas dpc_dfe_* e NAO alcanca o certificado - rodar so o 01_99 deixaria
--  uma linha de certificado apontando para empresa que nao existe mais no
--  modulo.
--
--  Rodar na ordem trocada nao quebra: cada delete e guardado por existencia da
--  tabela, e informa no Output que nao havia o que apagar.
--
--  ==========================================================================
--   REEXECUTAVEL
--  ==========================================================================
--  Rodar duas vezes seguidas: a segunda apaga 0 linha em cada tabela e diz
--  isso. Rodar depois do 01_99: cada bloco avisa "tabela nao existe" em vez de
--  devolver ORA-00942.
--
--  ==========================================================================
--   ANTES DE RODAR
--  ==========================================================================
--  A secao 0 mostra o que sera perdido. Se houver documento capturado, leia o
--  aviso da secao 4 - o XML bruto vai embora com o cursor, e a janela de
--  retencao da SEFAZ e de ~90 dias.
-- ============================================================================


-- ###########################################################################
--  0. O QUE SERA PERDIDO
--  Somente leitura. Rode e leia ANTES de seguir.
-- ###########################################################################
select (select count(*) from poseidon.dpc_dfe_empresa
         where nro_empresa = 20)                                      as identidade,
       (select count(*) from poseidon.dpc_dfe_cursor c
          join poseidon.dpc_dfe_empresa e on e.cod_dfe_empresa = c.cod_dfe_empresa
         where e.nro_empresa = 20)                                    as fluxos,
       (select count(*) from poseidon.dpc_dfe_documento d
          join poseidon.dpc_dfe_empresa e on e.cod_dfe_empresa = d.cod_dfe_empresa
         where e.nro_empresa = 20)                                    as documentos_brutos,
       (select count(*) from poseidon.dpc_dfe_nota n
          join poseidon.dpc_dfe_empresa e on e.cod_dfe_empresa = n.cod_dfe_empresa
         where e.nro_empresa = 20)                                    as notas,
       (select count(*) from poseidon.dpc_conta_certif_digital_emp
         where cod_empresa = 20)                                      as certificados
  from dual;

--  Cursor com leitura ja avancada: se nro_ultimo_nsu > 0, apagar o cursor
--  significa PERDER a posicao. ESPERADO em base recem-instalada: nenhuma linha.
select c.cod_tipo_dfe, c.nro_ultimo_nsu, c.nro_maximo_nsu, c.dta_ultima_consulta
  from poseidon.dpc_dfe_cursor  c
  join poseidon.dpc_dfe_empresa e on e.cod_dfe_empresa = c.cod_dfe_empresa
 where e.nro_empresa = 20
   and nvl(c.nro_ultimo_nsu, 0) > 0
 order by c.cod_tipo_dfe;


-- ###########################################################################
--  1. FILHOS DE NOTA
--  Ordem filho antes de pai, sempre. DPC_DFE_EMITENTE nao entra em nenhuma
--  secao, e a ausencia e deliberada: fornecedor e COMPARTILHADO entre empresas
--  e nao tem cod_dfe_empresa - apagar por aqui removeria emitente das outras.
-- ###########################################################################


-- ---------- DPC_DFE_MANIFESTACAO ----------
declare
  qtd number;
begin
  select count(*) into qtd from all_tables
   where owner = 'POSEIDON' and table_name = 'DPC_DFE_MANIFESTACAO';

  if qtd = 0 then
    dbms_output.put_line('DPC_DFE_MANIFESTACAO: tabela nao existe - nada a apagar.');
  else
    execute immediate
      'delete from poseidon.dpc_dfe_manifestacao
          where cod_dfe_nota in (select n.cod_dfe_nota
                                   from poseidon.dpc_dfe_nota n
                                   join poseidon.dpc_dfe_empresa e
                                     on e.cod_dfe_empresa = n.cod_dfe_empresa
                                  where e.nro_empresa = 20)';
    dbms_output.put_line('DPC_DFE_MANIFESTACAO: ' || sql%rowcount || ' linha(s) apagada(s).');
  end if;
end;


-- ---------- DPC_DFE_NOTA_ITEM ----------
declare
  qtd number;
begin
  select count(*) into qtd from all_tables
   where owner = 'POSEIDON' and table_name = 'DPC_DFE_NOTA_ITEM';

  if qtd = 0 then
    dbms_output.put_line('DPC_DFE_NOTA_ITEM: tabela nao existe - nada a apagar.');
  else
    execute immediate
      'delete from poseidon.dpc_dfe_nota_item
          where cod_dfe_nota in (select n.cod_dfe_nota
                                   from poseidon.dpc_dfe_nota n
                                   join poseidon.dpc_dfe_empresa e
                                     on e.cod_dfe_empresa = n.cod_dfe_empresa
                                  where e.nro_empresa = 20)';
    dbms_output.put_line('DPC_DFE_NOTA_ITEM: ' || sql%rowcount || ' linha(s) apagada(s).');
  end if;
end;


-- ###########################################################################
--  2. FILHOS DE CT-e
-- ###########################################################################


-- ---------- DPC_DFE_CTE_EVENTO ----------
declare
  qtd number;
begin
  select count(*) into qtd from all_tables
   where owner = 'POSEIDON' and table_name = 'DPC_DFE_CTE_EVENTO';

  if qtd = 0 then
    dbms_output.put_line('DPC_DFE_CTE_EVENTO: tabela nao existe - nada a apagar.');
  else
    execute immediate
      'delete from poseidon.dpc_dfe_cte_evento
          where cod_dfe_empresa in (select cod_dfe_empresa from poseidon.dpc_dfe_empresa
                                     where nro_empresa = 20)';
    dbms_output.put_line('DPC_DFE_CTE_EVENTO: ' || sql%rowcount || ' linha(s) apagada(s).');
  end if;
end;


-- ---------- DPC_DFE_CTE_NFE ----------
declare
  qtd number;
begin
  select count(*) into qtd from all_tables
   where owner = 'POSEIDON' and table_name = 'DPC_DFE_CTE_NFE';

  if qtd = 0 then
    dbms_output.put_line('DPC_DFE_CTE_NFE: tabela nao existe - nada a apagar.');
  else
    execute immediate
      'delete from poseidon.dpc_dfe_cte_nfe
          where cod_dfe_cte in (select t.cod_dfe_cte
                                  from poseidon.dpc_dfe_cte t
                                  join poseidon.dpc_dfe_empresa e
                                    on e.cod_dfe_empresa = t.cod_dfe_empresa
                                 where e.nro_empresa = 20)';
    dbms_output.put_line('DPC_DFE_CTE_NFE: ' || sql%rowcount || ' linha(s) apagada(s).');
  end if;
end;


-- ###########################################################################
--  3. NORMALIZADO
-- ###########################################################################


-- ---------- DPC_DFE_EVENTO ----------
declare
  qtd number;
begin
  select count(*) into qtd from all_tables
   where owner = 'POSEIDON' and table_name = 'DPC_DFE_EVENTO';

  if qtd = 0 then
    dbms_output.put_line('DPC_DFE_EVENTO: tabela nao existe - nada a apagar.');
  else
    execute immediate
      'delete from poseidon.dpc_dfe_evento
          where cod_dfe_empresa in (select cod_dfe_empresa from poseidon.dpc_dfe_empresa
                                     where nro_empresa = 20)';
    dbms_output.put_line('DPC_DFE_EVENTO: ' || sql%rowcount || ' linha(s) apagada(s).');
  end if;
end;


-- ---------- DPC_DFE_NOTA ----------
declare
  qtd number;
begin
  select count(*) into qtd from all_tables
   where owner = 'POSEIDON' and table_name = 'DPC_DFE_NOTA';

  if qtd = 0 then
    dbms_output.put_line('DPC_DFE_NOTA: tabela nao existe - nada a apagar.');
  else
    execute immediate
      'delete from poseidon.dpc_dfe_nota
          where cod_dfe_empresa in (select cod_dfe_empresa from poseidon.dpc_dfe_empresa
                                     where nro_empresa = 20)';
    dbms_output.put_line('DPC_DFE_NOTA: ' || sql%rowcount || ' linha(s) apagada(s).');
  end if;
end;


-- ---------- DPC_DFE_CTE ----------
declare
  qtd number;
begin
  select count(*) into qtd from all_tables
   where owner = 'POSEIDON' and table_name = 'DPC_DFE_CTE';

  if qtd = 0 then
    dbms_output.put_line('DPC_DFE_CTE: tabela nao existe - nada a apagar.');
  else
    execute immediate
      'delete from poseidon.dpc_dfe_cte
          where cod_dfe_empresa in (select cod_dfe_empresa from poseidon.dpc_dfe_empresa
                                     where nro_empresa = 20)';
    dbms_output.put_line('DPC_DFE_CTE: ' || sql%rowcount || ' linha(s) apagada(s).');
  end if;
end;


-- ---------- DPC_DFE_NFSE ----------
declare
  qtd number;
begin
  select count(*) into qtd from all_tables
   where owner = 'POSEIDON' and table_name = 'DPC_DFE_NFSE';

  if qtd = 0 then
    dbms_output.put_line('DPC_DFE_NFSE: tabela nao existe - nada a apagar.');
  else
    execute immediate
      'delete from poseidon.dpc_dfe_nfse
          where cod_dfe_empresa in (select cod_dfe_empresa from poseidon.dpc_dfe_empresa
                                     where nro_empresa = 20)';
    dbms_output.put_line('DPC_DFE_NFSE: ' || sql%rowcount || ' linha(s) apagada(s).');
  end if;
end;


-- ###########################################################################
--  4. AQUISICAO
--  ATENCAO: aqui vai embora o XML bruto. A SEFAZ retem por ~90 dias e o cursor
--  existe SOMENTE em DPC_DFE_CURSOR - depois deste delete ninguem sabe de onde
--  retomar. Se a intencao for apenas PARAR a captura, nao rode este arquivo:
--  pause os fluxos com
--
--      update poseidon.dpc_dfe_cursor set status_sincronismo = 'P' where ...
-- ###########################################################################


-- ---------- DPC_DFE_DOCUMENTO ----------
declare
  qtd number;
begin
  select count(*) into qtd from all_tables
   where owner = 'POSEIDON' and table_name = 'DPC_DFE_DOCUMENTO';

  if qtd = 0 then
    dbms_output.put_line('DPC_DFE_DOCUMENTO: tabela nao existe - nada a apagar.');
  else
    execute immediate
      'delete from poseidon.dpc_dfe_documento
          where cod_dfe_empresa in (select cod_dfe_empresa from poseidon.dpc_dfe_empresa
                                     where nro_empresa = 20)';
    dbms_output.put_line('DPC_DFE_DOCUMENTO: ' || sql%rowcount || ' linha(s) apagada(s).');
  end if;
end;


-- ---------- DPC_DFE_EXECUCAO ----------
declare
  qtd number;
begin
  select count(*) into qtd from all_tables
   where owner = 'POSEIDON' and table_name = 'DPC_DFE_EXECUCAO';

  if qtd = 0 then
    dbms_output.put_line('DPC_DFE_EXECUCAO: tabela nao existe - nada a apagar.');
  else
    execute immediate
      'delete from poseidon.dpc_dfe_execucao
          where cod_dfe_empresa in (select cod_dfe_empresa from poseidon.dpc_dfe_empresa
                                     where nro_empresa = 20)';
    dbms_output.put_line('DPC_DFE_EXECUCAO: ' || sql%rowcount || ' linha(s) apagada(s).');
  end if;
end;


-- ###########################################################################
--  5. CURSOR, IDENTIDADE E CERTIFICADO
--  Os tres filtram tambem por created_by = 'CADASTRO DFE': so o que o
--  29_01_empresa_20_dbeaver.sql criou e removido. Se alguem cadastrou a empresa 20
--  por outro caminho, a linha dele fica.
--
--  Esse filtro so passou a funcionar em 09/09/2026. Antes a empresa 20 nascia
--  no 02_carga_inicial com 'CARGA INICIAL' e este rollback procurava
--  'CADASTRO DFE' - nao apagava nada, e a conferencia acusava sem explicar.
-- ###########################################################################


-- ---------- DPC_DFE_CURSOR ----------
declare
  qtd number;
begin
  select count(*) into qtd from all_tables
   where owner = 'POSEIDON' and table_name = 'DPC_DFE_CURSOR';

  if qtd = 0 then
    dbms_output.put_line('DPC_DFE_CURSOR: tabela nao existe - nada a apagar.');
  else
    execute immediate
      'delete from poseidon.dpc_dfe_cursor
          where cod_dfe_empresa in (select cod_dfe_empresa from poseidon.dpc_dfe_empresa
                                     where nro_empresa = 20)
            and created_by = ''CADASTRO DFE''';
    dbms_output.put_line('DPC_DFE_CURSOR: ' || sql%rowcount || ' linha(s) apagada(s).');
  end if;
end;


-- ---------- DPC_DFE_EMPRESA ----------
declare
  qtd number;
begin
  select count(*) into qtd from all_tables
   where owner = 'POSEIDON' and table_name = 'DPC_DFE_EMPRESA';

  if qtd = 0 then
    dbms_output.put_line('DPC_DFE_EMPRESA: tabela nao existe - nada a apagar.');
  else
    execute immediate
      'delete from poseidon.dpc_dfe_empresa
          where nro_empresa = 20
            and created_by = ''CADASTRO DFE''';
    dbms_output.put_line('DPC_DFE_EMPRESA: ' || sql%rowcount || ' linha(s) apagada(s).');
  end if;
end;


--  Esta e a razao de existir um rollback proprio para a empresa: a tabela de
--  certificado e do ERP, e o 01_99_rollback_motor_dbeaver.sql - que derruba as 13
--  tabelas dpc_dfe_* - nao chega nela. Sem este delete, sobraria uma linha de
--  certificado apontando para uma empresa que nao existe mais no modulo.
-- ---------- DPC_CONTA_CERTIF_DIGITAL_EMP ----------
declare
  qtd number;
begin
  select count(*) into qtd from all_tables
   where owner = 'POSEIDON' and table_name = 'DPC_CONTA_CERTIF_DIGITAL_EMP';

  if qtd = 0 then
    dbms_output.put_line('DPC_CONTA_CERTIF_DIGITAL_EMP: tabela nao existe - nada a apagar.');
  else
    execute immediate
      'delete from poseidon.dpc_conta_certif_digital_emp
          where cod_empresa = 20
            and created_by = ''CADASTRO DFE''';
    dbms_output.put_line('DPC_CONTA_CERTIF_DIGITAL_EMP: ' || sql%rowcount || ' linha(s) apagada(s).');
  end if;
end;


commit;


-- ###########################################################################
--  6. CONFERENCIA
-- ###########################################################################
--  ESPERADO: todas as contagens em 0.
select (select count(*) from poseidon.dpc_dfe_empresa
         where nro_empresa = 20)                                      as identidade,
       (select count(*) from poseidon.dpc_dfe_cursor c
          join poseidon.dpc_dfe_empresa e on e.cod_dfe_empresa = c.cod_dfe_empresa
         where e.nro_empresa = 20)                                    as fluxos,
       (select count(*) from poseidon.dpc_conta_certif_digital_emp
         where cod_empresa = 20)                                      as certificado
  from dual;

--  Cinto de seguranca: cursor orfao em QUALQUER empresa. ESPERADO: 0.
--  Diferente de 0 significa que algum rollback deixou lixo apontando para
--  empresa inexistente.
select count(*) as cursor_orfao
  from poseidon.dpc_dfe_cursor c
 where not exists (select 1 from poseidon.dpc_dfe_empresa e
                    where e.cod_dfe_empresa = c.cod_dfe_empresa);

--  O GERAL tem de estar intacto: ESPERADO 12 estabelecimentos e 48 fluxos.
select (select count(*) from poseidon.dpc_dfe_empresa)                as estabelecimentos,
       (select count(*) from poseidon.dpc_dfe_cursor)                 as fluxos
  from dual;
-- ============================================================================
