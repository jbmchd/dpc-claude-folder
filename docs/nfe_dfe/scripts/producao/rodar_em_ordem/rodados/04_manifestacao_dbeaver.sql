-- ============================================================================
--  MODULO DFe - MANIFESTACAO DO DESTINATARIO (ARQUIVO 04_01)
-- ============================================================================
--  Fase 1 da manifestacao automatica: so a FUNDACAO. Nada passa a manifestar
--  sozinho por causa deste arquivo - as trancas continuam fechadas e o
--  dfe:manifestar segue fora do agendamento.
--
--  ==========================================================================
--   POR QUE ESTAS COLUNAS
--  ==========================================================================
--  A equipe fiscal definiu dois gatilhos automaticos: Ciencia (210210) ao
--  capturar a nota, e Confirmacao (210200) ao registrar no ERP. A tabela
--  dpc_dfe_manifestacao, como esta, NAO comporta isso:
--
--   - a UK e (cod_dfe_nota, cod_tipo_evento), sem sequencia. A Ciencia e
--     sempre nSeqEvento=1, mas Confirmacao, Desconhecimento e Operacao nao
--     Realizada sao seq=n - sem a coluna, a segunda ocorrencia do mesmo tipo
--     na mesma nota e impossivel de registrar, e o envio volta rejeicao 594.
--   - a justificativa do 210240 nao e persistida em lugar nenhum, embora seja
--     o dado juridicamente relevante daquele evento.
--   - nao ha onde guardar o dhRegEvento (a hora que a SEFAZ registrou, que e
--     diferente da hora em que NOS enviamos) nem o idLote.
--   - o indice DPC_DFE_MANIF_IX1 (status_envio, dta_ultima_tentativa) foi
--     desenhado como fila de reenvio e nunca teve consumidor, porque falta
--     coluna de agendamento da proxima tentativa.
--
--  E o status_manifestar de dpc_dfe_empresa e uma tranca unica: liga os
--  quatro eventos de uma vez. Nao da para liberar so a Ciencia numa filial
--  piloto e segurar a Confirmacao, que tem peso declaratorio maior.
--
--  ==========================================================================
--   UM CAMINHO SO
--  ==========================================================================
--  Idempotente: rodar duas vezes produz o mesmo resultado da primeira. Cada
--  coluna e conferida uma a uma, cada constraint so e criada se faltar.
--
--  As mesmas colunas foram acrescentadas ao 01_01_estrutura_dbeaver.sql. Sem
--  isso, um rebuild de homolog recriaria a base sem elas e o motor quebraria
--  em silencio - foi o que aconteceu em 09/09/2026 com o dfe_conexao_erp.
--
--  ==========================================================================
--   COMO RODAR (DBeaver)
--  ==========================================================================
--  Conectado como POSEIDON, arquivo INTEIRO com Alt+X. Sem "/" para terminar
--  bloco. E CRLF de proposito: em LF o divisor de statements do DBeaver corta
--  o bloco PL/SQL no fim do IF e devolve PLS-00103.
--
--  LIGUE O DBMS_OUTPUT (aba Output do editor de SQL).
--
--  O COMMIT e explicito, no fim. Ao final ha um SELECT de conferencia.
-- ============================================================================


-- ============================================================================
--  SECAO 1 - COLUNAS NOVAS EM DPC_DFE_MANIFESTACAO
-- ============================================================================
-- nro_seq_evento nasce com default 1 e NOT NULL: as linhas que ja existem
-- foram todas enviadas com nSeqEvento=1, entao o default as preenche correto.
declare
  qtd number;
begin
  for c in (
    select 'nro_seq_evento'        as nome, 'NUMBER default 1 not null' as def from dual union all
    select 'dsc_justificativa'          , 'VARCHAR2(255)'                     from dual union all
    select 'dta_registro_evento'        , 'TIMESTAMP(6)'                      from dual union all
    select 'cod_dfe_empresa'            , 'NUMBER'                            from dual union all
    select 'dsc_id_lote'                , 'VARCHAR2(20)'                      from dual union all
    select 'dta_proxima_tentativa'      , 'TIMESTAMP(6)'                      from dual
  ) loop
    begin
      select count(*) into qtd from all_tab_columns
       where owner = 'POSEIDON' and table_name = 'DPC_DFE_MANIFESTACAO'
         and column_name = upper(c.nome);

      if qtd = 0 then
        execute immediate 'alter table poseidon.dpc_dfe_manifestacao add ('
                          || c.nome || ' ' || c.def || ')';
        dbms_output.put_line('DPC_DFE_MANIFESTACAO: acrescentada -> ' || c.nome);
      else
        dbms_output.put_line('DPC_DFE_MANIFESTACAO: ja existia   -> ' || c.nome);
      end if;
    exception
      when others then
        dbms_output.put_line('DPC_DFE_MANIFESTACAO: FALHOU em ' || c.nome || ' -> ' || sqlerrm);
    end;
  end loop;
end;

-- ============================================================================
--  SECAO 2 - BACKFILL DE COD_DFE_EMPRESA
-- ============================================================================
-- Coluna denormalizada de proposito: a empresa e derivavel pela nota, mas
-- toda consulta por empresa exigiria join com dpc_dfe_nota, inclusive a do
-- freio que precisa contar bloqueios por CNPJ.
declare
  qtd number;
begin
  update poseidon.dpc_dfe_manifestacao m
     set m.cod_dfe_empresa = (select n.cod_dfe_empresa
                                from poseidon.dpc_dfe_nota n
                               where n.cod_dfe_nota = m.cod_dfe_nota)
   where m.cod_dfe_empresa is null;

  qtd := sql%rowcount;
  dbms_output.put_line('DPC_DFE_MANIFESTACAO: cod_dfe_empresa preenchido em ' || qtd || ' linha(s)');
end;

-- ============================================================================
--  SECAO 3 - UK PASSA A INCLUIR A SEQUENCIA
-- ============================================================================
-- De (cod_dfe_nota, cod_tipo_evento) para (cod_dfe_nota, cod_tipo_evento,
-- nro_seq_evento). Esta e a unica barreira anti-duplicidade que nao depende
-- de alguem lembrar de checar antes de enviar, entao a recriacao e drop+add
-- no mesmo bloco, sem janela em que a tabela fique sem ela.
declare
  qtd  number;
  cols varchar2(400);
begin
  select count(*) into qtd from all_constraints
   where owner = 'POSEIDON' and constraint_name = 'DPC_DFE_MANIF_UK1';

  if qtd = 0 then
    execute immediate q'[alter table poseidon.dpc_dfe_manifestacao add constraint DPC_DFE_MANIF_UK1 unique (cod_dfe_nota, cod_tipo_evento, nro_seq_evento) using index tablespace TSD_POSEIDON]';
    dbms_output.put_line('DPC_DFE_MANIF_UK1: criada com nro_seq_evento');
  else
    select listagg(column_name, ',') within group (order by position)
      into cols
      from all_cons_columns
     where owner = 'POSEIDON' and constraint_name = 'DPC_DFE_MANIF_UK1';

    if instr(upper(cols), 'NRO_SEQ_EVENTO') = 0 then
      execute immediate 'alter table poseidon.dpc_dfe_manifestacao drop constraint DPC_DFE_MANIF_UK1 drop index';
      execute immediate q'[alter table poseidon.dpc_dfe_manifestacao add constraint DPC_DFE_MANIF_UK1 unique (cod_dfe_nota, cod_tipo_evento, nro_seq_evento) using index tablespace TSD_POSEIDON]';
      dbms_output.put_line('DPC_DFE_MANIF_UK1: recriada, antes era (' || cols || ')');
    else
      dbms_output.put_line('DPC_DFE_MANIF_UK1: ja inclui nro_seq_evento');
    end if;
  end if;
exception
  when others then
    dbms_output.put_line('DPC_DFE_MANIF_UK1: FALHOU -> ' || sqlerrm);
end;

-- ============================================================================
--  SECAO 4 - TRANCA POR EVENTO EM DPC_DFE_EMPRESA
-- ============================================================================
-- status_manifestar continua sendo a chave-mestra: sem ele em 'S' a empresa
-- nao manifesta de jeito nenhum, nem manualmente pela tela. As duas colunas
-- novas governam SO a automacao, e so dos dois eventos que serao automaticos.
-- Desconhecimento e Operacao nao Realizada nunca serao automaticos: exigem
-- decisao caso a caso da contabilidade.
declare
  qtd number;
begin
  for c in (
    select 'status_manif_auto_ciencia'     as nome, 'VARCHAR2(1) default ''N'' not null' as def from dual union all
    select 'status_manif_auto_confirmacao'      , 'VARCHAR2(1) default ''N'' not null'         from dual
  ) loop
    begin
      select count(*) into qtd from all_tab_columns
       where owner = 'POSEIDON' and table_name = 'DPC_DFE_EMPRESA'
         and column_name = upper(c.nome);

      if qtd = 0 then
        execute immediate 'alter table poseidon.dpc_dfe_empresa add ('
                          || c.nome || ' ' || c.def || ')';
        dbms_output.put_line('DPC_DFE_EMPRESA: acrescentada -> ' || c.nome);
      else
        dbms_output.put_line('DPC_DFE_EMPRESA: ja existia   -> ' || c.nome);
      end if;
    exception
      when others then
        dbms_output.put_line('DPC_DFE_EMPRESA: FALHOU em ' || c.nome || ' -> ' || sqlerrm);
    end;
  end loop;
end;

declare
  qtd number;
begin
  select count(*) into qtd from all_constraints
   where owner = 'POSEIDON' and constraint_name = 'DPC_DFE_EMPRESA_CK3';

  if qtd = 0 then
    execute immediate q'[alter table poseidon.dpc_dfe_empresa add constraint DPC_DFE_EMPRESA_CK3 check (status_manif_auto_ciencia in ('N','S'))]';
    dbms_output.put_line('DPC_DFE_EMPRESA_CK3: criada');
  else
    dbms_output.put_line('DPC_DFE_EMPRESA_CK3: ja existia');
  end if;
exception
  when others then
    dbms_output.put_line('DPC_DFE_EMPRESA_CK3: FALHOU -> ' || sqlerrm);
end;

declare
  qtd number;
begin
  select count(*) into qtd from all_constraints
   where owner = 'POSEIDON' and constraint_name = 'DPC_DFE_EMPRESA_CK4';

  if qtd = 0 then
    execute immediate q'[alter table poseidon.dpc_dfe_empresa add constraint DPC_DFE_EMPRESA_CK4 check (status_manif_auto_confirmacao in ('N','S'))]';
    dbms_output.put_line('DPC_DFE_EMPRESA_CK4: criada');
  else
    dbms_output.put_line('DPC_DFE_EMPRESA_CK4: ja existia');
  end if;
exception
  when others then
    dbms_output.put_line('DPC_DFE_EMPRESA_CK4: FALHOU -> ' || sqlerrm);
end;

-- ============================================================================
--  SECAO 5 - COMENTARIOS
-- ============================================================================
comment on column poseidon.dpc_dfe_manifestacao.nro_seq_evento is
  'Numero de sequencia do evento (nSeqEvento). Ciencia da Operacao e SEMPRE 1, so pode existir uma por NF-e. Confirmacao, Desconhecimento e Operacao nao Realizada admitem seq=n. Calculado a partir DESTA tabela, nunca de dpc_dfe_evento: a SEFAZ nao devolve ao destinatario o evento da propria manifestacao (NT 2014.002, tabela de distribuicao - Eventos de Manifestacao do Destinatario: Emitente Sim, Destinatario Nao).';

comment on column poseidon.dpc_dfe_manifestacao.dsc_justificativa is
  'Texto do xJust, obrigatorio no evento 210240 (Operacao nao Realizada) com no minimo 15 caracteres. E o dado juridicamente relevante daquele evento e por isso e persistido; antes da Fase 1 ele so existia no parametro de linha de comando.';

comment on column poseidon.dpc_dfe_manifestacao.dta_registro_evento is
  'dhRegEvento: quando a SEFAZ REGISTROU o evento. Diferente de DTA_ENVIO, que e quando nos enviamos.';

comment on column poseidon.dpc_dfe_manifestacao.cod_dfe_empresa is
  'Empresa que manifestou. Denormalizado de dpc_dfe_nota de proposito, para o freio contar bloqueios por CNPJ sem join.';

comment on column poseidon.dpc_dfe_manifestacao.dsc_id_lote is
  'idLote do envelope envEvento. Informado explicitamente no envio: o autogerado da sped-nfe e date(YmdHis) mais um digito aleatorio, e colide. Sem ele nao da para reconstituir qual envelope gerou qual retorno.';

comment on column poseidon.dpc_dfe_manifestacao.dta_proxima_tentativa is
  'Quando a fila de reenvio pode tentar de novo. Com STATUS_ENVIO e DTA_ULTIMA_TENTATIVA fecha o indice DPC_DFE_MANIF_IX1, que existia desde a criacao da tabela e nunca teve consumidor.';

comment on column poseidon.dpc_dfe_empresa.status_manif_auto_ciencia is
  'N-Nao | S-Sim. Habilita a Ciencia da Operacao (210210) AUTOMATICA para esta empresa. Exige status_manifestar = S junto: aquele e a chave-mestra, este governa so a automacao. Default N.';

comment on column poseidon.dpc_dfe_empresa.status_manif_auto_confirmacao is
  'N-Nao | S-Sim. Habilita a Confirmacao da Operacao (210200) AUTOMATICA para esta empresa, disparada quando a nota chega a ESCRITURADA no ERP. Exige status_manifestar = S junto. Default N, e so deve ser ligado depois da Ciencia estar estavel na filial piloto: a Confirmacao tem peso declaratorio maior.';

-- ============================================================================
--  SECAO 6 - PARAMETROS
-- ============================================================================
-- ---------------------------------------------------------------------------
-- dfe_manifest_max_lote = 20   (faixa 1 a 20)
-- ---------------------------------------------------------------------------
insert into poseidon.dpc_parametro (nome, valor, explicacao)
select 'dfe_manifest_max_lote', '20',
       'Modulo DFe (ApiNFE) - maximo de eventos de manifestacao por lote enviado ao '
    || 'NFeRecepcaoEvento. O teto 20 e da NT e a propria sped-nfe recusa acima disso '
    || '(RuntimeException em sefazManifestaLote). Enviar em lote em vez de unitario '
    || 'troca 20 requisicoes por 1, o que importa porque a manifestacao usa o mesmo '
    || 'certificado, CNPJ e IP da captura. Faixa aceita: 1 a 20.'
  from dual
 where not exists (select 1 from poseidon.dpc_parametro
                    where lower(nome) = 'dfe_manifest_max_lote');

-- ---------------------------------------------------------------------------
-- dfe_manifest_max_ciclo = 100   (faixa 1 a 2000)
-- ---------------------------------------------------------------------------
insert into poseidon.dpc_parametro (nome, valor, explicacao)
select 'dfe_manifest_max_ciclo', '100',
       'Modulo DFe (ApiNFE) - maximo de eventos de manifestacao por execucao do '
    || 'dfe:manifestar. Orcamento do ciclo, equivalente ao dfe_max_consultas da '
    || 'captura. Manifestacao e ato fiscal irreversivel: o teto existe para que um '
    || 'defeito na fila de candidatas nao vire mil protocolos definitivos antes de '
    || 'alguem perceber. Faixa aceita: 1 a 2000.'
  from dual
 where not exists (select 1 from poseidon.dpc_parametro
                    where lower(nome) = 'dfe_manifest_max_ciclo');

-- ---------------------------------------------------------------------------
-- dfe_manifest_pausa_seg = 5   (faixa 0 a 600)
-- ---------------------------------------------------------------------------
insert into poseidon.dpc_parametro (nome, valor, explicacao)
select 'dfe_manifest_pausa_seg', '5',
       'Modulo DFe (ApiNFE) - pausa em segundos entre lotes de manifestacao. '
    || 'Prudencia propria, nao exigencia da NT. Antes da Fase 1 o dfe:manifestar nao '
    || 'tinha pausa nenhuma e mandava os eventos em rajada. Faixa aceita: 0 a 600.'
  from dual
 where not exists (select 1 from poseidon.dpc_parametro
                    where lower(nome) = 'dfe_manifest_pausa_seg');

-- ---------------------------------------------------------------------------
-- dfe_max_bloqueios_manifest = 6   (faixa 1 a 20)
-- ---------------------------------------------------------------------------
insert into poseidon.dpc_parametro (nome, valor, explicacao)
select 'dfe_max_bloqueios_manifest', '6',
       'Modulo DFe (ApiNFE) - freio da manifestacao: acima deste numero de rejeicoes '
    || '656 atribuidas ao envio de eventos em 24h, o dfe:manifestar para. Existe '
    || 'porque NAO ha medicao confirmando que o NFeRecepcaoEvento tem cota separada '
    || 'do NFeDistribuicaoDFe - a afirmacao esta no codigo (DfeSefazRepository) sem '
    || 'nenhum experimento atras, ao contrario do resto do modulo. O teste de '
    || '21/09/2026 (10 Ciencias na empresa 29) nao produziu 656 algum, mas foram so '
    || '7 execucoes de captura depois, N baixo demais para concluir. Enquanto isso '
    || 'nao fechar, a manifestacao respeita tambem o cooldown da captura, via '
    || 'dpc_dfe_cursor.dta_liberado_em. Espelha o dfe_max_bloqueios_cnpj. '
    || 'Faixa aceita: 1 a 20.'
  from dual
 where not exists (select 1 from poseidon.dpc_parametro
                    where lower(nome) = 'dfe_max_bloqueios_manifest');

commit;

-- ============================================================================
--  SECAO 7 - CONFERENCIA
-- ============================================================================
select 'coluna' as tipo, column_name as objeto,
       data_type || '(' || data_length || ')' as detalhe,
       nullable as obs
  from all_tab_columns
 where owner = 'POSEIDON' and table_name = 'DPC_DFE_MANIFESTACAO'
   and column_name in ('NRO_SEQ_EVENTO','DSC_JUSTIFICATIVA','DTA_REGISTRO_EVENTO',
                       'COD_DFE_EMPRESA','DSC_ID_LOTE','DTA_PROXIMA_TENTATIVA')
union all
select 'coluna', column_name,
       data_type || '(' || data_length || ')', nullable
  from all_tab_columns
 where owner = 'POSEIDON' and table_name = 'DPC_DFE_EMPRESA'
   and column_name in ('STATUS_MANIF_AUTO_CIENCIA','STATUS_MANIF_AUTO_CONFIRMACAO')
union all
select 'constraint', c.constraint_name,
       listagg(cc.column_name, ',') within group (order by cc.position), c.constraint_type
  from all_constraints c
  join all_cons_columns cc on cc.owner = c.owner and cc.constraint_name = c.constraint_name
 where c.owner = 'POSEIDON'
   and c.constraint_name in ('DPC_DFE_MANIF_UK1','DPC_DFE_EMPRESA_CK3','DPC_DFE_EMPRESA_CK4')
 group by c.constraint_name, c.constraint_type
union all
select 'parametro', nome, valor, null
  from poseidon.dpc_parametro
 where lower(nome) in ('dfe_manifest_max_lote','dfe_manifest_max_ciclo',
                       'dfe_manifest_pausa_seg','dfe_max_bloqueios_manifest')
 order by 1, 2;
