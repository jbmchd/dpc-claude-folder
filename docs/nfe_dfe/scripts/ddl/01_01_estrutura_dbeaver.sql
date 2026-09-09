-- ============================================================================
--  MODULO DFe - ESTRUTURA DO MOTOR (ARQUIVO 01_01)
-- ============================================================================
--  Captura propria de documento fiscal de ENTRADA: NF-e, CT-e e NFS-e.
--  Schema POSEIDON, tablespace TSD_POSEIDON.
--
--  ==========================================================================
--   UM CAMINHO SO
--  ==========================================================================
--  Este arquivo leva a estrutura ao estado correto partindo de QUALQUER base:
--  vazia, parcial, ou ja completa. Nao existe mais "rode este se a base e
--  nova, aquele se ja tem o modulo" - a diferenca que existia entre os dois
--  caminhos era a secao 3 (COLUNAS), e ela agora esta aqui.
--
--  Rodar duas vezes seguidas produz exatamente o mesmo resultado da primeira.
--  Cada objeto e criado somente se ainda nao existir, cada coluna e conferida
--  uma a uma, e a unica coisa que reexecutar reescreve sao os comentarios e as
--  triggers - que sao identicos.
--
--  ==========================================================================
--   COMO RODAR (DBeaver)
--  ==========================================================================
--  Conectado como POSEIDON, arquivo INTEIRO com Alt+X. Sem "/" para terminar
--  bloco. E CRLF de proposito: em LF o divisor de statements do DBeaver corta
--  o bloco PL/SQL no fim do IF e devolve PLS-00103.
--
--  LIGUE O DBMS_OUTPUT (aba Output do editor de SQL). A secao 3 avisa por ali
--  o que acrescentou e o que exige decisao humana; sem o Output ligado esses
--  avisos passam invisiveis.
--
--  Se algo falhar no meio, corrija e rode o arquivo de novo - o que ja passou
--  nao e refeito nem duplicado.
--
--  ==========================================================================
--   O QUE ESTE SCRIPT NAO FAZ
--  ==========================================================================
--   - nao cadastra empresa nem cria fluxo: e o 01_02 e o 02_01 (empresa 30)
--   - nao carrega parametro: e o 01_03
--   - nao mexe em nada fora do schema POSEIDON
--   - nao le nem altera nada do ERP. O motor foi desacoplado dele; a unica
--     leitura do ERP no modulo e a conciliacao (dfe:conciliar), que nao
--     precisa de objeto novo
--   - nao altera tipo nem tamanho de coluna que ja existe (ver secao 3)
--
--  ==========================================================================
--   ORDEM DOS ARQUIVOS DESTA PASTA
--  ==========================================================================
--  O primeiro numero e o BLOCO, o segundo e a ordem dentro dele. O _99 de cada
--  bloco e o rollback DAQUELE bloco: quem desfaz mora ao lado de quem faz.
--
--   BLOCO 01 - MOTOR
--   as 13 tabelas de captura. Serve a qualquer base e nao conhece empresa
--   especifica nem usuario - o motor e CLI e banco, sem sessao e sem login.
--
--     01_01_estrutura_dbeaver.sql             <- este
--     01_02_estabelecimentos_dbeaver.sql      12 CNPJs e 48 fluxos, PAUSADOS
--     01_03_parametros_dbeaver.sql            os 5 em DPC_PARAMETRO
--     01_04_validacao_dbeaver.sql             confere o motor e as telas
--     01_99_rollback_motor_dbeaver.sql        desfaz o bloco 01
--
--   BLOCO 02 - EMPRESA 30, filial MS
--   o unico estabelecimento com arquivo proprio, porque e o unico que precisa
--   de algo FORA das tabelas do modulo: o certificado, que mora no ERP.
--
--     02_01_empresa_30_dbeaver.sql            identidade, 4 fluxos, certificado
--     02_99_rollback_empresa_30_dbeaver.sql   desfaz o bloco 02
--
--   BLOCO 03 - TELAS
--   permissao de acesso aos paineis e o limiar de alerta que eles usam para
--   pintar a linha. Nao e do motor: o motor nao sabe o que e um usuario.
--
--     03_01_parametrizacao_telas_dbeaver.sql  dpc_dfe_usuario_empresa,
--                                             dpc_dfe_usuario_aba e
--                                             dpc_dfe_painel_alerta
--     03_99_rollback_telas_dbeaver.sql        desfaz o bloco 03
--
--   INSTALAR   01_01, 01_02, 01_03, 01_04, e depois 02_01 e 03_01
--   DESFAZER   03_99, 02_99, 01_99 - do bloco mais especifico para o motor
--
--  ==========================================================================
--   O QUE HAVIA ANTES
--  ==========================================================================
--  Ate 09/09/2026 instalar era escolher entre DOIS conjuntos: scripts/01..04
--  para base nova, e scripts/alteracoes/ para base ja instalada. Errar a
--  escolha custava caro - rodar o instalador numa base parcial gerava 14
--  ORA-00904 e NAO consertava as colunas que faltavam, porque o create table e
--  pulado quando a tabela existe.
--
--  Aqueles arquivos foram REMOVIDOS. Seguem no historico do git do .claude, e o
--  que cada um fazia esta em docs/09_catalogo-scripts.md, na secao "o que foi
--  apagado, e onde recuperar".
-- ============================================================================

-- ###########################################################################
--  0. PRE-REQUISITOS
--  Para nao descobrir no meio da instalacao. Nenhuma linha abaixo altera nada.
-- ###########################################################################

--  Deve devolver: usuario POSEIDON, o tablespace existente e ONLINE, e quantos
--  objetos DPC_DFE_* ja existem. Objeto preexistente nao impede a execucao (o
--  script e convergente), mas voce quer saber ANTES se esta instalando de zero
--  ou completando.
--
--  USER_TABLESPACES, e nao ALL_TABLESPACES: essa view nao existe no Oracle - a
--  familia e USER_/DBA_ apenas. Ate 09/09/2026 estava escrito ALL_ aqui, e o
--  PRIMEIRO statement da instalacao morria com ORA-00942.
select user                                                    as conectado_como,
       (select count(*) from user_tablespaces
         where tablespace_name = 'TSD_POSEIDON')                as tablespace_existe,
       (select status from user_tablespaces
         where tablespace_name = 'TSD_POSEIDON')                as tablespace_status,
       (select count(*) from all_tables
         where owner = 'POSEIDON' and table_name like 'DPC_DFE%')  as tabelas_ja_existentes,
       (select count(*) from all_sequences
         where sequence_owner = 'POSEIDON' and sequence_name like 'DPCS_DFE%') as sequences_ja_existentes
  from dual;

-- ###########################################################################
--  1. SEQUENCES
--  Uma por tabela. A PK NUNCA e informada pela aplicacao: quem preenche e a
--  trigger da secao 6, lendo daqui. Padrao do ecossistema DPC.
--
--  cache 20 em todas. Em homologacao as quatro mais novas (cursor, cte,
--  cte_nfe, nfse) ficaram nocache por acidente de copia; aqui esta
--  uniformizado. A validacao vai apontar essa diferenca entre os ambientes -
--  e apontar de proposito, nao por defeito.
-- ###########################################################################
declare
  qtd number;
begin
  select count(*) into qtd from all_sequences
   where sequence_owner = 'POSEIDON' and sequence_name = 'DPCS_DFE_EMPRESA';

  if qtd = 0 then
    execute immediate q'[create sequence poseidon.dpcs_dfe_empresa minvalue 1 start with 1 increment by 1 cache 20]';
  end if;
end;

declare
  qtd number;
begin
  select count(*) into qtd from all_sequences
   where sequence_owner = 'POSEIDON' and sequence_name = 'DPCS_DFE_CURSOR';

  if qtd = 0 then
    execute immediate q'[create sequence poseidon.dpcs_dfe_cursor minvalue 1 start with 1 increment by 1 cache 20]';
  end if;
end;

declare
  qtd number;
begin
  select count(*) into qtd from all_sequences
   where sequence_owner = 'POSEIDON' and sequence_name = 'DPCS_DFE_EMITENTE';

  if qtd = 0 then
    execute immediate q'[create sequence poseidon.dpcs_dfe_emitente minvalue 1 start with 1 increment by 1 cache 20]';
  end if;
end;

declare
  qtd number;
begin
  select count(*) into qtd from all_sequences
   where sequence_owner = 'POSEIDON' and sequence_name = 'DPCS_DFE_DOCUMENTO';

  if qtd = 0 then
    execute immediate q'[create sequence poseidon.dpcs_dfe_documento minvalue 1 start with 1 increment by 1 cache 20]';
  end if;
end;

declare
  qtd number;
begin
  select count(*) into qtd from all_sequences
   where sequence_owner = 'POSEIDON' and sequence_name = 'DPCS_DFE_NOTA';

  if qtd = 0 then
    execute immediate q'[create sequence poseidon.dpcs_dfe_nota minvalue 1 start with 1 increment by 1 cache 20]';
  end if;
end;

declare
  qtd number;
begin
  select count(*) into qtd from all_sequences
   where sequence_owner = 'POSEIDON' and sequence_name = 'DPCS_DFE_NOTA_ITEM';

  if qtd = 0 then
    execute immediate q'[create sequence poseidon.dpcs_dfe_nota_item minvalue 1 start with 1 increment by 1 cache 20]';
  end if;
end;

declare
  qtd number;
begin
  select count(*) into qtd from all_sequences
   where sequence_owner = 'POSEIDON' and sequence_name = 'DPCS_DFE_EVENTO';

  if qtd = 0 then
    execute immediate q'[create sequence poseidon.dpcs_dfe_evento minvalue 1 start with 1 increment by 1 cache 20]';
  end if;
end;

declare
  qtd number;
begin
  select count(*) into qtd from all_sequences
   where sequence_owner = 'POSEIDON' and sequence_name = 'DPCS_DFE_EXECUCAO';

  if qtd = 0 then
    execute immediate q'[create sequence poseidon.dpcs_dfe_execucao minvalue 1 start with 1 increment by 1 cache 20]';
  end if;
end;

declare
  qtd number;
begin
  select count(*) into qtd from all_sequences
   where sequence_owner = 'POSEIDON' and sequence_name = 'DPCS_DFE_MANIFESTACAO';

  if qtd = 0 then
    execute immediate q'[create sequence poseidon.dpcs_dfe_manifestacao minvalue 1 start with 1 increment by 1 cache 20]';
  end if;
end;

declare
  qtd number;
begin
  select count(*) into qtd from all_sequences
   where sequence_owner = 'POSEIDON' and sequence_name = 'DPCS_DFE_CTE';

  if qtd = 0 then
    execute immediate q'[create sequence poseidon.dpcs_dfe_cte minvalue 1 start with 1 increment by 1 cache 20]';
  end if;
end;

declare
  qtd number;
begin
  select count(*) into qtd from all_sequences
   where sequence_owner = 'POSEIDON' and sequence_name = 'DPCS_DFE_CTE_NFE';

  if qtd = 0 then
    execute immediate q'[create sequence poseidon.dpcs_dfe_cte_nfe minvalue 1 start with 1 increment by 1 cache 20]';
  end if;
end;

declare
  qtd number;
begin
  select count(*) into qtd from all_sequences
   where sequence_owner = 'POSEIDON' and sequence_name = 'DPCS_DFE_CTE_EVENTO';

  if qtd = 0 then
    execute immediate q'[create sequence poseidon.dpcs_dfe_cte_evento minvalue 1 start with 1 increment by 1 cache 20]';
  end if;
end;

declare
  qtd number;
begin
  select count(*) into qtd from all_sequences
   where sequence_owner = 'POSEIDON' and sequence_name = 'DPCS_DFE_NFSE';

  if qtd = 0 then
    execute immediate q'[create sequence poseidon.dpcs_dfe_nfse minvalue 1 start with 1 increment by 1 cache 20]';
  end if;
end;


-- ###########################################################################
--  2. TABELAS
--  Ordem de dependencia: a tabela referenciada por FK vem antes.
--  As constraints ficam na secao 4, para que uma falha de FK nao interrompa a
--  criacao das tabelas.
-- ###########################################################################
-- ---------- DPC_DFE_EMPRESA ----------
declare
  qtd number;
begin
  select count(*) into qtd from all_tables
   where owner = 'POSEIDON' and table_name = 'DPC_DFE_EMPRESA';

  if qtd = 0 then
    execute immediate q'[create table poseidon.dpc_dfe_empresa
    (
      cod_dfe_empresa     NUMBER not null,
      nro_empresa         NUMBER not null,
      num_cnpj            VARCHAR2(14) not null,
      status_manifestar   VARCHAR2(1) default 'N' not null,
      dsc_razao_social    VARCHAR2(120) not null,
      sig_uf              VARCHAR2(2) not null,
      num_inscr_estadual  VARCHAR2(20),
      created_at          DATE default sysdate,
      created_by          VARCHAR2(50),
      updated_at          DATE,
      updated_by          VARCHAR2(50)
    )
    tablespace TSD_POSEIDON
    ]';
  end if;
end;

-- ---------- DPC_DFE_CURSOR ----------
declare
  qtd number;
begin
  select count(*) into qtd from all_tables
   where owner = 'POSEIDON' and table_name = 'DPC_DFE_CURSOR';

  if qtd = 0 then
    execute immediate q'[create table poseidon.dpc_dfe_cursor
    (
      cod_dfe_cursor          NUMBER not null,
      cod_dfe_empresa         NUMBER not null,
      cod_tipo_dfe            VARCHAR2(4) not null,
      status_sincronismo      VARCHAR2(1) default 'A' not null,
      nro_ultimo_nsu          NUMBER default 0 not null,
      nro_maximo_nsu          NUMBER default 0 not null,
      qtd_min_entre_consulta  NUMBER default 3 not null,
      qtd_min_em_dia          NUMBER default 60 not null,
      dta_ultima_consulta     TIMESTAMP(6),
      dta_liberado_em         TIMESTAMP(6),
      cod_ultimo_status       VARCHAR2(5),
      dsc_ultimo_motivo       VARCHAR2(255),
      created_at              DATE default sysdate,
      created_by              VARCHAR2(50),
      updated_at              DATE,
      updated_by              VARCHAR2(50)
    )
    tablespace TSD_POSEIDON
    ]';
  end if;
end;

-- ---------- DPC_DFE_EMITENTE ----------
declare
  qtd number;
begin
  select count(*) into qtd from all_tables
   where owner = 'POSEIDON' and table_name = 'DPC_DFE_EMITENTE';

  if qtd = 0 then
    execute immediate q'[create table poseidon.dpc_dfe_emitente
    (
      cod_dfe_emitente    NUMBER not null,
      num_cnpj_cpf        VARCHAR2(14) not null,
      dsc_razao_social    VARCHAR2(120),
      num_inscr_estadual  VARCHAR2(20),
      created_at          DATE default sysdate,
      created_by          VARCHAR2(50),
      updated_at          DATE,
      updated_by          VARCHAR2(50)
    )
    tablespace TSD_POSEIDON
    ]';
  end if;
end;

-- ---------- DPC_DFE_DOCUMENTO ----------
declare
  qtd number;
begin
  select count(*) into qtd from all_tables
   where owner = 'POSEIDON' and table_name = 'DPC_DFE_DOCUMENTO';

  if qtd = 0 then
    execute immediate q'[create table poseidon.dpc_dfe_documento
    (
      cod_dfe_documento  NUMBER not null,
      cod_dfe_cursor     NUMBER not null,
      cod_dfe_empresa    NUMBER not null,
      nro_nsu            NUMBER not null,
      dsc_schema         VARCHAR2(60),
      dsc_tipo_doc       VARCHAR2(10),
      chave_nf           VARCHAR2(50),
      bin_documento      BLOB,
      status_process     VARCHAR2(1) default 'P' not null,
      qtd_tentativa      NUMBER default 0 not null,
      det_erro           VARCHAR2(4000),
      dta_recebimento    TIMESTAMP(6) default systimestamp not null,
      dta_processado     TIMESTAMP(6)
    )
    tablespace TSD_POSEIDON
    ]';
  end if;
end;

-- ---------- DPC_DFE_NOTA ----------
declare
  qtd number;
begin
  select count(*) into qtd from all_tables
   where owner = 'POSEIDON' and table_name = 'DPC_DFE_NOTA';

  if qtd = 0 then
    execute immediate q'[create table poseidon.dpc_dfe_nota
    (
      cod_dfe_nota         NUMBER not null,
      cod_dfe_empresa      NUMBER not null,
      cod_dfe_emitente     NUMBER,
      chave_nf             VARCHAR2(44) not null,
      nro_nsu              NUMBER,
      dsc_tipo_doc         VARCHAR2(10),
      nro_modelo           NUMBER,
      nro_serie            NUMBER,
      nro_nf               NUMBER,
      tipo_nf              NUMBER,
      vlr_nota             NUMBER,
      vlr_total_produto    NUMBER,
      dta_emissao          DATE,
      dta_recibo           DATE,
      nro_protocolo        VARCHAR2(20),
      cod_situacao         NUMBER,
      dsc_situacao         VARCHAR2(20),
      status_manifestacao  VARCHAR2(1) default 'N' not null,
      sig_papel_empresa    VARCHAR2(6),
      status_recebimento   VARCHAR2(1) default 'N' not null,
      seq_nf_erp           NUMBER,
      dta_entrada_erp      DATE,
      dta_conciliacao      TIMESTAMP(6),
      sig_estado_erp       VARCHAR2(20),
      num_estado_erp       NUMBER(1),
      num_estado_erp_max   NUMBER(1),
      dta_estado_erp       TIMESTAMP(6),
      seq_notamestre_erp   NUMBER,
      dta_lancamento_erp   DATE,
      cod_cfop_erp         NUMBER(5),
      dsc_ocorr_dev_erp    VARCHAR2(5),
      seq_comprador_erp    NUMBER,
      dsc_comprador_erp    VARCHAR2(40),
      created_at           DATE default sysdate,
      created_by           VARCHAR2(50),
      updated_at           DATE,
      updated_by           VARCHAR2(50)
    )
    tablespace TSD_POSEIDON
    ]';
  end if;
end;

-- ---------- DPC_DFE_NOTA_ITEM ----------
declare
  qtd number;
begin
  select count(*) into qtd from all_tables
   where owner = 'POSEIDON' and table_name = 'DPC_DFE_NOTA_ITEM';

  if qtd = 0 then
    execute immediate q'[create table poseidon.dpc_dfe_nota_item
    (
      cod_dfe_nota_item    NUMBER not null,
      cod_dfe_nota         NUMBER not null,
      nro_item             NUMBER not null,
      cod_produto          VARCHAR2(60),
      cod_ean              VARCHAR2(20),
      dsc_produto          VARCHAR2(120),
      cod_ncm              VARCHAR2(8),
      cod_cest             VARCHAR2(7),
      cod_ex_tipi          VARCHAR2(3),
      cod_cfop             VARCHAR2(4),
      cod_beneficio        VARCHAR2(10),
      sig_unid_com         VARCHAR2(6),
      qtd_comercial        NUMBER,
      vlr_unit_com         NUMBER,
      vlr_produto          NUMBER,
      sig_unid_trib        VARCHAR2(6),
      qtd_tributavel       NUMBER,
      vlr_unit_trib        NUMBER,
      vlr_frete            NUMBER,
      vlr_seguro           NUMBER,
      vlr_desconto         NUMBER,
      vlr_outros           NUMBER,
      status_compoe_total  VARCHAR2(1),
      vlr_item             NUMBER,
      dsc_inf_adic         VARCHAR2(500),
      cod_cst_icms         VARCHAR2(4),
      cod_origem           VARCHAR2(1),
      vlr_bc_icms          NUMBER,
      pct_icms             NUMBER,
      vlr_icms             NUMBER,
      vlr_bc_icms_st       NUMBER,
      vlr_icms_st          NUMBER,
      cod_cst_ipi          VARCHAR2(2),
      vlr_bc_ipi           NUMBER,
      pct_ipi              NUMBER,
      vlr_ipi              NUMBER,
      cod_cst_pis          VARCHAR2(2),
      vlr_bc_pis           NUMBER,
      pct_pis              NUMBER,
      vlr_pis              NUMBER,
      cod_cst_cofins       VARCHAR2(2),
      vlr_bc_cofins        NUMBER,
      pct_cofins           NUMBER,
      vlr_cofins           NUMBER,
      cod_cst_ibscbs       VARCHAR2(3),
      cod_class_trib       VARCHAR2(6),
      vlr_bc_ibscbs        NUMBER,
      vlr_ibs              NUMBER,
      vlr_cbs              NUMBER,
      created_at           DATE default sysdate,
      created_by           VARCHAR2(50)
    )
    tablespace TSD_POSEIDON
    ]';
  end if;
end;

-- ---------- DPC_DFE_EVENTO ----------
declare
  qtd number;
begin
  select count(*) into qtd from all_tables
   where owner = 'POSEIDON' and table_name = 'DPC_DFE_EVENTO';

  if qtd = 0 then
    execute immediate q'[create table poseidon.dpc_dfe_evento
    (
      cod_dfe_evento   NUMBER not null,
      cod_dfe_empresa  NUMBER not null,
      cod_dfe_nota     NUMBER,
      chave_nf         VARCHAR2(44) not null,
      nro_nsu          NUMBER,
      cod_tipo_evento  VARCHAR2(6),
      dsc_evento       VARCHAR2(255),
      nro_seq_evento   NUMBER default 1 not null,
      nro_protocolo    VARCHAR2(20),
      cod_status       VARCHAR2(5),
      dsc_motivo       VARCHAR2(255),
      dta_evento       TIMESTAMP(6),
      created_at       DATE default sysdate,
      created_by       VARCHAR2(50)
    )
    tablespace TSD_POSEIDON
    ]';
  end if;
end;

-- ---------- DPC_DFE_EXECUCAO ----------
declare
  qtd number;
begin
  select count(*) into qtd from all_tables
   where owner = 'POSEIDON' and table_name = 'DPC_DFE_EXECUCAO';

  if qtd = 0 then
    execute immediate q'[create table poseidon.dpc_dfe_execucao
    (
      cod_dfe_execucao  NUMBER not null,
      cod_dfe_cursor    NUMBER not null,
      cod_dfe_empresa   NUMBER not null,
      dta_inicio        TIMESTAMP(6) default systimestamp not null,
      dta_fim           TIMESTAMP(6),
      nro_nsu_inicial   NUMBER,
      nro_nsu_final     NUMBER,
      qtd_consulta      NUMBER default 0 not null,
      qtd_documento     NUMBER default 0 not null,
      qtd_nota          NUMBER default 0 not null,
      qtd_evento        NUMBER default 0 not null,
      qtd_erro          NUMBER default 0 not null,
      cod_resultado     VARCHAR2(20),
      dsc_resultado     VARCHAR2(4000),
      created_by        VARCHAR2(50)
    )
    tablespace TSD_POSEIDON
    ]';
  end if;
end;

-- ---------- DPC_DFE_MANIFESTACAO ----------
declare
  qtd number;
begin
  select count(*) into qtd from all_tables
   where owner = 'POSEIDON' and table_name = 'DPC_DFE_MANIFESTACAO';

  if qtd = 0 then
    execute immediate q'[create table poseidon.dpc_dfe_manifestacao
    (
      cod_dfe_manifestacao  NUMBER not null,
      cod_dfe_nota          NUMBER not null,
      cod_tipo_evento       VARCHAR2(6) not null,
      status_envio          VARCHAR2(1) default 'P' not null,
      cod_status_retorno    VARCHAR2(5),
      dsc_status_retorno    VARCHAR2(255),
      nro_protocolo         VARCHAR2(20),
      qtd_tentativa         NUMBER default 0 not null,
      det_erro              VARCHAR2(4000),
      xml_retorno           CLOB,
      dta_envio             TIMESTAMP(6),
      dta_ultima_tentativa  TIMESTAMP(6),
      dta_atualizacao       TIMESTAMP(6),
      created_at            DATE default sysdate,
      created_by            VARCHAR2(50)
    )
    tablespace TSD_POSEIDON
    ]';
  end if;
end;

-- ---------- DPC_DFE_CTE ----------
declare
  qtd number;
begin
  select count(*) into qtd from all_tables
   where owner = 'POSEIDON' and table_name = 'DPC_DFE_CTE';

  if qtd = 0 then
    execute immediate q'[create table poseidon.dpc_dfe_cte
    (
      cod_dfe_cte         NUMBER not null,
      cod_dfe_empresa     NUMBER not null,
      chave_cte           VARCHAR2(44) not null,
      nro_nsu             NUMBER,
      dsc_tipo_doc        VARCHAR2(10),
      nro_modelo          NUMBER,
      nro_serie           NUMBER,
      nro_cte             NUMBER,
      dta_emissao         DATE,
      cod_cfop            VARCHAR2(4),
      dsc_natureza_oper   VARCHAR2(60),
      cod_modal           VARCHAR2(2),
      cod_tipo_servico    VARCHAR2(1),
      cod_tipo_cte        VARCHAR2(1),
      dsc_municipio_ini   VARCHAR2(60),
      sig_uf_ini          VARCHAR2(2),
      dsc_municipio_fim   VARCHAR2(60),
      sig_uf_fim          VARCHAR2(2),
      num_cnpj_emitente   VARCHAR2(14),
      dsc_razao_emitente  VARCHAR2(120),
      num_cnpj_remetente  VARCHAR2(14),
      num_cnpj_expedidor  VARCHAR2(14),
      num_cnpj_recebedor  VARCHAR2(14),
      num_cnpj_destinat   VARCHAR2(14),
      cod_tomador         VARCHAR2(1),
      sig_papel_empresa   VARCHAR2(6),
      vlr_prestacao       NUMBER,
      vlr_receber         NUMBER,
      nro_protocolo       VARCHAR2(20),
      cod_situacao        NUMBER,
      dsc_situacao        VARCHAR2(20),
      created_at          DATE default sysdate,
      created_by          VARCHAR2(50),
      updated_at          DATE,
      updated_by          VARCHAR2(50)
    )
    tablespace TSD_POSEIDON
    ]';
  end if;
end;

-- ---------- DPC_DFE_CTE_NFE ----------
declare
  qtd number;
begin
  select count(*) into qtd from all_tables
   where owner = 'POSEIDON' and table_name = 'DPC_DFE_CTE_NFE';

  if qtd = 0 then
    execute immediate q'[create table poseidon.dpc_dfe_cte_nfe
    (
      cod_dfe_cte_nfe  NUMBER not null,
      cod_dfe_cte      NUMBER not null,
      chave_nf         VARCHAR2(44) not null,
      created_at       DATE default sysdate,
      created_by       VARCHAR2(50)
    )
    tablespace TSD_POSEIDON
    ]';
  end if;
end;

-- ---------- DPC_DFE_CTE_EVENTO ----------
declare
  qtd number;
begin
  select count(*) into qtd from all_tables
   where owner = 'POSEIDON' and table_name = 'DPC_DFE_CTE_EVENTO';

  if qtd = 0 then
    execute immediate q'[create table poseidon.dpc_dfe_cte_evento
    (
      cod_dfe_cte_evento  NUMBER not null,
      cod_dfe_empresa     NUMBER not null,
      cod_dfe_cte         NUMBER,
      chave_cte           VARCHAR2(44) not null,
      nro_nsu             NUMBER,
      cod_tipo_evento     VARCHAR2(6),
      dsc_evento          VARCHAR2(255),
      nro_seq_evento      NUMBER default 1 not null,
      nro_protocolo       VARCHAR2(20),
      cod_status          VARCHAR2(5),
      dsc_motivo          VARCHAR2(255),
      dta_evento          TIMESTAMP(6),
      num_cnpj_autor      VARCHAR2(14),
      dta_entrega         TIMESTAMP(6),
      num_doc_recebedor   VARCHAR2(60),
      dsc_nome_recebedor  VARCHAR2(60),
      dsc_hash_entrega    VARCHAR2(60),
      chave_mdfe          VARCHAR2(44),
      created_at          DATE default sysdate,
      created_by          VARCHAR2(50)
    )
    tablespace TSD_POSEIDON
    ]';
  end if;
end;

-- ---------- DPC_DFE_NFSE ----------
declare
  qtd number;
begin
  select count(*) into qtd from all_tables
   where owner = 'POSEIDON' and table_name = 'DPC_DFE_NFSE';

  if qtd = 0 then
    execute immediate q'[create table poseidon.dpc_dfe_nfse
    (
      cod_dfe_nfse          NUMBER not null,
      cod_dfe_empresa       NUMBER not null,
      chave_nfse            VARCHAR2(50) not null,
      nro_nsu               NUMBER,
      dsc_tipo_doc          VARCHAR2(10),
      nro_nfse              VARCHAR2(15),
      dta_processamento     DATE,
      dta_competencia       DATE,
      cod_situacao          NUMBER,
      dsc_situacao          VARCHAR2(20),
      sig_papel_empresa     VARCHAR2(6),
      num_cnpj_cpf_prest    VARCHAR2(14),
      dsc_razao_prest       VARCHAR2(120),
      num_insc_munic_prest  VARCHAR2(20),
      cod_municipio_prest   VARCHAR2(7),
      sig_uf_prest          VARCHAR2(2),
      num_cnpj_cpf_toma     VARCHAR2(14),
      dsc_razao_toma        VARCHAR2(120),
      cod_municipio_incid   VARCHAR2(7),
      dsc_municipio_incid   VARCHAR2(60),
      cod_trib_nacional     VARCHAR2(10),
      cod_trib_municipal    VARCHAR2(20),
      dsc_servico           VARCHAR2(2000),
      vlr_servico           NUMBER,
      vlr_base_calculo      NUMBER,
      pct_aliquota          NUMBER,
      vlr_issqn             NUMBER,
      vlr_retido            NUMBER,
      vlr_liquido           NUMBER,
      created_at            DATE default sysdate,
      created_by            VARCHAR2(50),
      updated_at            DATE,
      updated_by            VARCHAR2(50)
    )
    tablespace TSD_POSEIDON
    ]';
  end if;
end;


-- ###########################################################################
--  3. COLUNAS
--  E esta secao que faz o arquivo servir a QUALQUER base, e por isso nao
--  existe mais um script de "alteracao" separado.
--
--  O create table da secao 2 e PULADO quando a tabela existe. Logo, numa base
--  instalada por uma versao ANTERIOR deste arquivo, as tabelas estao no lugar
--  e as colunas novas nao. Foi exatamente o que aconteceu em 09/09/2026: a
--  base de teste voltou a um snapshot de 13 dias antes, com as 13 tabelas
--  presentes e 11 colunas de DPC_DFE_NOTA ausentes - e recuperar exigiu
--  escolher a dedo tres scripts de alteracao, na ordem certa.
--
--  Aqui a lista de colunas de cada tabela e conferida uma a uma, e a que
--  faltar e acrescentada. Numa base recem-criada pela secao 2 todas existem, e
--  a secao inteira e no-op.
--
--  MANUTENCAO: coluna nova do modulo entra em DOIS lugares deste arquivo - no
--  create table da secao 2 e na lista da secao 3. Sao a mesma lista, e a
--  secao 1 do 01_04_validacao_dbeaver.sql compara as duas contra o banco.
--
--  ==========================================================================
--   POR QUE CADA COLUNA TEM EXCEPTION PROPRIA
--  ==========================================================================
--  Das 273 colunas do modulo, 41 sao NOT NULL sem DEFAULT - as PKs e as FKs.
--  Acrescentar uma dessas a uma tabela QUE JA TEM LINHAS falha com ORA-01758,
--  e falhar e o comportamento correto: nao existe valor para as linhas antigas.
--
--  Sem o handler, uma dessas abortaria o arquivo inteiro e as secoes seguintes
--  nao rodariam. Com ele o script termina, o DBMS_OUTPUT diz exatamente qual
--  coluna exige decisao humana, e a validacao acusa a coluna ausente.
--
--  As outras 232 - 211 anulaveis e 21 com DEFAULT - entram sempre. Toda coluna
--  que o modulo ganhou depois da instalacao original e anulavel: as 11 da
--  etapa no ERP e a VLR_TOTAL_PRODUTO.
--
--  ==========================================================================
--   O QUE ESTA SECAO NAO FAZ
--  ==========================================================================
--  Nao altera tipo nem tamanho de coluna existente. ALTER MODIFY pode falhar
--  por causa do dado gravado e nao cabe em script automatico. Divergencia de
--  tipo e REPORTADA pela secao 4 do 01_04_validacao_dbeaver.sql, que guarda os
--  casos que ja custaram diagnostico - CHAVE_NF com 44 onde a NFS-e precisa de
--  50, por exemplo.
-- ###########################################################################

-- ---------- DPC_DFE_EMPRESA ----------
declare
  qtd number;
begin
  for c in (
    select 'cod_dfe_empresa'    as nome, 'NUMBER not null'                    as def from dual union all
    select 'nro_empresa'               , 'NUMBER not null'                           from dual union all
    select 'num_cnpj'                  , 'VARCHAR2(14) not null'                     from dual union all
    select 'status_manifestar'         , 'VARCHAR2(1) default ''N'' not null'        from dual union all
    select 'dsc_razao_social'          , 'VARCHAR2(120) not null'                    from dual union all
    select 'sig_uf'                    , 'VARCHAR2(2) not null'                      from dual union all
    select 'num_inscr_estadual'        , 'VARCHAR2(20)'                              from dual union all
    select 'created_at'                , 'DATE default sysdate'                      from dual union all
    select 'created_by'                , 'VARCHAR2(50)'                              from dual union all
    select 'updated_at'                , 'DATE'                                      from dual union all
    select 'updated_by'                , 'VARCHAR2(50)'                              from dual
  ) loop
    begin
      select count(*) into qtd from all_tab_columns
       where owner = 'POSEIDON' and table_name = 'DPC_DFE_EMPRESA'
         and column_name = upper(c.nome);

      if qtd = 0 then
        execute immediate 'alter table poseidon.dpc_dfe_empresa add ('
                          || c.nome || ' ' || c.def || ')';
        dbms_output.put_line('DPC_DFE_EMPRESA: acrescentada -> ' || c.nome);
      end if;
    exception
      when others then
        dbms_output.put_line('DPC_DFE_EMPRESA: FALHOU em ' || c.nome || ' -> ' || sqlerrm);
    end;
  end loop;
end;

-- ---------- DPC_DFE_CURSOR ----------
declare
  qtd number;
begin
  for c in (
    select 'cod_dfe_cursor'         as nome, 'NUMBER not null'                    as def from dual union all
    select 'cod_dfe_empresa'               , 'NUMBER not null'                           from dual union all
    select 'cod_tipo_dfe'                  , 'VARCHAR2(4) not null'                      from dual union all
    select 'status_sincronismo'            , 'VARCHAR2(1) default ''A'' not null'        from dual union all
    select 'nro_ultimo_nsu'                , 'NUMBER default 0 not null'                 from dual union all
    select 'nro_maximo_nsu'                , 'NUMBER default 0 not null'                 from dual union all
    select 'qtd_min_entre_consulta'        , 'NUMBER default 3 not null'                 from dual union all
    select 'qtd_min_em_dia'                , 'NUMBER default 60 not null'                from dual union all
    select 'dta_ultima_consulta'           , 'TIMESTAMP(6)'                              from dual union all
    select 'dta_liberado_em'               , 'TIMESTAMP(6)'                              from dual union all
    select 'cod_ultimo_status'             , 'VARCHAR2(5)'                               from dual union all
    select 'dsc_ultimo_motivo'             , 'VARCHAR2(255)'                             from dual union all
    select 'created_at'                    , 'DATE default sysdate'                      from dual union all
    select 'created_by'                    , 'VARCHAR2(50)'                              from dual union all
    select 'updated_at'                    , 'DATE'                                      from dual union all
    select 'updated_by'                    , 'VARCHAR2(50)'                              from dual
  ) loop
    begin
      select count(*) into qtd from all_tab_columns
       where owner = 'POSEIDON' and table_name = 'DPC_DFE_CURSOR'
         and column_name = upper(c.nome);

      if qtd = 0 then
        execute immediate 'alter table poseidon.dpc_dfe_cursor add ('
                          || c.nome || ' ' || c.def || ')';
        dbms_output.put_line('DPC_DFE_CURSOR: acrescentada -> ' || c.nome);
      end if;
    exception
      when others then
        dbms_output.put_line('DPC_DFE_CURSOR: FALHOU em ' || c.nome || ' -> ' || sqlerrm);
    end;
  end loop;
end;

-- ---------- DPC_DFE_EMITENTE ----------
declare
  qtd number;
begin
  for c in (
    select 'cod_dfe_emitente'   as nome, 'NUMBER not null'       as def from dual union all
    select 'num_cnpj_cpf'              , 'VARCHAR2(14) not null'        from dual union all
    select 'dsc_razao_social'          , 'VARCHAR2(120)'                from dual union all
    select 'num_inscr_estadual'        , 'VARCHAR2(20)'                 from dual union all
    select 'created_at'                , 'DATE default sysdate'         from dual union all
    select 'created_by'                , 'VARCHAR2(50)'                 from dual union all
    select 'updated_at'                , 'DATE'                         from dual union all
    select 'updated_by'                , 'VARCHAR2(50)'                 from dual
  ) loop
    begin
      select count(*) into qtd from all_tab_columns
       where owner = 'POSEIDON' and table_name = 'DPC_DFE_EMITENTE'
         and column_name = upper(c.nome);

      if qtd = 0 then
        execute immediate 'alter table poseidon.dpc_dfe_emitente add ('
                          || c.nome || ' ' || c.def || ')';
        dbms_output.put_line('DPC_DFE_EMITENTE: acrescentada -> ' || c.nome);
      end if;
    exception
      when others then
        dbms_output.put_line('DPC_DFE_EMITENTE: FALHOU em ' || c.nome || ' -> ' || sqlerrm);
    end;
  end loop;
end;

-- ---------- DPC_DFE_DOCUMENTO ----------
declare
  qtd number;
begin
  for c in (
    select 'cod_dfe_documento' as nome, 'NUMBER not null'                            as def from dual union all
    select 'cod_dfe_cursor'           , 'NUMBER not null'                                   from dual union all
    select 'cod_dfe_empresa'          , 'NUMBER not null'                                   from dual union all
    select 'nro_nsu'                  , 'NUMBER not null'                                   from dual union all
    select 'dsc_schema'               , 'VARCHAR2(60)'                                      from dual union all
    select 'dsc_tipo_doc'             , 'VARCHAR2(10)'                                      from dual union all
    select 'chave_nf'                 , 'VARCHAR2(50)'                                      from dual union all
    select 'bin_documento'            , 'BLOB'                                              from dual union all
    select 'status_process'           , 'VARCHAR2(1) default ''P'' not null'                from dual union all
    select 'qtd_tentativa'            , 'NUMBER default 0 not null'                         from dual union all
    select 'det_erro'                 , 'VARCHAR2(4000)'                                    from dual union all
    select 'dta_recebimento'          , 'TIMESTAMP(6) default systimestamp not null'        from dual union all
    select 'dta_processado'           , 'TIMESTAMP(6)'                                      from dual
  ) loop
    begin
      select count(*) into qtd from all_tab_columns
       where owner = 'POSEIDON' and table_name = 'DPC_DFE_DOCUMENTO'
         and column_name = upper(c.nome);

      if qtd = 0 then
        execute immediate 'alter table poseidon.dpc_dfe_documento add ('
                          || c.nome || ' ' || c.def || ')';
        dbms_output.put_line('DPC_DFE_DOCUMENTO: acrescentada -> ' || c.nome);
      end if;
    exception
      when others then
        dbms_output.put_line('DPC_DFE_DOCUMENTO: FALHOU em ' || c.nome || ' -> ' || sqlerrm);
    end;
  end loop;
end;

-- ---------- DPC_DFE_NOTA ----------
declare
  qtd number;
begin
  for c in (
    select 'cod_dfe_nota'        as nome, 'NUMBER not null'                    as def from dual union all
    select 'cod_dfe_empresa'            , 'NUMBER not null'                           from dual union all
    select 'cod_dfe_emitente'           , 'NUMBER'                                    from dual union all
    select 'chave_nf'                   , 'VARCHAR2(44) not null'                     from dual union all
    select 'nro_nsu'                    , 'NUMBER'                                    from dual union all
    select 'dsc_tipo_doc'               , 'VARCHAR2(10)'                              from dual union all
    select 'nro_modelo'                 , 'NUMBER'                                    from dual union all
    select 'nro_serie'                  , 'NUMBER'                                    from dual union all
    select 'nro_nf'                     , 'NUMBER'                                    from dual union all
    select 'tipo_nf'                    , 'NUMBER'                                    from dual union all
    select 'vlr_nota'                   , 'NUMBER'                                    from dual union all
    select 'vlr_total_produto'          , 'NUMBER'                                    from dual union all
    select 'dta_emissao'                , 'DATE'                                      from dual union all
    select 'dta_recibo'                 , 'DATE'                                      from dual union all
    select 'nro_protocolo'              , 'VARCHAR2(20)'                              from dual union all
    select 'cod_situacao'               , 'NUMBER'                                    from dual union all
    select 'dsc_situacao'               , 'VARCHAR2(20)'                              from dual union all
    select 'status_manifestacao'        , 'VARCHAR2(1) default ''N'' not null'        from dual union all
    select 'sig_papel_empresa'          , 'VARCHAR2(6)'                               from dual union all
    select 'status_recebimento'         , 'VARCHAR2(1) default ''N'' not null'        from dual union all
    select 'seq_nf_erp'                 , 'NUMBER'                                    from dual union all
    select 'dta_entrada_erp'            , 'DATE'                                      from dual union all
    select 'dta_conciliacao'            , 'TIMESTAMP(6)'                              from dual union all
    select 'sig_estado_erp'             , 'VARCHAR2(20)'                              from dual union all
    select 'num_estado_erp'             , 'NUMBER(1)'                                 from dual union all
    select 'num_estado_erp_max'         , 'NUMBER(1)'                                 from dual union all
    select 'dta_estado_erp'             , 'TIMESTAMP(6)'                              from dual union all
    select 'seq_notamestre_erp'         , 'NUMBER'                                    from dual union all
    select 'dta_lancamento_erp'         , 'DATE'                                      from dual union all
    select 'cod_cfop_erp'               , 'NUMBER(5)'                                 from dual union all
    select 'dsc_ocorr_dev_erp'          , 'VARCHAR2(5)'                               from dual union all
    select 'seq_comprador_erp'          , 'NUMBER'                                    from dual union all
    select 'dsc_comprador_erp'          , 'VARCHAR2(40)'                              from dual union all
    select 'created_at'                 , 'DATE default sysdate'                      from dual union all
    select 'created_by'                 , 'VARCHAR2(50)'                              from dual union all
    select 'updated_at'                 , 'DATE'                                      from dual union all
    select 'updated_by'                 , 'VARCHAR2(50)'                              from dual
  ) loop
    begin
      select count(*) into qtd from all_tab_columns
       where owner = 'POSEIDON' and table_name = 'DPC_DFE_NOTA'
         and column_name = upper(c.nome);

      if qtd = 0 then
        execute immediate 'alter table poseidon.dpc_dfe_nota add ('
                          || c.nome || ' ' || c.def || ')';
        dbms_output.put_line('DPC_DFE_NOTA: acrescentada -> ' || c.nome);
      end if;
    exception
      when others then
        dbms_output.put_line('DPC_DFE_NOTA: FALHOU em ' || c.nome || ' -> ' || sqlerrm);
    end;
  end loop;
end;

-- ---------- DPC_DFE_NOTA_ITEM ----------
declare
  qtd number;
begin
  for c in (
    select 'cod_dfe_nota_item'   as nome, 'NUMBER not null'      as def from dual union all
    select 'cod_dfe_nota'               , 'NUMBER not null'             from dual union all
    select 'nro_item'                   , 'NUMBER not null'             from dual union all
    select 'cod_produto'                , 'VARCHAR2(60)'                from dual union all
    select 'cod_ean'                    , 'VARCHAR2(20)'                from dual union all
    select 'dsc_produto'                , 'VARCHAR2(120)'               from dual union all
    select 'cod_ncm'                    , 'VARCHAR2(8)'                 from dual union all
    select 'cod_cest'                   , 'VARCHAR2(7)'                 from dual union all
    select 'cod_ex_tipi'                , 'VARCHAR2(3)'                 from dual union all
    select 'cod_cfop'                   , 'VARCHAR2(4)'                 from dual union all
    select 'cod_beneficio'              , 'VARCHAR2(10)'                from dual union all
    select 'sig_unid_com'               , 'VARCHAR2(6)'                 from dual union all
    select 'qtd_comercial'              , 'NUMBER'                      from dual union all
    select 'vlr_unit_com'               , 'NUMBER'                      from dual union all
    select 'vlr_produto'                , 'NUMBER'                      from dual union all
    select 'sig_unid_trib'              , 'VARCHAR2(6)'                 from dual union all
    select 'qtd_tributavel'             , 'NUMBER'                      from dual union all
    select 'vlr_unit_trib'              , 'NUMBER'                      from dual union all
    select 'vlr_frete'                  , 'NUMBER'                      from dual union all
    select 'vlr_seguro'                 , 'NUMBER'                      from dual union all
    select 'vlr_desconto'               , 'NUMBER'                      from dual union all
    select 'vlr_outros'                 , 'NUMBER'                      from dual union all
    select 'status_compoe_total'        , 'VARCHAR2(1)'                 from dual union all
    select 'vlr_item'                   , 'NUMBER'                      from dual union all
    select 'dsc_inf_adic'               , 'VARCHAR2(500)'               from dual union all
    select 'cod_cst_icms'               , 'VARCHAR2(4)'                 from dual union all
    select 'cod_origem'                 , 'VARCHAR2(1)'                 from dual union all
    select 'vlr_bc_icms'                , 'NUMBER'                      from dual union all
    select 'pct_icms'                   , 'NUMBER'                      from dual union all
    select 'vlr_icms'                   , 'NUMBER'                      from dual union all
    select 'vlr_bc_icms_st'             , 'NUMBER'                      from dual union all
    select 'vlr_icms_st'                , 'NUMBER'                      from dual union all
    select 'cod_cst_ipi'                , 'VARCHAR2(2)'                 from dual union all
    select 'vlr_bc_ipi'                 , 'NUMBER'                      from dual union all
    select 'pct_ipi'                    , 'NUMBER'                      from dual union all
    select 'vlr_ipi'                    , 'NUMBER'                      from dual union all
    select 'cod_cst_pis'                , 'VARCHAR2(2)'                 from dual union all
    select 'vlr_bc_pis'                 , 'NUMBER'                      from dual union all
    select 'pct_pis'                    , 'NUMBER'                      from dual union all
    select 'vlr_pis'                    , 'NUMBER'                      from dual union all
    select 'cod_cst_cofins'             , 'VARCHAR2(2)'                 from dual union all
    select 'vlr_bc_cofins'              , 'NUMBER'                      from dual union all
    select 'pct_cofins'                 , 'NUMBER'                      from dual union all
    select 'vlr_cofins'                 , 'NUMBER'                      from dual union all
    select 'cod_cst_ibscbs'             , 'VARCHAR2(3)'                 from dual union all
    select 'cod_class_trib'             , 'VARCHAR2(6)'                 from dual union all
    select 'vlr_bc_ibscbs'              , 'NUMBER'                      from dual union all
    select 'vlr_ibs'                    , 'NUMBER'                      from dual union all
    select 'vlr_cbs'                    , 'NUMBER'                      from dual union all
    select 'created_at'                 , 'DATE default sysdate'        from dual union all
    select 'created_by'                 , 'VARCHAR2(50)'                from dual
  ) loop
    begin
      select count(*) into qtd from all_tab_columns
       where owner = 'POSEIDON' and table_name = 'DPC_DFE_NOTA_ITEM'
         and column_name = upper(c.nome);

      if qtd = 0 then
        execute immediate 'alter table poseidon.dpc_dfe_nota_item add ('
                          || c.nome || ' ' || c.def || ')';
        dbms_output.put_line('DPC_DFE_NOTA_ITEM: acrescentada -> ' || c.nome);
      end if;
    exception
      when others then
        dbms_output.put_line('DPC_DFE_NOTA_ITEM: FALHOU em ' || c.nome || ' -> ' || sqlerrm);
    end;
  end loop;
end;

-- ---------- DPC_DFE_EVENTO ----------
declare
  qtd number;
begin
  for c in (
    select 'cod_dfe_evento'  as nome, 'NUMBER not null'           as def from dual union all
    select 'cod_dfe_empresa'        , 'NUMBER not null'                  from dual union all
    select 'cod_dfe_nota'           , 'NUMBER'                           from dual union all
    select 'chave_nf'               , 'VARCHAR2(44) not null'            from dual union all
    select 'nro_nsu'                , 'NUMBER'                           from dual union all
    select 'cod_tipo_evento'        , 'VARCHAR2(6)'                      from dual union all
    select 'dsc_evento'             , 'VARCHAR2(255)'                    from dual union all
    select 'nro_seq_evento'         , 'NUMBER default 1 not null'        from dual union all
    select 'nro_protocolo'          , 'VARCHAR2(20)'                     from dual union all
    select 'cod_status'             , 'VARCHAR2(5)'                      from dual union all
    select 'dsc_motivo'             , 'VARCHAR2(255)'                    from dual union all
    select 'dta_evento'             , 'TIMESTAMP(6)'                     from dual union all
    select 'created_at'             , 'DATE default sysdate'             from dual union all
    select 'created_by'             , 'VARCHAR2(50)'                     from dual
  ) loop
    begin
      select count(*) into qtd from all_tab_columns
       where owner = 'POSEIDON' and table_name = 'DPC_DFE_EVENTO'
         and column_name = upper(c.nome);

      if qtd = 0 then
        execute immediate 'alter table poseidon.dpc_dfe_evento add ('
                          || c.nome || ' ' || c.def || ')';
        dbms_output.put_line('DPC_DFE_EVENTO: acrescentada -> ' || c.nome);
      end if;
    exception
      when others then
        dbms_output.put_line('DPC_DFE_EVENTO: FALHOU em ' || c.nome || ' -> ' || sqlerrm);
    end;
  end loop;
end;

-- ---------- DPC_DFE_EXECUCAO ----------
declare
  qtd number;
begin
  for c in (
    select 'cod_dfe_execucao' as nome, 'NUMBER not null'                            as def from dual union all
    select 'cod_dfe_cursor'          , 'NUMBER not null'                                   from dual union all
    select 'cod_dfe_empresa'         , 'NUMBER not null'                                   from dual union all
    select 'dta_inicio'              , 'TIMESTAMP(6) default systimestamp not null'        from dual union all
    select 'dta_fim'                 , 'TIMESTAMP(6)'                                      from dual union all
    select 'nro_nsu_inicial'         , 'NUMBER'                                            from dual union all
    select 'nro_nsu_final'           , 'NUMBER'                                            from dual union all
    select 'qtd_consulta'            , 'NUMBER default 0 not null'                         from dual union all
    select 'qtd_documento'           , 'NUMBER default 0 not null'                         from dual union all
    select 'qtd_nota'                , 'NUMBER default 0 not null'                         from dual union all
    select 'qtd_evento'              , 'NUMBER default 0 not null'                         from dual union all
    select 'qtd_erro'                , 'NUMBER default 0 not null'                         from dual union all
    select 'cod_resultado'           , 'VARCHAR2(20)'                                      from dual union all
    select 'dsc_resultado'           , 'VARCHAR2(4000)'                                    from dual union all
    select 'created_by'              , 'VARCHAR2(50)'                                      from dual
  ) loop
    begin
      select count(*) into qtd from all_tab_columns
       where owner = 'POSEIDON' and table_name = 'DPC_DFE_EXECUCAO'
         and column_name = upper(c.nome);

      if qtd = 0 then
        execute immediate 'alter table poseidon.dpc_dfe_execucao add ('
                          || c.nome || ' ' || c.def || ')';
        dbms_output.put_line('DPC_DFE_EXECUCAO: acrescentada -> ' || c.nome);
      end if;
    exception
      when others then
        dbms_output.put_line('DPC_DFE_EXECUCAO: FALHOU em ' || c.nome || ' -> ' || sqlerrm);
    end;
  end loop;
end;

-- ---------- DPC_DFE_MANIFESTACAO ----------
declare
  qtd number;
begin
  for c in (
    select 'cod_dfe_manifestacao' as nome, 'NUMBER not null'                    as def from dual union all
    select 'cod_dfe_nota'                , 'NUMBER not null'                           from dual union all
    select 'cod_tipo_evento'             , 'VARCHAR2(6) not null'                      from dual union all
    select 'status_envio'                , 'VARCHAR2(1) default ''P'' not null'        from dual union all
    select 'cod_status_retorno'          , 'VARCHAR2(5)'                               from dual union all
    select 'dsc_status_retorno'          , 'VARCHAR2(255)'                             from dual union all
    select 'nro_protocolo'               , 'VARCHAR2(20)'                              from dual union all
    select 'qtd_tentativa'               , 'NUMBER default 0 not null'                 from dual union all
    select 'det_erro'                    , 'VARCHAR2(4000)'                            from dual union all
    select 'xml_retorno'                 , 'CLOB'                                      from dual union all
    select 'dta_envio'                   , 'TIMESTAMP(6)'                              from dual union all
    select 'dta_ultima_tentativa'        , 'TIMESTAMP(6)'                              from dual union all
    select 'dta_atualizacao'             , 'TIMESTAMP(6)'                              from dual union all
    select 'created_at'                  , 'DATE default sysdate'                      from dual union all
    select 'created_by'                  , 'VARCHAR2(50)'                              from dual
  ) loop
    begin
      select count(*) into qtd from all_tab_columns
       where owner = 'POSEIDON' and table_name = 'DPC_DFE_MANIFESTACAO'
         and column_name = upper(c.nome);

      if qtd = 0 then
        execute immediate 'alter table poseidon.dpc_dfe_manifestacao add ('
                          || c.nome || ' ' || c.def || ')';
        dbms_output.put_line('DPC_DFE_MANIFESTACAO: acrescentada -> ' || c.nome);
      end if;
    exception
      when others then
        dbms_output.put_line('DPC_DFE_MANIFESTACAO: FALHOU em ' || c.nome || ' -> ' || sqlerrm);
    end;
  end loop;
end;

-- ---------- DPC_DFE_CTE ----------
declare
  qtd number;
begin
  for c in (
    select 'cod_dfe_cte'        as nome, 'NUMBER not null'       as def from dual union all
    select 'cod_dfe_empresa'           , 'NUMBER not null'              from dual union all
    select 'chave_cte'                 , 'VARCHAR2(44) not null'        from dual union all
    select 'nro_nsu'                   , 'NUMBER'                       from dual union all
    select 'dsc_tipo_doc'              , 'VARCHAR2(10)'                 from dual union all
    select 'nro_modelo'                , 'NUMBER'                       from dual union all
    select 'nro_serie'                 , 'NUMBER'                       from dual union all
    select 'nro_cte'                   , 'NUMBER'                       from dual union all
    select 'dta_emissao'               , 'DATE'                         from dual union all
    select 'cod_cfop'                  , 'VARCHAR2(4)'                  from dual union all
    select 'dsc_natureza_oper'         , 'VARCHAR2(60)'                 from dual union all
    select 'cod_modal'                 , 'VARCHAR2(2)'                  from dual union all
    select 'cod_tipo_servico'          , 'VARCHAR2(1)'                  from dual union all
    select 'cod_tipo_cte'              , 'VARCHAR2(1)'                  from dual union all
    select 'dsc_municipio_ini'         , 'VARCHAR2(60)'                 from dual union all
    select 'sig_uf_ini'                , 'VARCHAR2(2)'                  from dual union all
    select 'dsc_municipio_fim'         , 'VARCHAR2(60)'                 from dual union all
    select 'sig_uf_fim'                , 'VARCHAR2(2)'                  from dual union all
    select 'num_cnpj_emitente'         , 'VARCHAR2(14)'                 from dual union all
    select 'dsc_razao_emitente'        , 'VARCHAR2(120)'                from dual union all
    select 'num_cnpj_remetente'        , 'VARCHAR2(14)'                 from dual union all
    select 'num_cnpj_expedidor'        , 'VARCHAR2(14)'                 from dual union all
    select 'num_cnpj_recebedor'        , 'VARCHAR2(14)'                 from dual union all
    select 'num_cnpj_destinat'         , 'VARCHAR2(14)'                 from dual union all
    select 'cod_tomador'               , 'VARCHAR2(1)'                  from dual union all
    select 'sig_papel_empresa'         , 'VARCHAR2(6)'                  from dual union all
    select 'vlr_prestacao'             , 'NUMBER'                       from dual union all
    select 'vlr_receber'               , 'NUMBER'                       from dual union all
    select 'nro_protocolo'             , 'VARCHAR2(20)'                 from dual union all
    select 'cod_situacao'              , 'NUMBER'                       from dual union all
    select 'dsc_situacao'              , 'VARCHAR2(20)'                 from dual union all
    select 'created_at'                , 'DATE default sysdate'         from dual union all
    select 'created_by'                , 'VARCHAR2(50)'                 from dual union all
    select 'updated_at'                , 'DATE'                         from dual union all
    select 'updated_by'                , 'VARCHAR2(50)'                 from dual
  ) loop
    begin
      select count(*) into qtd from all_tab_columns
       where owner = 'POSEIDON' and table_name = 'DPC_DFE_CTE'
         and column_name = upper(c.nome);

      if qtd = 0 then
        execute immediate 'alter table poseidon.dpc_dfe_cte add ('
                          || c.nome || ' ' || c.def || ')';
        dbms_output.put_line('DPC_DFE_CTE: acrescentada -> ' || c.nome);
      end if;
    exception
      when others then
        dbms_output.put_line('DPC_DFE_CTE: FALHOU em ' || c.nome || ' -> ' || sqlerrm);
    end;
  end loop;
end;

-- ---------- DPC_DFE_CTE_NFE ----------
declare
  qtd number;
begin
  for c in (
    select 'cod_dfe_cte_nfe' as nome, 'NUMBER not null'       as def from dual union all
    select 'cod_dfe_cte'            , 'NUMBER not null'              from dual union all
    select 'chave_nf'               , 'VARCHAR2(44) not null'        from dual union all
    select 'created_at'             , 'DATE default sysdate'         from dual union all
    select 'created_by'             , 'VARCHAR2(50)'                 from dual
  ) loop
    begin
      select count(*) into qtd from all_tab_columns
       where owner = 'POSEIDON' and table_name = 'DPC_DFE_CTE_NFE'
         and column_name = upper(c.nome);

      if qtd = 0 then
        execute immediate 'alter table poseidon.dpc_dfe_cte_nfe add ('
                          || c.nome || ' ' || c.def || ')';
        dbms_output.put_line('DPC_DFE_CTE_NFE: acrescentada -> ' || c.nome);
      end if;
    exception
      when others then
        dbms_output.put_line('DPC_DFE_CTE_NFE: FALHOU em ' || c.nome || ' -> ' || sqlerrm);
    end;
  end loop;
end;

-- ---------- DPC_DFE_CTE_EVENTO ----------
declare
  qtd number;
begin
  for c in (
    select 'cod_dfe_cte_evento' as nome, 'NUMBER not null'           as def from dual union all
    select 'cod_dfe_empresa'           , 'NUMBER not null'                  from dual union all
    select 'cod_dfe_cte'               , 'NUMBER'                           from dual union all
    select 'chave_cte'                 , 'VARCHAR2(44) not null'            from dual union all
    select 'nro_nsu'                   , 'NUMBER'                           from dual union all
    select 'cod_tipo_evento'           , 'VARCHAR2(6)'                      from dual union all
    select 'dsc_evento'                , 'VARCHAR2(255)'                    from dual union all
    select 'nro_seq_evento'            , 'NUMBER default 1 not null'        from dual union all
    select 'nro_protocolo'             , 'VARCHAR2(20)'                     from dual union all
    select 'cod_status'                , 'VARCHAR2(5)'                      from dual union all
    select 'dsc_motivo'                , 'VARCHAR2(255)'                    from dual union all
    select 'dta_evento'                , 'TIMESTAMP(6)'                     from dual union all
    select 'num_cnpj_autor'            , 'VARCHAR2(14)'                     from dual union all
    select 'dta_entrega'               , 'TIMESTAMP(6)'                     from dual union all
    select 'num_doc_recebedor'         , 'VARCHAR2(60)'                     from dual union all
    select 'dsc_nome_recebedor'        , 'VARCHAR2(60)'                     from dual union all
    select 'dsc_hash_entrega'          , 'VARCHAR2(60)'                     from dual union all
    select 'chave_mdfe'                , 'VARCHAR2(44)'                     from dual union all
    select 'created_at'                , 'DATE default sysdate'             from dual union all
    select 'created_by'                , 'VARCHAR2(50)'                     from dual
  ) loop
    begin
      select count(*) into qtd from all_tab_columns
       where owner = 'POSEIDON' and table_name = 'DPC_DFE_CTE_EVENTO'
         and column_name = upper(c.nome);

      if qtd = 0 then
        execute immediate 'alter table poseidon.dpc_dfe_cte_evento add ('
                          || c.nome || ' ' || c.def || ')';
        dbms_output.put_line('DPC_DFE_CTE_EVENTO: acrescentada -> ' || c.nome);
      end if;
    exception
      when others then
        dbms_output.put_line('DPC_DFE_CTE_EVENTO: FALHOU em ' || c.nome || ' -> ' || sqlerrm);
    end;
  end loop;
end;

-- ---------- DPC_DFE_NFSE ----------
declare
  qtd number;
begin
  for c in (
    select 'cod_dfe_nfse'         as nome, 'NUMBER not null'       as def from dual union all
    select 'cod_dfe_empresa'             , 'NUMBER not null'              from dual union all
    select 'chave_nfse'                  , 'VARCHAR2(50) not null'        from dual union all
    select 'nro_nsu'                     , 'NUMBER'                       from dual union all
    select 'dsc_tipo_doc'                , 'VARCHAR2(10)'                 from dual union all
    select 'nro_nfse'                    , 'VARCHAR2(15)'                 from dual union all
    select 'dta_processamento'           , 'DATE'                         from dual union all
    select 'dta_competencia'             , 'DATE'                         from dual union all
    select 'cod_situacao'                , 'NUMBER'                       from dual union all
    select 'dsc_situacao'                , 'VARCHAR2(20)'                 from dual union all
    select 'sig_papel_empresa'           , 'VARCHAR2(6)'                  from dual union all
    select 'num_cnpj_cpf_prest'          , 'VARCHAR2(14)'                 from dual union all
    select 'dsc_razao_prest'             , 'VARCHAR2(120)'                from dual union all
    select 'num_insc_munic_prest'        , 'VARCHAR2(20)'                 from dual union all
    select 'cod_municipio_prest'         , 'VARCHAR2(7)'                  from dual union all
    select 'sig_uf_prest'                , 'VARCHAR2(2)'                  from dual union all
    select 'num_cnpj_cpf_toma'           , 'VARCHAR2(14)'                 from dual union all
    select 'dsc_razao_toma'              , 'VARCHAR2(120)'                from dual union all
    select 'cod_municipio_incid'         , 'VARCHAR2(7)'                  from dual union all
    select 'dsc_municipio_incid'         , 'VARCHAR2(60)'                 from dual union all
    select 'cod_trib_nacional'           , 'VARCHAR2(10)'                 from dual union all
    select 'cod_trib_municipal'          , 'VARCHAR2(20)'                 from dual union all
    select 'dsc_servico'                 , 'VARCHAR2(2000)'               from dual union all
    select 'vlr_servico'                 , 'NUMBER'                       from dual union all
    select 'vlr_base_calculo'            , 'NUMBER'                       from dual union all
    select 'pct_aliquota'                , 'NUMBER'                       from dual union all
    select 'vlr_issqn'                   , 'NUMBER'                       from dual union all
    select 'vlr_retido'                  , 'NUMBER'                       from dual union all
    select 'vlr_liquido'                 , 'NUMBER'                       from dual union all
    select 'created_at'                  , 'DATE default sysdate'         from dual union all
    select 'created_by'                  , 'VARCHAR2(50)'                 from dual union all
    select 'updated_at'                  , 'DATE'                         from dual union all
    select 'updated_by'                  , 'VARCHAR2(50)'                 from dual
  ) loop
    begin
      select count(*) into qtd from all_tab_columns
       where owner = 'POSEIDON' and table_name = 'DPC_DFE_NFSE'
         and column_name = upper(c.nome);

      if qtd = 0 then
        execute immediate 'alter table poseidon.dpc_dfe_nfse add ('
                          || c.nome || ' ' || c.def || ')';
        dbms_output.put_line('DPC_DFE_NFSE: acrescentada -> ' || c.nome);
      end if;
    exception
      when others then
        dbms_output.put_line('DPC_DFE_NFSE: FALHOU em ' || c.nome || ' -> ' || sqlerrm);
    end;
  end loop;
end;


-- ###########################################################################
--  4. CONSTRAINTS
--  Duas ausencias sao DELIBERADAS e cada uma tem historia:
--
--   DPC_DFE_EMPRESA_CK1 - existia sobre status_sincronismo, coluna que saiu
--     desta tabela para DPC_DFE_CURSOR. Recriar aqui seria ressuscitar
--     constraint de coluna inexistente.
--
--   DPC_DFE_DOCUMENTO_UK1 (empresa, nsu) - substituida pela UK2
--     (cursor, nsu). O NSU e sequencial POR FLUXO: o NSU 100 da NF-e e o
--     NSU 100 do CT-e sao documentos distintos e colidiriam na UK antiga,
--     fazendo a unique que protege contra duplicidade virar perda.
--
--  E um detalhe do CT-e que a DPC_DFE_CTE_CK1 registra: os papeis aceitos
--  sao REM, EXPED, RECEB, DEST, TOMA e OUTRO - NAO existe EMIT. Quando a
--  propria DPC EMITE o CT-e (a empresa 3 e transportadora), o CNPJ nao
--  aparece em nenhum dos quatro papeis que o parser le, e a linha fica como
--  OUTRO. Nao e erro, e o comportamento atual - mas significa que OUTRO hoje
--  mistura frete que emitimos com aparecemos por outro motivo. Para separar,
--  a tela compara num_cnpj_emitente com o CNPJ da empresa.
-- ###########################################################################

declare
  qtd number;
begin
  select count(*) into qtd from all_constraints
   where owner = 'POSEIDON' and constraint_name = 'DPC_DFE_EMPRESA_PK';

  if qtd = 0 then
    execute immediate q'[alter table poseidon.dpc_dfe_empresa add constraint DPC_DFE_EMPRESA_PK primary key (cod_dfe_empresa) using index tablespace TSD_POSEIDON]';
  end if;
end;

declare
  qtd number;
begin
  select count(*) into qtd from all_constraints
   where owner = 'POSEIDON' and constraint_name = 'DPC_DFE_EMPRESA_UK1';

  if qtd = 0 then
    execute immediate q'[alter table poseidon.dpc_dfe_empresa add constraint DPC_DFE_EMPRESA_UK1 unique (num_cnpj) using index tablespace TSD_POSEIDON]';
  end if;
end;

declare
  qtd number;
begin
  select count(*) into qtd from all_constraints
   where owner = 'POSEIDON' and constraint_name = 'DPC_DFE_EMPRESA_CK2';

  if qtd = 0 then
    execute immediate q'[alter table poseidon.dpc_dfe_empresa add constraint DPC_DFE_EMPRESA_CK2 check (status_manifestar in ('N','S'))]';
  end if;
end;

declare
  qtd number;
begin
  select count(*) into qtd from all_constraints
   where owner = 'POSEIDON' and constraint_name = 'DPC_DFE_CURSOR_PK';

  if qtd = 0 then
    execute immediate q'[alter table poseidon.dpc_dfe_cursor add constraint DPC_DFE_CURSOR_PK primary key (cod_dfe_cursor) using index tablespace TSD_POSEIDON]';
  end if;
end;

declare
  qtd number;
begin
  select count(*) into qtd from all_constraints
   where owner = 'POSEIDON' and constraint_name = 'DPC_DFE_CURSOR_UK1';

  if qtd = 0 then
    execute immediate q'[alter table poseidon.dpc_dfe_cursor add constraint DPC_DFE_CURSOR_UK1 unique (cod_dfe_empresa, cod_tipo_dfe) using index tablespace TSD_POSEIDON]';
  end if;
end;

declare
  qtd number;
begin
  select count(*) into qtd from all_constraints
   where owner = 'POSEIDON' and constraint_name = 'DPC_DFE_CURSOR_FK1';

  if qtd = 0 then
    execute immediate q'[alter table poseidon.dpc_dfe_cursor add constraint DPC_DFE_CURSOR_FK1 foreign key (cod_dfe_empresa) references poseidon.dpc_dfe_empresa (cod_dfe_empresa)]';
  end if;
end;

declare
  qtd number;
begin
  select count(*) into qtd from all_constraints
   where owner = 'POSEIDON' and constraint_name = 'DPC_DFE_CURSOR_CK1';

  if qtd = 0 then
    execute immediate q'[alter table poseidon.dpc_dfe_cursor add constraint DPC_DFE_CURSOR_CK1 check (cod_tipo_dfe in ('NFE','CTE','MDFE','NFSE'))]';
  end if;
end;

declare
  qtd number;
begin
  select count(*) into qtd from all_constraints
   where owner = 'POSEIDON' and constraint_name = 'DPC_DFE_CURSOR_CK2';

  if qtd = 0 then
    execute immediate q'[alter table poseidon.dpc_dfe_cursor add constraint DPC_DFE_CURSOR_CK2 check (status_sincronismo in ('A','P','B','C'))]';
  end if;
end;

declare
  qtd number;
begin
  select count(*) into qtd from all_constraints
   where owner = 'POSEIDON' and constraint_name = 'DPC_DFE_EMITENTE_PK';

  if qtd = 0 then
    execute immediate q'[alter table poseidon.dpc_dfe_emitente add constraint DPC_DFE_EMITENTE_PK primary key (cod_dfe_emitente) using index tablespace TSD_POSEIDON]';
  end if;
end;

declare
  qtd number;
begin
  select count(*) into qtd from all_constraints
   where owner = 'POSEIDON' and constraint_name = 'DPC_DFE_EMITENTE_UK1';

  if qtd = 0 then
    execute immediate q'[alter table poseidon.dpc_dfe_emitente add constraint DPC_DFE_EMITENTE_UK1 unique (num_cnpj_cpf) using index tablespace TSD_POSEIDON]';
  end if;
end;

declare
  qtd number;
begin
  select count(*) into qtd from all_constraints
   where owner = 'POSEIDON' and constraint_name = 'DPC_DFE_DOCUMENTO_PK';

  if qtd = 0 then
    execute immediate q'[alter table poseidon.dpc_dfe_documento add constraint DPC_DFE_DOCUMENTO_PK primary key (cod_dfe_documento) using index tablespace TSD_POSEIDON]';
  end if;
end;

declare
  qtd number;
begin
  select count(*) into qtd from all_constraints
   where owner = 'POSEIDON' and constraint_name = 'DPC_DFE_DOCUMENTO_UK2';

  if qtd = 0 then
    execute immediate q'[alter table poseidon.dpc_dfe_documento add constraint DPC_DFE_DOCUMENTO_UK2 unique (cod_dfe_cursor, nro_nsu) using index tablespace TSD_POSEIDON]';
  end if;
end;

declare
  qtd number;
begin
  select count(*) into qtd from all_constraints
   where owner = 'POSEIDON' and constraint_name = 'DPC_DFE_DOCUMENTO_FK1';

  if qtd = 0 then
    execute immediate q'[alter table poseidon.dpc_dfe_documento add constraint DPC_DFE_DOCUMENTO_FK1 foreign key (cod_dfe_empresa) references poseidon.dpc_dfe_empresa (cod_dfe_empresa)]';
  end if;
end;

declare
  qtd number;
begin
  select count(*) into qtd from all_constraints
   where owner = 'POSEIDON' and constraint_name = 'DPC_DFE_DOCUMENTO_FK2';

  if qtd = 0 then
    execute immediate q'[alter table poseidon.dpc_dfe_documento add constraint DPC_DFE_DOCUMENTO_FK2 foreign key (cod_dfe_cursor) references poseidon.dpc_dfe_cursor (cod_dfe_cursor)]';
  end if;
end;

declare
  qtd number;
begin
  select count(*) into qtd from all_constraints
   where owner = 'POSEIDON' and constraint_name = 'DPC_DFE_DOCUMENTO_CK1';

  if qtd = 0 then
    execute immediate q'[alter table poseidon.dpc_dfe_documento add constraint DPC_DFE_DOCUMENTO_CK1 check (status_process in ('P','A','C','E','I'))]';
  end if;
end;

declare
  qtd number;
begin
  select count(*) into qtd from all_constraints
   where owner = 'POSEIDON' and constraint_name = 'DPC_DFE_NOTA_PK';

  if qtd = 0 then
    execute immediate q'[alter table poseidon.dpc_dfe_nota add constraint DPC_DFE_NOTA_PK primary key (cod_dfe_nota) using index tablespace TSD_POSEIDON]';
  end if;
end;

declare
  qtd number;
begin
  select count(*) into qtd from all_constraints
   where owner = 'POSEIDON' and constraint_name = 'DPC_DFE_NOTA_UK1';

  if qtd = 0 then
    execute immediate q'[alter table poseidon.dpc_dfe_nota add constraint DPC_DFE_NOTA_UK1 unique (cod_dfe_empresa, chave_nf) using index tablespace TSD_POSEIDON]';
  end if;
end;

declare
  qtd number;
begin
  select count(*) into qtd from all_constraints
   where owner = 'POSEIDON' and constraint_name = 'DPC_DFE_NOTA_FK1';

  if qtd = 0 then
    execute immediate q'[alter table poseidon.dpc_dfe_nota add constraint DPC_DFE_NOTA_FK1 foreign key (cod_dfe_empresa) references poseidon.dpc_dfe_empresa (cod_dfe_empresa)]';
  end if;
end;

declare
  qtd number;
begin
  select count(*) into qtd from all_constraints
   where owner = 'POSEIDON' and constraint_name = 'DPC_DFE_NOTA_FK2';

  if qtd = 0 then
    execute immediate q'[alter table poseidon.dpc_dfe_nota add constraint DPC_DFE_NOTA_FK2 foreign key (cod_dfe_emitente) references poseidon.dpc_dfe_emitente (cod_dfe_emitente)]';
  end if;
end;

declare
  qtd number;
begin
  select count(*) into qtd from all_constraints
   where owner = 'POSEIDON' and constraint_name = 'DPC_DFE_NOTA_CK1';

  if qtd = 0 then
    execute immediate q'[alter table poseidon.dpc_dfe_nota add constraint DPC_DFE_NOTA_CK1 check (status_manifestacao in ('N','C','X'))]';
  end if;
end;

declare
  qtd number;
begin
  select count(*) into qtd from all_constraints
   where owner = 'POSEIDON' and constraint_name = 'DPC_DFE_NOTA_CK2';

  if qtd = 0 then
    execute immediate q'[alter table poseidon.dpc_dfe_nota add constraint DPC_DFE_NOTA_CK2 check (status_recebimento in ('N','S'))]';
  end if;
end;

declare
  qtd number;
begin
  select count(*) into qtd from all_constraints
   where owner = 'POSEIDON' and constraint_name = 'DPC_DFE_NOTA_CK3';

  if qtd = 0 then
    execute immediate q'[alter table poseidon.dpc_dfe_nota add constraint DPC_DFE_NOTA_CK3 check (sig_papel_empresa in ('DEST','EMIT','TRANSP','AUTXML','OUTRO','INDEF'))]';
  end if;
end;

declare
  qtd number;
begin
  select count(*) into qtd from all_constraints
   where owner = 'POSEIDON' and constraint_name = 'DPC_DFE_NOTA_CK4';

  if qtd = 0 then
    execute immediate q'[alter table poseidon.dpc_dfe_nota add constraint DPC_DFE_NOTA_CK4 check ((sig_estado_erp is null and num_estado_erp is null) or (sig_estado_erp = 'AGUARDANDO_ENTRADA' and num_estado_erp = 0) or (sig_estado_erp = 'EM_DIGITACAO' and num_estado_erp = 1) or (sig_estado_erp = 'RECEBIDA' and num_estado_erp = 2) or (sig_estado_erp = 'ESCRITURADA' and num_estado_erp = 3))]';
  end if;
end;

declare
  qtd number;
begin
  select count(*) into qtd from all_constraints
   where owner = 'POSEIDON' and constraint_name = 'DPC_DFE_NOTA_CK5';

  if qtd = 0 then
    execute immediate q'[alter table poseidon.dpc_dfe_nota add constraint DPC_DFE_NOTA_CK5 check (num_estado_erp_max is null or num_estado_erp_max between 0 and 3)]';
  end if;
end;

declare
  qtd number;
begin
  select count(*) into qtd from all_constraints
   where owner = 'POSEIDON' and constraint_name = 'DPC_DFE_NOTA_ITEM_PK';

  if qtd = 0 then
    execute immediate q'[alter table poseidon.dpc_dfe_nota_item add constraint DPC_DFE_NOTA_ITEM_PK primary key (cod_dfe_nota_item) using index tablespace TSD_POSEIDON]';
  end if;
end;

declare
  qtd number;
begin
  select count(*) into qtd from all_constraints
   where owner = 'POSEIDON' and constraint_name = 'DPC_DFE_NOTA_ITEM_UK1';

  if qtd = 0 then
    execute immediate q'[alter table poseidon.dpc_dfe_nota_item add constraint DPC_DFE_NOTA_ITEM_UK1 unique (cod_dfe_nota, nro_item) using index tablespace TSD_POSEIDON]';
  end if;
end;

declare
  qtd number;
begin
  select count(*) into qtd from all_constraints
   where owner = 'POSEIDON' and constraint_name = 'DPC_DFE_NOTA_ITEM_FK1';

  if qtd = 0 then
    execute immediate q'[alter table poseidon.dpc_dfe_nota_item add constraint DPC_DFE_NOTA_ITEM_FK1 foreign key (cod_dfe_nota) references poseidon.dpc_dfe_nota (cod_dfe_nota)]';
  end if;
end;

declare
  qtd number;
begin
  select count(*) into qtd from all_constraints
   where owner = 'POSEIDON' and constraint_name = 'DPC_DFE_NOTA_ITEM_CK1';

  if qtd = 0 then
    execute immediate q'[alter table poseidon.dpc_dfe_nota_item add constraint DPC_DFE_NOTA_ITEM_CK1 check (status_compoe_total in ('0','1'))]';
  end if;
end;

declare
  qtd number;
begin
  select count(*) into qtd from all_constraints
   where owner = 'POSEIDON' and constraint_name = 'DPC_DFE_EVENTO_PK';

  if qtd = 0 then
    execute immediate q'[alter table poseidon.dpc_dfe_evento add constraint DPC_DFE_EVENTO_PK primary key (cod_dfe_evento) using index tablespace TSD_POSEIDON]';
  end if;
end;

declare
  qtd number;
begin
  select count(*) into qtd from all_constraints
   where owner = 'POSEIDON' and constraint_name = 'DPC_DFE_EVENTO_UK1';

  if qtd = 0 then
    execute immediate q'[alter table poseidon.dpc_dfe_evento add constraint DPC_DFE_EVENTO_UK1 unique (chave_nf, cod_tipo_evento, nro_seq_evento) using index tablespace TSD_POSEIDON]';
  end if;
end;

declare
  qtd number;
begin
  select count(*) into qtd from all_constraints
   where owner = 'POSEIDON' and constraint_name = 'DPC_DFE_EVENTO_FK1';

  if qtd = 0 then
    execute immediate q'[alter table poseidon.dpc_dfe_evento add constraint DPC_DFE_EVENTO_FK1 foreign key (cod_dfe_empresa) references poseidon.dpc_dfe_empresa (cod_dfe_empresa)]';
  end if;
end;

declare
  qtd number;
begin
  select count(*) into qtd from all_constraints
   where owner = 'POSEIDON' and constraint_name = 'DPC_DFE_EVENTO_FK2';

  if qtd = 0 then
    execute immediate q'[alter table poseidon.dpc_dfe_evento add constraint DPC_DFE_EVENTO_FK2 foreign key (cod_dfe_nota) references poseidon.dpc_dfe_nota (cod_dfe_nota)]';
  end if;
end;

declare
  qtd number;
begin
  select count(*) into qtd from all_constraints
   where owner = 'POSEIDON' and constraint_name = 'DPC_DFE_EXECUCAO_PK';

  if qtd = 0 then
    execute immediate q'[alter table poseidon.dpc_dfe_execucao add constraint DPC_DFE_EXECUCAO_PK primary key (cod_dfe_execucao) using index tablespace TSD_POSEIDON]';
  end if;
end;

declare
  qtd number;
begin
  select count(*) into qtd from all_constraints
   where owner = 'POSEIDON' and constraint_name = 'DPC_DFE_EXECUCAO_FK1';

  if qtd = 0 then
    execute immediate q'[alter table poseidon.dpc_dfe_execucao add constraint DPC_DFE_EXECUCAO_FK1 foreign key (cod_dfe_empresa) references poseidon.dpc_dfe_empresa (cod_dfe_empresa)]';
  end if;
end;

declare
  qtd number;
begin
  select count(*) into qtd from all_constraints
   where owner = 'POSEIDON' and constraint_name = 'DPC_DFE_EXECUCAO_FK2';

  if qtd = 0 then
    execute immediate q'[alter table poseidon.dpc_dfe_execucao add constraint DPC_DFE_EXECUCAO_FK2 foreign key (cod_dfe_cursor) references poseidon.dpc_dfe_cursor (cod_dfe_cursor)]';
  end if;
end;

declare
  qtd number;
begin
  select count(*) into qtd from all_constraints
   where owner = 'POSEIDON' and constraint_name = 'DPC_DFE_MANIFESTACAO_PK';

  if qtd = 0 then
    execute immediate q'[alter table poseidon.dpc_dfe_manifestacao add constraint DPC_DFE_MANIFESTACAO_PK primary key (cod_dfe_manifestacao) using index tablespace TSD_POSEIDON]';
  end if;
end;

declare
  qtd number;
begin
  select count(*) into qtd from all_constraints
   where owner = 'POSEIDON' and constraint_name = 'DPC_DFE_MANIF_UK1';

  if qtd = 0 then
    execute immediate q'[alter table poseidon.dpc_dfe_manifestacao add constraint DPC_DFE_MANIF_UK1 unique (cod_dfe_nota, cod_tipo_evento) using index tablespace TSD_POSEIDON]';
  end if;
end;

declare
  qtd number;
begin
  select count(*) into qtd from all_constraints
   where owner = 'POSEIDON' and constraint_name = 'DPC_DFE_MANIF_FK1';

  if qtd = 0 then
    execute immediate q'[alter table poseidon.dpc_dfe_manifestacao add constraint DPC_DFE_MANIF_FK1 foreign key (cod_dfe_nota) references poseidon.dpc_dfe_nota (cod_dfe_nota)]';
  end if;
end;

declare
  qtd number;
begin
  select count(*) into qtd from all_constraints
   where owner = 'POSEIDON' and constraint_name = 'DPC_DFE_MANIF_CK1';

  if qtd = 0 then
    execute immediate q'[alter table poseidon.dpc_dfe_manifestacao add constraint DPC_DFE_MANIF_CK1 check (status_envio in ('P','E','F'))]';
  end if;
end;

declare
  qtd number;
begin
  select count(*) into qtd from all_constraints
   where owner = 'POSEIDON' and constraint_name = 'DPC_DFE_CTE_PK';

  if qtd = 0 then
    execute immediate q'[alter table poseidon.dpc_dfe_cte add constraint DPC_DFE_CTE_PK primary key (cod_dfe_cte) using index tablespace TSD_POSEIDON]';
  end if;
end;

declare
  qtd number;
begin
  select count(*) into qtd from all_constraints
   where owner = 'POSEIDON' and constraint_name = 'DPC_DFE_CTE_UK1';

  if qtd = 0 then
    execute immediate q'[alter table poseidon.dpc_dfe_cte add constraint DPC_DFE_CTE_UK1 unique (cod_dfe_empresa, chave_cte) using index tablespace TSD_POSEIDON]';
  end if;
end;

declare
  qtd number;
begin
  select count(*) into qtd from all_constraints
   where owner = 'POSEIDON' and constraint_name = 'DPC_DFE_CTE_FK1';

  if qtd = 0 then
    execute immediate q'[alter table poseidon.dpc_dfe_cte add constraint DPC_DFE_CTE_FK1 foreign key (cod_dfe_empresa) references poseidon.dpc_dfe_empresa (cod_dfe_empresa)]';
  end if;
end;

declare
  qtd number;
begin
  select count(*) into qtd from all_constraints
   where owner = 'POSEIDON' and constraint_name = 'DPC_DFE_CTE_CK1';

  if qtd = 0 then
    execute immediate q'[alter table poseidon.dpc_dfe_cte add constraint DPC_DFE_CTE_CK1 check (sig_papel_empresa in ('REM','EXPED','RECEB','DEST','TOMA','OUTRO'))]';
  end if;
end;

declare
  qtd number;
begin
  select count(*) into qtd from all_constraints
   where owner = 'POSEIDON' and constraint_name = 'DPC_DFE_CTE_NFE_PK';

  if qtd = 0 then
    execute immediate q'[alter table poseidon.dpc_dfe_cte_nfe add constraint DPC_DFE_CTE_NFE_PK primary key (cod_dfe_cte_nfe) using index tablespace TSD_POSEIDON]';
  end if;
end;

declare
  qtd number;
begin
  select count(*) into qtd from all_constraints
   where owner = 'POSEIDON' and constraint_name = 'DPC_DFE_CTE_NFE_UK1';

  if qtd = 0 then
    execute immediate q'[alter table poseidon.dpc_dfe_cte_nfe add constraint DPC_DFE_CTE_NFE_UK1 unique (cod_dfe_cte, chave_nf) using index tablespace TSD_POSEIDON]';
  end if;
end;

declare
  qtd number;
begin
  select count(*) into qtd from all_constraints
   where owner = 'POSEIDON' and constraint_name = 'DPC_DFE_CTE_NFE_FK1';

  if qtd = 0 then
    execute immediate q'[alter table poseidon.dpc_dfe_cte_nfe add constraint DPC_DFE_CTE_NFE_FK1 foreign key (cod_dfe_cte) references poseidon.dpc_dfe_cte (cod_dfe_cte)]';
  end if;
end;

declare
  qtd number;
begin
  select count(*) into qtd from all_constraints
   where owner = 'POSEIDON' and constraint_name = 'DPC_DFE_CTE_EVENTO_PK';

  if qtd = 0 then
    execute immediate q'[alter table poseidon.dpc_dfe_cte_evento add constraint DPC_DFE_CTE_EVENTO_PK primary key (cod_dfe_cte_evento) using index tablespace TSD_POSEIDON]';
  end if;
end;

declare
  qtd number;
begin
  select count(*) into qtd from all_constraints
   where owner = 'POSEIDON' and constraint_name = 'DPC_DFE_CTE_EVENTO_UK1';

  if qtd = 0 then
    execute immediate q'[alter table poseidon.dpc_dfe_cte_evento add constraint DPC_DFE_CTE_EVENTO_UK1 unique (chave_cte, cod_tipo_evento, nro_seq_evento) using index tablespace TSD_POSEIDON]';
  end if;
end;

declare
  qtd number;
begin
  select count(*) into qtd from all_constraints
   where owner = 'POSEIDON' and constraint_name = 'DPC_DFE_CTE_EVENTO_FK1';

  if qtd = 0 then
    execute immediate q'[alter table poseidon.dpc_dfe_cte_evento add constraint DPC_DFE_CTE_EVENTO_FK1 foreign key (cod_dfe_empresa) references poseidon.dpc_dfe_empresa (cod_dfe_empresa)]';
  end if;
end;

declare
  qtd number;
begin
  select count(*) into qtd from all_constraints
   where owner = 'POSEIDON' and constraint_name = 'DPC_DFE_CTE_EVENTO_FK2';

  if qtd = 0 then
    execute immediate q'[alter table poseidon.dpc_dfe_cte_evento add constraint DPC_DFE_CTE_EVENTO_FK2 foreign key (cod_dfe_cte) references poseidon.dpc_dfe_cte (cod_dfe_cte)]';
  end if;
end;

declare
  qtd number;
begin
  select count(*) into qtd from all_constraints
   where owner = 'POSEIDON' and constraint_name = 'DPC_DFE_NFSE_PK';

  if qtd = 0 then
    execute immediate q'[alter table poseidon.dpc_dfe_nfse add constraint DPC_DFE_NFSE_PK primary key (cod_dfe_nfse) using index tablespace TSD_POSEIDON]';
  end if;
end;

declare
  qtd number;
begin
  select count(*) into qtd from all_constraints
   where owner = 'POSEIDON' and constraint_name = 'DPC_DFE_NFSE_UK1';

  if qtd = 0 then
    execute immediate q'[alter table poseidon.dpc_dfe_nfse add constraint DPC_DFE_NFSE_UK1 unique (cod_dfe_empresa, chave_nfse) using index tablespace TSD_POSEIDON]';
  end if;
end;

declare
  qtd number;
begin
  select count(*) into qtd from all_constraints
   where owner = 'POSEIDON' and constraint_name = 'DPC_DFE_NFSE_FK1';

  if qtd = 0 then
    execute immediate q'[alter table poseidon.dpc_dfe_nfse add constraint DPC_DFE_NFSE_FK1 foreign key (cod_dfe_empresa) references poseidon.dpc_dfe_empresa (cod_dfe_empresa)]';
  end if;
end;

declare
  qtd number;
begin
  select count(*) into qtd from all_constraints
   where owner = 'POSEIDON' and constraint_name = 'DPC_DFE_NFSE_CK1';

  if qtd = 0 then
    execute immediate q'[alter table poseidon.dpc_dfe_nfse add constraint DPC_DFE_NFSE_CK1 check (sig_papel_empresa in ('PREST','TOMA','INTERM','OUTRO'))]';
  end if;
end;


-- ###########################################################################
--  5. INDICES
--  Somente os que nao vem de constraint. PK e UK ja criam o seu.
--
--  DPC_DFE_EMPRESA_IX1 nao esta aqui, e a ausencia e deliberada: ele era
--  sobre (status_sincronismo, dta_liberado_em), duas colunas que sairam desta
--  tabela para DPC_DFE_CURSOR. O indice equivalente e o DPCI_DFE_CURSOR.
-- ###########################################################################
--  fila de elegiveis: quem esta ativo e com cooldown vencido
declare
  qtd number;
begin
  select count(*) into qtd from all_indexes
   where owner = 'POSEIDON' and index_name = 'DPCI_DFE_CURSOR';

  if qtd = 0 then
    execute immediate q'[create index poseidon.DPCI_DFE_CURSOR on poseidon.dpc_dfe_cursor (status_sincronismo, dta_liberado_em) tablespace TSD_POSEIDON]';
  end if;
end;

--  fila do bruto, e o alerta de documento parado ha mais de 24h
declare
  qtd number;
begin
  select count(*) into qtd from all_indexes
   where owner = 'POSEIDON' and index_name = 'DPC_DFE_DOCUMENTO_IX1';

  if qtd = 0 then
    execute immediate q'[create index poseidon.DPC_DFE_DOCUMENTO_IX1 on poseidon.dpc_dfe_documento (status_process, dta_recebimento) tablespace TSD_POSEIDON]';
  end if;
end;

--  download do XML pela chave
declare
  qtd number;
begin
  select count(*) into qtd from all_indexes
   where owner = 'POSEIDON' and index_name = 'DPC_DFE_DOCUMENTO_IX2';

  if qtd = 0 then
    execute immediate q'[create index poseidon.DPC_DFE_DOCUMENTO_IX2 on poseidon.dpc_dfe_documento (chave_nf) tablespace TSD_POSEIDON]';
  end if;
end;

--  FK sem indice faz lock de tabela no filho quando se apaga linha do pai, e
--  este filho e o que guarda os BLOB. Tambem serve ao delete por empresa do
--  98/99_rollback. Achado em 09/09/2026 pelo assert "FK sem indice" da
--  validacao, que acusava 1 numa base tida por completa.
declare
  qtd number;
begin
  select count(*) into qtd from all_indexes
   where owner = 'POSEIDON' and index_name = 'DPC_DFE_DOCUMENTO_IX3';

  if qtd = 0 then
    execute immediate q'[create index poseidon.DPC_DFE_DOCUMENTO_IX3 on poseidon.dpc_dfe_documento (cod_dfe_empresa) tablespace TSD_POSEIDON]';
  end if;
end;

--  FK sem indice faz lock de tabela no pai; e tambem o filtro por fornecedor
declare
  qtd number;
begin
  select count(*) into qtd from all_indexes
   where owner = 'POSEIDON' and index_name = 'DPC_DFE_NOTA_IX1';

  if qtd = 0 then
    execute immediate q'[create index poseidon.DPC_DFE_NOTA_IX1 on poseidon.dpc_dfe_nota (cod_dfe_emitente) tablespace TSD_POSEIDON]';
  end if;
end;

--  busca por chave sem informar a empresa - a UK1 tem empresa na frente
declare
  qtd number;
begin
  select count(*) into qtd from all_indexes
   where owner = 'POSEIDON' and index_name = 'DPC_DFE_NOTA_IX2';

  if qtd = 0 then
    execute immediate q'[create index poseidon.DPC_DFE_NOTA_IX2 on poseidon.dpc_dfe_nota (chave_nf) tablespace TSD_POSEIDON]';
  end if;
end;

--  as quatro abas da tela: recorta o mesmo acervo por papel, dentro de um estabelecimento e um periodo
declare
  qtd number;
begin
  select count(*) into qtd from all_indexes
   where owner = 'POSEIDON' and index_name = 'DPCI_DFE_NOTA_PAPEL';

  if qtd = 0 then
    execute immediate q'[create index poseidon.DPCI_DFE_NOTA_PAPEL on poseidon.dpc_dfe_nota (cod_dfe_empresa, sig_papel_empresa, dta_emissao) tablespace TSD_POSEIDON]';
  end if;
end;

--  a lista que a contabilidade pede: nota que ainda nao entrou no ERP
declare
  qtd number;
begin
  select count(*) into qtd from all_indexes
   where owner = 'POSEIDON' and index_name = 'DPCI_DFE_NOTA_CONC';

  if qtd = 0 then
    execute immediate q'[create index poseidon.DPCI_DFE_NOTA_CONC on poseidon.dpc_dfe_nota (status_recebimento, dta_emissao) tablespace TSD_POSEIDON]';
  end if;
end;

--  classificacao fiscal e o filtro analitico da tabela. O acesso dominante - itens de uma nota - ja e servido pela UK1, cujo prefixo e cod_dfe_nota
declare
  qtd number;
begin
  select count(*) into qtd from all_indexes
   where owner = 'POSEIDON' and index_name = 'DPCI_DFE_NOTA_ITEM_NCM';

  if qtd = 0 then
    execute immediate q'[create index poseidon.DPCI_DFE_NOTA_ITEM_NCM on poseidon.dpc_dfe_nota_item (cod_ncm) tablespace TSD_POSEIDON]';
  end if;
end;

declare
  qtd number;
begin
  select count(*) into qtd from all_indexes
   where owner = 'POSEIDON' and index_name = 'DPCI_DFE_NOTA_COMPRADOR';

  if qtd = 0 then
    execute immediate 'create index poseidon.dpci_dfe_nota_comprador on poseidon.dpc_dfe_nota (cod_dfe_empresa, seq_comprador_erp) tablespace TSD_POSEIDON';
  end if;
end;

--  eventos de uma nota, e o religamento de orfao
declare
  qtd number;
begin
  select count(*) into qtd from all_indexes
   where owner = 'POSEIDON' and index_name = 'DPC_DFE_EVENTO_IX1';

  if qtd = 0 then
    execute immediate q'[create index poseidon.DPC_DFE_EVENTO_IX1 on poseidon.dpc_dfe_evento (cod_dfe_nota) tablespace TSD_POSEIDON]';
  end if;
end;

--  FK sem indice
declare
  qtd number;
begin
  select count(*) into qtd from all_indexes
   where owner = 'POSEIDON' and index_name = 'DPC_DFE_EVENTO_IX2';

  if qtd = 0 then
    execute immediate q'[create index poseidon.DPC_DFE_EVENTO_IX2 on poseidon.dpc_dfe_evento (cod_dfe_empresa) tablespace TSD_POSEIDON]';
  end if;
end;

--  eventos de um CT-e, e o religamento de orfao
declare
  qtd number;
begin
  select count(*) into qtd from all_indexes
   where owner = 'POSEIDON' and index_name = 'DPC_DFE_CTE_EVENTO_IX1';

  if qtd = 0 then
    execute immediate q'[create index poseidon.DPC_DFE_CTE_EVENTO_IX1 on poseidon.dpc_dfe_cte_evento (cod_dfe_cte) tablespace TSD_POSEIDON]';
  end if;
end;

--  FK sem indice
declare
  qtd number;
begin
  select count(*) into qtd from all_indexes
   where owner = 'POSEIDON' and index_name = 'DPC_DFE_CTE_EVENTO_IX2';

  if qtd = 0 then
    execute immediate q'[create index poseidon.DPC_DFE_CTE_EVENTO_IX2 on poseidon.dpc_dfe_cte_evento (cod_dfe_empresa) tablespace TSD_POSEIDON]';
  end if;
end;

--  comprovante de entrega por periodo - a consulta que motivou a tabela. Nulo na maioria das linhas (so o evento 110180 preenche), e indice Oracle NAO indexa nulo: o indice fica pequeno e serve exatamente a busca util
declare
  qtd number;
begin
  select count(*) into qtd from all_indexes
   where owner = 'POSEIDON' and index_name = 'DPCI_DFE_CTE_EVENTO_ENTR';

  if qtd = 0 then
    execute immediate q'[create index poseidon.DPCI_DFE_CTE_EVENTO_ENTR on poseidon.dpc_dfe_cte_evento (dta_entrega) tablespace TSD_POSEIDON]';
  end if;
end;

--  trilha por estabelecimento
declare
  qtd number;
begin
  select count(*) into qtd from all_indexes
   where owner = 'POSEIDON' and index_name = 'DPC_DFE_EXECUCAO_IX1';

  if qtd = 0 then
    execute immediate q'[create index poseidon.DPC_DFE_EXECUCAO_IX1 on poseidon.dpc_dfe_execucao (cod_dfe_empresa, dta_inicio) tablespace TSD_POSEIDON]';
  end if;
end;

--  trilha por fluxo. DESC porque a consulta e sempre pelo ciclo mais recente
declare
  qtd number;
begin
  select count(*) into qtd from all_indexes
   where owner = 'POSEIDON' and index_name = 'DPCI_DFE_EXECUCAO_CURSOR';

  if qtd = 0 then
    execute immediate q'[create index poseidon.DPCI_DFE_EXECUCAO_CURSOR on poseidon.dpc_dfe_execucao (cod_dfe_cursor, dta_inicio desc) tablespace TSD_POSEIDON]';
  end if;
end;

--  fila de reenvio da manifestacao
declare
  qtd number;
begin
  select count(*) into qtd from all_indexes
   where owner = 'POSEIDON' and index_name = 'DPC_DFE_MANIF_IX1';

  if qtd = 0 then
    execute immediate q'[create index poseidon.DPC_DFE_MANIF_IX1 on poseidon.dpc_dfe_manifestacao (status_envio, dta_ultima_tentativa) tablespace TSD_POSEIDON]';
  end if;
end;

--  listagem de CT-e por periodo
declare
  qtd number;
begin
  select count(*) into qtd from all_indexes
   where owner = 'POSEIDON' and index_name = 'DPCI_DFE_CTE_EMISSAO';

  if qtd = 0 then
    execute immediate q'[create index poseidon.DPCI_DFE_CTE_EMISSAO on poseidon.dpc_dfe_cte (cod_dfe_empresa, dta_emissao) tablespace TSD_POSEIDON]';
  end if;
end;

--  frete que a DPC contratou (TOMA), separado do que apenas nos cita
declare
  qtd number;
begin
  select count(*) into qtd from all_indexes
   where owner = 'POSEIDON' and index_name = 'DPCI_DFE_CTE_PAPEL';

  if qtd = 0 then
    execute immediate q'[create index poseidon.DPCI_DFE_CTE_PAPEL on poseidon.dpc_dfe_cte (sig_papel_empresa, dta_emissao) tablespace TSD_POSEIDON]';
  end if;
end;

--  caminho inverso: qual frete trouxe esta nota
declare
  qtd number;
begin
  select count(*) into qtd from all_indexes
   where owner = 'POSEIDON' and index_name = 'DPCI_DFE_CTE_NFE_CHAVE';

  if qtd = 0 then
    execute immediate q'[create index poseidon.DPCI_DFE_CTE_NFE_CHAVE on poseidon.dpc_dfe_cte_nfe (chave_nf) tablespace TSD_POSEIDON]';
  end if;
end;

--  fechamento contabil por competencia
declare
  qtd number;
begin
  select count(*) into qtd from all_indexes
   where owner = 'POSEIDON' and index_name = 'DPCI_DFE_NFSE_COMPET';

  if qtd = 0 then
    execute immediate q'[create index poseidon.DPCI_DFE_NFSE_COMPET on poseidon.dpc_dfe_nfse (cod_dfe_empresa, dta_competencia) tablespace TSD_POSEIDON]';
  end if;
end;

--  historico por prestador
declare
  qtd number;
begin
  select count(*) into qtd from all_indexes
   where owner = 'POSEIDON' and index_name = 'DPCI_DFE_NFSE_PREST';

  if qtd = 0 then
    execute immediate q'[create index poseidon.DPCI_DFE_NFSE_PREST on poseidon.dpc_dfe_nfse (num_cnpj_cpf_prest, dta_competencia) tablespace TSD_POSEIDON]';
  end if;
end;

--  cobertura do padrao nacional por municipio de incidencia
declare
  qtd number;
begin
  select count(*) into qtd from all_indexes
   where owner = 'POSEIDON' and index_name = 'DPCI_DFE_NFSE_MUNIC';

  if qtd = 0 then
    execute immediate q'[create index poseidon.DPCI_DFE_NFSE_MUNIC on poseidon.dpc_dfe_nfse (cod_municipio_incid) tablespace TSD_POSEIDON]';
  end if;
end;


-- ###########################################################################
--  6. TRIGGERS
--  PK por trigger + sequence, padrao do ecossistema DPC: a aplicacao nunca
--  seta a chave. O IF ... IS NULL preserva um valor informado de proposito -
--  necessario em carga e em correcao pontual.
--
--  CREATE OR REPLACE nao precisa de guarda: reexecutar e inofensivo.
-- ###########################################################################
create or replace trigger poseidon.dpct_dfe_empresa
  before insert on poseidon.dpc_dfe_empresa
  for each row
begin
  if :new.cod_dfe_empresa is null then
    :new.cod_dfe_empresa := poseidon.dpcs_dfe_empresa.nextval;
  end if;
end dpct_dfe_empresa;

create or replace trigger poseidon.dpct_dfe_cursor
  before insert on poseidon.dpc_dfe_cursor
  for each row
begin
  if :new.cod_dfe_cursor is null then
    :new.cod_dfe_cursor := poseidon.dpcs_dfe_cursor.nextval;
  end if;
end dpct_dfe_cursor;

create or replace trigger poseidon.dpct_dfe_emitente
  before insert on poseidon.dpc_dfe_emitente
  for each row
begin
  if :new.cod_dfe_emitente is null then
    :new.cod_dfe_emitente := poseidon.dpcs_dfe_emitente.nextval;
  end if;
end dpct_dfe_emitente;

create or replace trigger poseidon.dpct_dfe_documento
  before insert on poseidon.dpc_dfe_documento
  for each row
begin
  if :new.cod_dfe_documento is null then
    :new.cod_dfe_documento := poseidon.dpcs_dfe_documento.nextval;
  end if;
end dpct_dfe_documento;

create or replace trigger poseidon.dpct_dfe_nota
  before insert on poseidon.dpc_dfe_nota
  for each row
begin
  if :new.cod_dfe_nota is null then
    :new.cod_dfe_nota := poseidon.dpcs_dfe_nota.nextval;
  end if;
end dpct_dfe_nota;

create or replace trigger poseidon.dpct_dfe_nota_item
  before insert on poseidon.dpc_dfe_nota_item
  for each row
begin
  if :new.cod_dfe_nota_item is null then
    :new.cod_dfe_nota_item := poseidon.dpcs_dfe_nota_item.nextval;
  end if;
end dpct_dfe_nota_item;

create or replace trigger poseidon.dpct_dfe_evento
  before insert on poseidon.dpc_dfe_evento
  for each row
begin
  if :new.cod_dfe_evento is null then
    :new.cod_dfe_evento := poseidon.dpcs_dfe_evento.nextval;
  end if;
end dpct_dfe_evento;

create or replace trigger poseidon.dpct_dfe_execucao
  before insert on poseidon.dpc_dfe_execucao
  for each row
begin
  if :new.cod_dfe_execucao is null then
    :new.cod_dfe_execucao := poseidon.dpcs_dfe_execucao.nextval;
  end if;
end dpct_dfe_execucao;

create or replace trigger poseidon.dpct_dfe_manifestacao
  before insert on poseidon.dpc_dfe_manifestacao
  for each row
begin
  if :new.cod_dfe_manifestacao is null then
    :new.cod_dfe_manifestacao := poseidon.dpcs_dfe_manifestacao.nextval;
  end if;
end dpct_dfe_manifestacao;

create or replace trigger poseidon.dpct_dfe_cte
  before insert on poseidon.dpc_dfe_cte
  for each row
begin
  if :new.cod_dfe_cte is null then
    :new.cod_dfe_cte := poseidon.dpcs_dfe_cte.nextval;
  end if;
end dpct_dfe_cte;

create or replace trigger poseidon.dpct_dfe_cte_nfe
  before insert on poseidon.dpc_dfe_cte_nfe
  for each row
begin
  if :new.cod_dfe_cte_nfe is null then
    :new.cod_dfe_cte_nfe := poseidon.dpcs_dfe_cte_nfe.nextval;
  end if;
end dpct_dfe_cte_nfe;

create or replace trigger poseidon.dpct_dfe_cte_evento
  before insert on poseidon.dpc_dfe_cte_evento
  for each row
begin
  if :new.cod_dfe_cte_evento is null then
    :new.cod_dfe_cte_evento := poseidon.dpcs_dfe_cte_evento.nextval;
  end if;
end dpct_dfe_cte_evento;

create or replace trigger poseidon.dpct_dfe_nfse
  before insert on poseidon.dpc_dfe_nfse
  for each row
begin
  if :new.cod_dfe_nfse is null then
    :new.cod_dfe_nfse := poseidon.dpcs_dfe_nfse.nextval;
  end if;
end dpct_dfe_nfse;


-- ###########################################################################
--  7. COMENTARIOS
--  Obrigatorios pela convencao do projeto, e nao e burocracia: um SELECT
--  nesta base sem comentario obriga quem chega a ler codigo PHP para saber o
--  que a coluna significa.
--
--  Os textos vem dos scripts de homologacao, sem reescrita, mais os que
--  faltavam. Todas as 242 colunas das 12 tabelas estao documentadas.
-- ###########################################################################
--  ---------- DPC_DFE_EMPRESA ----------
comment on table poseidon.dpc_dfe_empresa is
  'Cursor e estado de sincronismo do NFeDistribuicaoDFe por CNPJ. Uma linha por estabelecimento monitorado';
comment on column poseidon.dpc_dfe_empresa.cod_dfe_empresa is
  'PK. Preenchida pela trigger DPCT_DFE_EMPRESA a partir da sequence DPCS_DFE_EMPRESA - a aplicacao nunca informa.';
comment on column poseidon.dpc_dfe_empresa.nro_empresa is
  'Codigo da empresa, o mesmo numero usado no ERP. NAO e lido do ERP: esta tabela e a fonte unica de identidade fiscal do modulo.';
comment on column poseidon.dpc_dfe_empresa.num_cnpj is
  'CNPJ do estabelecimento sem mascara. E o valor enviado na tag CNPJ do distDFeInt e define de quem sao os documentos retornados';
comment on column poseidon.dpc_dfe_empresa.status_manifestar is
  'N-Nao manifestar | S-Manifestar automaticamente. Default N: manifestacao e ato fiscal e exige aval da contabilidade';
comment on column poseidon.dpc_dfe_empresa.dsc_razao_social is
  'Razao social usada no configJson do sped. FONTE UNICA - o modulo nao le cadastro de empresa do ERP.';
comment on column poseidon.dpc_dfe_empresa.sig_uf is
  'UF do consulente. Vira <cUFAutor> no distDFeInt. FONTE UNICA.';
comment on column poseidon.dpc_dfe_empresa.num_inscr_estadual is
  'Inscricao estadual. Nao vai no distDFeInt, mas compoe o configJson do sped.';
comment on column poseidon.dpc_dfe_empresa.created_at is
  'Data de inclusao da linha.';
comment on column poseidon.dpc_dfe_empresa.created_by is
  'Rotina que incluiu a linha (DFE INGERIR, DFE NORMALIZAR, DFE CONCILIAR, CARGA INICIAL).';
comment on column poseidon.dpc_dfe_empresa.updated_at is
  'Data da ultima alteracao.';
comment on column poseidon.dpc_dfe_empresa.updated_by is
  'Rotina que alterou a linha por ultimo.';

--  ---------- DPC_DFE_CURSOR ----------
comment on table poseidon.dpc_dfe_cursor is
  'Estado de leitura do NSU por CNPJ e por TIPO de documento. Os tres servicos de distribuicao tem sequencias independentes para o mesmo CNPJ.';
comment on column poseidon.dpc_dfe_cursor.cod_dfe_cursor is
  'PK. Preenchida pela trigger DPCT_DFE_CURSOR - a aplicacao nunca informa.';
comment on column poseidon.dpc_dfe_cursor.cod_dfe_empresa is
  'FK para DPC_DFE_EMPRESA. A identidade fiscal e uma por CNPJ; o cursor e um por CNPJ E tipo de documento.';
comment on column poseidon.dpc_dfe_cursor.cod_tipo_dfe is
  'NFE (cobre NF-e 55 e NFC-e 65 - mesmo servico) | CTE | MDFE | NFSE (ADN Nacional, REST/mTLS). Sequencias de NSU independentes.';
comment on column poseidon.dpc_dfe_cursor.status_sincronismo is
  'A-Ativo P-Pausado (exige intervencao manual) B-Bloqueado por consumo indevido C-Certificado invalido. Somente A consulta.';
comment on column poseidon.dpc_dfe_cursor.nro_ultimo_nsu is
  'TOKEN devolvido pela SEFAZ. So pode ser CONTINUADO - valor arbitrario resulta em cStat 656 e bloqueia o certificado por 1 hora. A SEFAZ nao guarda esta posicao; ela existe somente aqui.';
comment on column poseidon.dpc_dfe_cursor.nro_maximo_nsu is
  'Ultimo NSU que a fonte declarou existir. A SEFAZ informa; o ADN NAO informa e a coluna fica em 0 - nesse caso o atraso e DESCONHECIDO, nao zero. Nunca calcular maximo-ultimo sem antes checar se maximo >= ultimo.';
comment on column poseidon.dpc_dfe_cursor.qtd_min_entre_consulta is
  'Minutos de espera entre consultas quando ha atraso a drenar. Prudencia propria: a NT 2014.002 nao fixa intervalo havendo documento.';
comment on column poseidon.dpc_dfe_cursor.qtd_min_em_dia is
  'Minutos de espera quando nao ha nada novo. Default 60 porque a NT 2014.002 EXIGE 1 hora depois de um cStat 137 - consultar antes retorna 656 e bloqueia o CNPJ.';
comment on column poseidon.dpc_dfe_cursor.dta_ultima_consulta is
  'Quando a fonte foi consultada por ultimo. Renovada mesmo em lote vazio: era essa omissao que fazia a rotina antiga disparar rajadas.';
comment on column poseidon.dpc_dfe_cursor.dta_liberado_em is
  'Quando este fluxo pode consultar de novo. Cooldown explicito em coluna, e nao recalculado em SQL, para a politica nao ficar duplicada entre PHP e banco.';
comment on column poseidon.dpc_dfe_cursor.cod_ultimo_status is
  'Ultimo codigo devolvido pela fonte. cStat na SEFAZ (137, 138, 656); StatusProcessamento no ADN.';
comment on column poseidon.dpc_dfe_cursor.dsc_ultimo_motivo is
  'Ultimo texto devolvido pela fonte, ou o motivo da pausa quando a intervencao foi manual.';
comment on column poseidon.dpc_dfe_cursor.created_at is
  'Data de inclusao da linha.';
comment on column poseidon.dpc_dfe_cursor.created_by is
  'Rotina que incluiu a linha (DFE INGERIR, DFE NORMALIZAR, DFE CONCILIAR, CARGA INICIAL).';
comment on column poseidon.dpc_dfe_cursor.updated_at is
  'Data da ultima alteracao.';
comment on column poseidon.dpc_dfe_cursor.updated_by is
  'Rotina que alterou a linha por ultimo.';

--  ---------- DPC_DFE_EMITENTE ----------
comment on table poseidon.dpc_dfe_emitente is
  'Emitente (fornecedor) das notas de entrada capturadas. Deduplicado por CNPJ/CPF';
comment on column poseidon.dpc_dfe_emitente.cod_dfe_emitente is
  'PK. Preenchida pela trigger DPCT_DFE_EMITENTE - a aplicacao nunca informa.';
comment on column poseidon.dpc_dfe_emitente.num_cnpj_cpf is
  'CNPJ ou CPF do emitente, sem mascara. Emitente pessoa fisica e possivel: nesse caso vem CPF e a inscricao estadual normalmente e ausente';
comment on column poseidon.dpc_dfe_emitente.dsc_razao_social is
  'Razao social (tag xNome). O Sefaz limita a 60 caracteres; a folga aqui evita truncamento por acentuacao em charset multibyte';
comment on column poseidon.dpc_dfe_emitente.num_inscr_estadual is
  'Inscricao estadual (tag IE). Pode ser NULL: a tag nao existe quando o emitente e CPF ou nao contribuinte';
comment on column poseidon.dpc_dfe_emitente.created_at is
  'Data de inclusao da linha.';
comment on column poseidon.dpc_dfe_emitente.created_by is
  'Rotina que incluiu a linha (DFE INGERIR, DFE NORMALIZAR, DFE CONCILIAR, CARGA INICIAL).';
comment on column poseidon.dpc_dfe_emitente.updated_at is
  'Data da ultima alteracao.';
comment on column poseidon.dpc_dfe_emitente.updated_by is
  'Rotina que alterou a linha por ultimo.';

--  ---------- DPC_DFE_DOCUMENTO ----------
comment on table poseidon.dpc_dfe_documento is
  'Documento bruto entregue pelo Sefaz (docZip do NFeDistribuicaoDFe), gravado ANTES de qualquer interpretacao. Uma linha imutavel por empresa+NSU. Serve tambem como fila de normalizacao: duravel, consultavel em SQL e reprocessavel por filtro';
comment on column poseidon.dpc_dfe_documento.cod_dfe_documento is
  'PK. Preenchida pela trigger DPCT_DFE_DOCUMENTO - a aplicacao nunca informa.';
comment on column poseidon.dpc_dfe_documento.cod_dfe_cursor is
  'Fluxo de origem (empresa + tipo). Compoe a UK com nro_nsu: NSU e sequencial POR FLUXO, nao por empresa.';
comment on column poseidon.dpc_dfe_documento.cod_dfe_empresa is
  'Empresa que consultou o Sefaz e para quem o documento foi entregue';
comment on column poseidon.dpc_dfe_documento.nro_nsu is
  'Numero Sequencial Unico atribuido pelo Sefaz. E a posicao do documento na fila DESTE CNPJ - a mesma NF-e tem NSU diferente para cada interessado';
comment on column poseidon.dpc_dfe_documento.dsc_schema is
  'Atributo schema do docZip, como veio do Sefaz (ex.: resNFe_v1.01.xsd)';
comment on column poseidon.dpc_dfe_documento.dsc_tipo_doc is
  'Primeiros 6 caracteres do schema: resNFe-resumo de NF-e | procNF-NF-e completa com protocolo | resEve-resumo de evento | procEv-evento completo';
comment on column poseidon.dpc_dfe_documento.chave_nf is
  'Chave de acesso do documento. 44 para NF-e/CT-e/MDF-e, 50 para NFS-e - por isso a coluna e VARCHAR2(50).';
comment on column poseidon.dpc_dfe_documento.bin_documento is
  'Conteudo do docZip exatamente como veio do Sefaz (gzip, ja decodificado de base64). Guardado comprimido: ~6x menor que o XML expandido em NCLOB';
comment on column poseidon.dpc_dfe_documento.status_process is
  'P-Pendente | A-Em andamento | C-Concluido | E-Erro na normalizacao (reprocessavel) | I-Ignorado (schema nao tratado)';
comment on column poseidon.dpc_dfe_documento.qtd_tentativa is
  'Numero de tentativas de normalizacao. Documento com status E e muitas tentativas indica bug de parser a corrigir';
comment on column poseidon.dpc_dfe_documento.det_erro is
  'Detalhe do erro da ultima tentativa de normalizacao';
comment on column poseidon.dpc_dfe_documento.dta_recebimento is
  'Quando o documento foi gravado aqui. Com STATUS_PROCESS, e o par que revela bruto acumulando sem normalizar - o risco real do desenho em duas etapas.';
comment on column poseidon.dpc_dfe_documento.dta_processado is
  'Quando a normalizacao concluiu. Nula enquanto pendente.';

--  ---------- DPC_DFE_NOTA ----------
comment on table poseidon.dpc_dfe_nota is
  'Nota fiscal de entrada normalizada a partir de DPC_DFE_DOCUMENTO. Uma linha por empresa+chave';
comment on column poseidon.dpc_dfe_nota.cod_dfe_nota is
  'PK. Preenchida pela trigger DPCT_DFE_NOTA - a aplicacao nunca informa.';
comment on column poseidon.dpc_dfe_nota.cod_dfe_empresa is
  'Empresa destinataria/interessada que capturou a nota. Faz parte da chave de unicidade: a mesma NF-e pode interessar a mais de um estabelecimento';
comment on column poseidon.dpc_dfe_nota.cod_dfe_emitente is
  'Emitente da nota. NULL quando o documento nao trouxe identificacao do emitente';
comment on column poseidon.dpc_dfe_nota.chave_nf is
  'Chave de acesso da NF-e, 44 digitos sem mascara. Com COD_DFE_EMPRESA forma a UK: a mesma nota pode interessar a mais de um estabelecimento.';
comment on column poseidon.dpc_dfe_nota.nro_nsu is
  'NSU do documento que originou ou atualizou esta linha por ultimo';
comment on column poseidon.dpc_dfe_nota.dsc_tipo_doc is
  'Origem do dado atual: resNFe-somente resumo | procNF-documento completo. Permite a PROMOCAO: quando o procNF chega depois do resumo, a linha e atualizada em vez de ignorada';
comment on column poseidon.dpc_dfe_nota.nro_modelo is
  'Modelo do documento: 55-NF-e, 65-NFC-e. Os dois chegam pelo mesmo fluxo NFE.';
comment on column poseidon.dpc_dfe_nota.nro_serie is
  'Serie da nota.';
comment on column poseidon.dpc_dfe_nota.nro_nf is
  'Numero da nota.';
comment on column poseidon.dpc_dfe_nota.tipo_nf is
  'Tipo da NF-e (tag tpNF): 0-entrada | 1-saida';
comment on column poseidon.dpc_dfe_nota.vlr_nota is
  'Valor total da nota (tag vNF)';
comment on column poseidon.dpc_dfe_nota.vlr_total_produto is
  'vProd do ICMSTot - soma dos produtos declarada pelo emitente. NAO e o total da nota (vlr_nota / vNF), que ainda desconta vDesc e soma frete, seguro, outros, ST e IPI. Serve para conferir contra sum(dpc_dfe_nota_item.vlr_produto): sao duas leituras independentes da MESMA grandeza. Nulo em nota que so tem resumo, porque o resNFe nao traz ICMSTot.';
comment on column poseidon.dpc_dfe_nota.dta_emissao is
  'Data de emissao, sem hora. Filtro por periodo precisa de >= :de and < :ate + 1, senao o ultimo dia se perde.';
comment on column poseidon.dpc_dfe_nota.dta_recibo is
  'Data/hora do recebimento pelo Sefaz (tag dhRecbto). Pode ser NULL em nota denegada';
comment on column poseidon.dpc_dfe_nota.nro_protocolo is
  'Numero do protocolo de autorizacao (tag nProt). Pode ser NULL no resumo';
comment on column poseidon.dpc_dfe_nota.cod_situacao is
  '1-Autorizada | 2-Denegada | 3-Cancelada. Derivado de cSitNFe (resNFe) ou de cStat (procNF: 100-autorizada, 101/151-cancelada, 205-denegada)';
comment on column poseidon.dpc_dfe_nota.dsc_situacao is
  'Texto da situacao, pronto para exibir, evitando que cada tela traduza COD_SITUACAO por conta propria.';
comment on column poseidon.dpc_dfe_nota.status_manifestacao is
  'N-Nao manifestada | C-Ciencia da operacao registrada | X-Falha ao manifestar. Sem manifestacao o Sefaz nao disponibiliza o XML completo';
comment on column poseidon.dpc_dfe_nota.sig_papel_empresa is
  'Papel da NOSSA empresa nesta NF-e: DEST destinataria, EMIT emitente, TRANSP transportadora, AUTXML citada em autXML (autorizada a baixar), OUTRO o XML completo foi lido e o CNPJ nao esta em nenhum papel conhecido, INDEF o documento nao permite saber. INDEF e OUTRO NAO sao a mesma coisa: o resNFe tem 546 bytes e so o CNPJ do emitente - sem dest, sem transp, sem autXML - entao nota que so tem resumo e INDEF, e isso e temporario (o XML completo resolve). OUTRO e definitivo. Colapsar os dois faria a tela tratar caso temporario como definitivo. Precedencia no preenchimento: dest, emit, transp, autXML - DEST vence porque o caso de uso do modulo e a nota RECEBIDA.';
comment on column poseidon.dpc_dfe_nota.status_recebimento is
  'N nao recebida no ERP | S recebida. Preenchido pelo dfe:conciliar, o UNICO ponto do modulo autorizado a ler o ERP.';
comment on column poseidon.dpc_dfe_nota.seq_nf_erp is
  'Sequencial da nota correspondente no ERP, casado pela chave de acesso de 44 digitos. E REFERENCIA para localizar a nota la, nao chave unica: a PK do lado do ERP e composta.';
comment on column poseidon.dpc_dfe_nota.dta_entrada_erp is
  'Data de entrada da nota no ERP. A diferenca entre esta data e dta_emissao e o atraso de lancamento.';
comment on column poseidon.dpc_dfe_nota.dta_conciliacao is
  'Quando a nota foi conferida contra o ERP. NULA = nunca conferida, que e diferente de conferida-e-ausente. Sem essa distincao, STATUS_RECEBIMENTO = N confunde os dois casos.';

comment on column poseidon.dpc_dfe_nota.sig_estado_erp is
  'Etapa da nota no ERP: AGUARDANDO_ENTRADA | EM_DIGITACAO | RECEBIDA | ESCRITURADA. NULO = ainda nao conciliada nenhuma vez. Preenchido pelo dfe:conciliar.';

comment on column poseidon.dpc_dfe_nota.num_estado_erp is
  'Ordinal da etapa: 0 aguardando, 1 digitada, 2 recebida, 3 escriturada. Existe para comparar ORDEM - regressao e num_estado_erp < num_estado_erp_max.';

comment on column poseidon.dpc_dfe_nota.num_estado_erp_max is
  'Maior ordinal que esta nota ja atingiu. Nunca diminui. Quando fica ACIMA do atual, a nota REGREDIU no ERP - foi desfeita uma etapa.';

comment on column poseidon.dpc_dfe_nota.dta_estado_erp is
  'Quando o estado atual foi observado pela ultima vez. Nao e quando mudou: e quando foi conferido.';

comment on column poseidon.dpc_dfe_nota.seq_notamestre_erp is
  'consinco.rf_notamestre.SEQNOTA correspondente. REFERENCIA para localizar a escrituracao, nao chave unica.';

comment on column poseidon.dpc_dfe_nota.dta_lancamento_erp is
  'Data de lancamento fiscal (rf_notamestre.DTALANCAMENTO). dta_lancamento_erp - dta_emissao e o atraso de escrituracao: mediana medida de 1 dia, maximo de 74.';

comment on column poseidon.dpc_dfe_nota.cod_cfop_erp is
  'CFOP do item de MAIOR VALOR da nota, lido de consinco.rf_notaitem quando ela chega em ESCRITURADA. Insumo da categoria - a classificacao NAO e gravada, para que mudanca nas listas de CFOP reclassifique sem reprocessar.';

comment on column poseidon.dpc_dfe_nota.dsc_ocorr_dev_erp is
  'consinco.mlf_notafiscal.OCORRENCIADEV. Nao nulo = devolucao, e vence o CFOP na classificacao. Guardado o valor, e nao um flag, para nao perder informacao.';

comment on column poseidon.dpc_dfe_nota.seq_comprador_erp is
  'Comprador responsavel pelo item de maior valor (rf_notaitem -> map_produto -> map_famdivisao nrodivisao=1 -> max_comprador). E o que a tela FILTRA.';

comment on column poseidon.dpc_dfe_nota.dsc_comprador_erp is
  'Nome do comprador, para exibicao. Denormalizado de proposito: aqui e rotulo, nao chave - o vinculo e o seq_comprador_erp.';
comment on column poseidon.dpc_dfe_nota.created_at is
  'Data de inclusao da linha.';
comment on column poseidon.dpc_dfe_nota.created_by is
  'Rotina que incluiu a linha (DFE INGERIR, DFE NORMALIZAR, DFE CONCILIAR, CARGA INICIAL).';
comment on column poseidon.dpc_dfe_nota.updated_at is
  'Data da ultima alteracao.';
comment on column poseidon.dpc_dfe_nota.updated_by is
  'Rotina que alterou a linha por ultimo.';

--  ---------- DPC_DFE_NOTA_ITEM ----------
comment on table poseidon.dpc_dfe_nota_item is
  'Itens da NF-e, um por tag det do procNFe. Extraidos do XML JA GRAVADO em dpc_dfe_documento, na normalizacao - a ingestao nao interpreta conteudo. O resNFe nao tem itens: e o resumo, nao a nota, e por isso uma nota pode existir sem nenhuma linha aqui.';
comment on column poseidon.dpc_dfe_nota_item.cod_dfe_nota_item is
  'PK. Preenchida pela trigger DPCT_DFE_NOTA_ITEM - a aplicacao nunca informa.';
comment on column poseidon.dpc_dfe_nota_item.cod_dfe_nota is
  'FK para DPC_DFE_NOTA. Com NRO_ITEM forma a UK: reprocessar o mesmo bruto nao duplica item.';
comment on column poseidon.dpc_dfe_nota_item.nro_item is
  'Atributo nItem da tag det. Numeracao do proprio emitente, comeca em 1.';
comment on column poseidon.dpc_dfe_nota_item.cod_produto is
  'cProd - codigo do produto no cadastro do FORNECEDOR, nao no nosso. Nao serve de chave para o ERP.';
comment on column poseidon.dpc_dfe_nota_item.cod_ean is
  'cEAN - codigo de barras. E TEXTO, nunca numero: vem a string SEM GTIN quando o produto nao tem codigo, e tratar como numerico zeraria o campo.';
comment on column poseidon.dpc_dfe_nota_item.dsc_produto is
  'xProd - descricao do produto como o fornecedor a escreveu.';
comment on column poseidon.dpc_dfe_nota_item.cod_ncm is
  'NCM - classificacao fiscal da mercadoria, 8 digitos. E o filtro analitico mais usado, e tem indice proprio.';
comment on column poseidon.dpc_dfe_nota_item.cod_cest is
  'CEST - codigo especificador da substituicao tributaria. Nulo quando o produto nao esta sujeito a ST.';
comment on column poseidon.dpc_dfe_nota_item.cod_ex_tipi is
  'EXTIPI - excecao a TIPI, quando houver.';
comment on column poseidon.dpc_dfe_nota_item.cod_cfop is
  'CFOP da operacao no item. Pode diferir entre itens da mesma nota.';
comment on column poseidon.dpc_dfe_nota_item.cod_beneficio is
  'cBenef - codigo de beneficio fiscal na UF, quando aplicavel.';
comment on column poseidon.dpc_dfe_nota_item.sig_unid_com is
  'uCom - unidade COMERCIAL, a que o fornecedor fatura. Pode ser diferente da tributavel: um item chegou com uCom UNIDAD e uTrib UN.';
comment on column poseidon.dpc_dfe_nota_item.qtd_comercial is
  'qCom - quantidade na unidade comercial.';
comment on column poseidon.dpc_dfe_nota_item.vlr_unit_com is
  'vUnCom - valor unitario comercial. O layout admite ATE 10 DECIMAIS, e o dado real usa: 6.4580725910. Arredondar na leitura distorce a conferencia de total.';
comment on column poseidon.dpc_dfe_nota_item.vlr_produto is
  'vProd - valor bruto do item (quantidade x unitario), antes de desconto e acessorios.';
comment on column poseidon.dpc_dfe_nota_item.sig_unid_trib is
  'uTrib - unidade TRIBUTAVEL, a que a tributacao considera.';
comment on column poseidon.dpc_dfe_nota_item.qtd_tributavel is
  'qTrib - quantidade na unidade tributavel.';
comment on column poseidon.dpc_dfe_nota_item.vlr_unit_trib is
  'vUnTrib - valor unitario na unidade tributavel.';
comment on column poseidon.dpc_dfe_nota_item.vlr_frete is
  'vFrete rateado no item, quando o emitente informa por item.';
comment on column poseidon.dpc_dfe_nota_item.vlr_seguro is
  'vSeg rateado no item.';
comment on column poseidon.dpc_dfe_nota_item.vlr_desconto is
  'vDesc do item.';
comment on column poseidon.dpc_dfe_nota_item.vlr_outros is
  'vOutro - outras despesas acessorias do item.';
comment on column poseidon.dpc_dfe_nota_item.status_compoe_total is
  'indTot - 1 quando o vProd deste item ENTRA no total da nota, 0 quando nao. Somar vlr_produto sem filtrar por 1 pode nao fechar com dpc_dfe_nota.vlr_nota.';
comment on column poseidon.dpc_dfe_nota_item.vlr_item is
  'vItem - valor do item, irmao da tag prod e nao filho dela. Presente em 825 dos 833 itens do acervo capturado.';
comment on column poseidon.dpc_dfe_nota_item.dsc_inf_adic is
  'infAdProd - texto livre do emitente sobre o item. Costuma trazer tributo aproximado (IBPT).';
comment on column poseidon.dpc_dfe_nota_item.cod_cst_icms is
  'CST do ICMS, ou CSOSN quando o emitente e do Simples Nacional - o XML usa tags diferentes (CST em ICMS00/40/60, CSOSN em ICMSSN*) para o mesmo papel, e esta coluna guarda o que vier. CSOSN tem 3 digitos, dai o tamanho 4.';
comment on column poseidon.dpc_dfe_nota_item.cod_origem is
  'orig - origem da mercadoria: 0 nacional, 1 importada direta, 2 importada adquirida no mercado interno, 3 a 8 demais casos.';
comment on column poseidon.dpc_dfe_nota_item.vlr_bc_icms is
  'vBC do ICMS. NULO em ICMS60 (substituicao ja recolhida), que nao tem base propria - nesse caso olhar as colunas de ST.';
comment on column poseidon.dpc_dfe_nota_item.pct_icms is
  'pICMS - aliquota aplicada.';
comment on column poseidon.dpc_dfe_nota_item.vlr_icms is
  'vICMS - imposto do item. Nulo quando o CST nao gera ICMS proprio.';
comment on column poseidon.dpc_dfe_nota_item.vlr_bc_icms_st is
  'Base do ICMS-ST. Guarda vBCST (retido AGORA, ICMS10/70) ou vBCSTRet (retido ANTES, ICMS60) - sao o mesmo fato para quem consulta, e o XML usa nomes diferentes.';
comment on column poseidon.dpc_dfe_nota_item.vlr_icms_st is
  'ICMS-ST do item. Guarda vICMSST ou vICMSSTRet, pela mesma razao da coluna de base.';
comment on column poseidon.dpc_dfe_nota_item.cod_cst_ipi is
  'CST do IPI. Nulo quando o item nao traz o grupo.';
comment on column poseidon.dpc_dfe_nota_item.vlr_bc_ipi is
  'vBC do IPI.';
comment on column poseidon.dpc_dfe_nota_item.pct_ipi is
  'pIPI - aliquota.';
comment on column poseidon.dpc_dfe_nota_item.vlr_ipi is
  'vIPI do item.';
comment on column poseidon.dpc_dfe_nota_item.cod_cst_pis is
  'CST do PIS. 04 e 06 sao nao tributados - a maioria do acervo capturado.';
comment on column poseidon.dpc_dfe_nota_item.vlr_bc_pis is
  'vBC do PIS. Nulo quando o CST nao tributa.';
comment on column poseidon.dpc_dfe_nota_item.pct_pis is
  'pPIS - aliquota.';
comment on column poseidon.dpc_dfe_nota_item.vlr_pis is
  'vPIS do item.';
comment on column poseidon.dpc_dfe_nota_item.cod_cst_cofins is
  'CST da COFINS.';
comment on column poseidon.dpc_dfe_nota_item.vlr_bc_cofins is
  'vBC da COFINS.';
comment on column poseidon.dpc_dfe_nota_item.pct_cofins is
  'pCOFINS - aliquota.';
comment on column poseidon.dpc_dfe_nota_item.vlr_cofins is
  'vCOFINS do item.';
comment on column poseidon.dpc_dfe_nota_item.cod_cst_ibscbs is
  'CST do grupo IBSCBS - a reforma tributaria. NAO e novidade distante: 826 dos 833 itens do acervo capturado ja trazem este campo preenchido.';
comment on column poseidon.dpc_dfe_nota_item.cod_class_trib is
  'cClassTrib - classificacao tributaria do IBS/CBS.';
comment on column poseidon.dpc_dfe_nota_item.vlr_bc_ibscbs is
  'vBC do grupo IBSCBS. E base PROPRIA do grupo, diferente do vBC do ICMS - dai coluna separada em vez de reaproveitar vlr_bc_icms.';
comment on column poseidon.dpc_dfe_nota_item.vlr_ibs is
  'vIBS do item - soma da parcela estadual (gIBSUF) e municipal (gIBSMun).';
comment on column poseidon.dpc_dfe_nota_item.vlr_cbs is
  'vCBS do item.';
comment on column poseidon.dpc_dfe_nota_item.created_at is
  'Data de inclusao da linha.';
comment on column poseidon.dpc_dfe_nota_item.created_by is
  'Rotina que incluiu a linha (DFE NORMALIZAR).';

--  ---------- DPC_DFE_EVENTO ----------
comment on table poseidon.dpc_dfe_evento is
  'Eventos de NF-e recebidos pelo NFeDistribuicaoDFe (cancelamento, ciencia, confirmacao, CC-e). Aceita evento ORFAO - ver cod_dfe_nota';
comment on column poseidon.dpc_dfe_evento.cod_dfe_evento is
  'PK. Preenchida pela trigger DPCT_DFE_EVENTO - a aplicacao nunca informa.';
comment on column poseidon.dpc_dfe_evento.cod_dfe_empresa is
  'FK para DPC_DFE_EMPRESA: o estabelecimento a quem a fonte entregou o evento.';
comment on column poseidon.dpc_dfe_evento.cod_dfe_nota is
  'Nota a que o evento pertence. NULL quando o evento chegou ANTES da nota (evento orfao). Guardar o orfao em vez de descartar e o que evita perda definitiva: o Sefaz retem os documentos por apenas 90 dias';
comment on column poseidon.dpc_dfe_evento.chave_nf is
  'Chave da NF-e do evento. Sempre preenchida - e por ela que o orfao e religado a nota quando ela aparecer';
comment on column poseidon.dpc_dfe_evento.nro_nsu is
  'NSU do documento que originou este evento';
comment on column poseidon.dpc_dfe_evento.cod_tipo_evento is
  'Codigo do evento (tag tpEvento): 110111-cancelamento | 110110-CC-e | 210200-confirmacao | 210210-ciencia | 210220-desconhecimento | 210240-operacao nao realizada';
comment on column poseidon.dpc_dfe_evento.dsc_evento is
  'Descricao do evento conforme o layout (xEvento).';
comment on column poseidon.dpc_dfe_evento.nro_seq_evento is
  'Sequencia do evento (tag nSeqEvento). Faz parte da chave de unicidade: o mesmo tipo de evento pode ocorrer mais de uma vez na mesma nota';
comment on column poseidon.dpc_dfe_evento.nro_protocolo is
  'Protocolo do registro do evento (tag nProt). Ausente no resumo de evento (resEve), por isso NAO integra a chave de unicidade';
comment on column poseidon.dpc_dfe_evento.cod_status is
  'cStat do processamento do evento. Presente somente em procEventoNFe';
comment on column poseidon.dpc_dfe_evento.dsc_motivo is
  'Texto do retorno do evento (xMotivo). Nulo em evento de MDF-e, que nao traz o par status/motivo.';
comment on column poseidon.dpc_dfe_evento.dta_evento is
  'Data e hora do evento, do proprio documento.';
comment on column poseidon.dpc_dfe_evento.created_at is
  'Data de inclusao da linha.';
comment on column poseidon.dpc_dfe_evento.created_by is
  'Rotina que incluiu a linha (DFE INGERIR, DFE NORMALIZAR, DFE CONCILIAR, CARGA INICIAL).';

--  ---------- DPC_DFE_EXECUCAO ----------
comment on table poseidon.dpc_dfe_execucao is
  'Trilha de execucao da rotina de sincronismo: uma linha por empresa por ciclo. E a fonte do monitoramento e do diagnostico de bloqueio';
comment on column poseidon.dpc_dfe_execucao.cod_dfe_execucao is
  'PK. Preenchida pela trigger DPCT_DFE_EXECUCAO - a aplicacao nunca informa.';
comment on column poseidon.dpc_dfe_execucao.cod_dfe_cursor is
  'Fluxo (empresa + tipo) que originou o ciclo. Necessario para ultimoNsuRecebido: o ultNSU de um fluxo NAO vale para outro, e usar o errado gera cStat 656.';
comment on column poseidon.dpc_dfe_execucao.cod_dfe_empresa is
  'FK para DPC_DFE_EMPRESA. Redundante com o cursor, e mantida de proposito: permite somar por estabelecimento sem juntar com DPC_DFE_CURSOR.';
comment on column poseidon.dpc_dfe_execucao.dta_inicio is
  'Inicio do ciclo. Com COD_DFE_CURSOR e o par de leitura da trilha - o indice DPCI_DFE_EXECUCAO_CURSOR e DESC porque a consulta e sempre pelo mais recente.';
comment on column poseidon.dpc_dfe_execucao.dta_fim is
  'NULL indica execucao interrompida sem fechamento (queda de processo) - deve ser investigado';
comment on column poseidon.dpc_dfe_execucao.nro_nsu_inicial is
  'Cursor no inicio do ciclo';
comment on column poseidon.dpc_dfe_execucao.nro_nsu_final is
  'Cursor no fim do ciclo. Igual ao inicial significa que nada avancou';
comment on column poseidon.dpc_dfe_execucao.qtd_consulta is
  'Quantidade de chamadas distNSU feitas ao Sefaz neste ciclo';
comment on column poseidon.dpc_dfe_execucao.qtd_documento is
  'Documentos brutos gravados neste ciclo (o Sefaz entrega no maximo 50 por chamada)';
comment on column poseidon.dpc_dfe_execucao.qtd_nota is
  'Notas gravadas ou atualizadas no ciclo.';
comment on column poseidon.dpc_dfe_execucao.qtd_evento is
  'Eventos gravados no ciclo.';
comment on column poseidon.dpc_dfe_execucao.qtd_erro is
  'Documentos que falharam no ciclo. Continuam reprocessaveis: falha aqui nao perde documento.';
comment on column poseidon.dpc_dfe_execucao.cod_resultado is
  'EM_DIA-cursor alcancou o maximo | ORCAMENTO-limite de chamadas do ciclo | CURSOR_TRAVADO-Sefaz nao avancou o ultNSU, empresa pausada | CONSUMO_INDEVIDO-cStat 656, bloqueio de 1h | AGUARDANDO-ainda em cooldown | ERRO_SEFAZ | ERRO_BD | CERT_INVALIDO';
comment on column poseidon.dpc_dfe_execucao.dsc_resultado is
  'Mensagem detalhada do resultado, incluindo xMotivo do Sefaz quando houver';
comment on column poseidon.dpc_dfe_execucao.created_by is
  'Rotina que incluiu a linha (DFE INGERIR, DFE NORMALIZAR, DFE CONCILIAR, CARGA INICIAL).';

--  ---------- DPC_DFE_MANIFESTACAO ----------
comment on table poseidon.dpc_dfe_manifestacao is
  'Controle da manifestacao do destinatario enviada ao Sefaz. ATENCAO: manifestar e ato fiscal com efeito juridico - a rotina nasce DESLIGADA e exige a flag --confirmar';
comment on column poseidon.dpc_dfe_manifestacao.cod_dfe_manifestacao is
  'PK. Preenchida pela trigger DPCT_DFE_MANIFESTACAO - a aplicacao nunca informa.';
comment on column poseidon.dpc_dfe_manifestacao.cod_dfe_nota is
  'FK para DPC_DFE_NOTA. Com COD_TIPO_EVENTO forma a UK que IMPEDE manifestar em duplicidade - manifestacao e ato fiscal com efeito juridico, e o banco e a ultima barreira.';
comment on column poseidon.dpc_dfe_manifestacao.cod_tipo_evento is
  '210200-Confirmacao da operacao | 210210-Ciencia da operacao | 210220-Desconhecimento | 210240-Operacao nao realizada. A Ciencia (210210) e a que libera o XML completo sem afirmar nada sobre a operacao';
comment on column poseidon.dpc_dfe_manifestacao.status_envio is
  'P-Pendente | E-Enviado com sucesso | F-Falha';
comment on column poseidon.dpc_dfe_manifestacao.cod_status_retorno is
  'cStat devolvido pelo Sefaz. 135 indica evento registrado com sucesso';
comment on column poseidon.dpc_dfe_manifestacao.dsc_status_retorno is
  'Texto do retorno da SEFAZ.';
comment on column poseidon.dpc_dfe_manifestacao.nro_protocolo is
  'Protocolo do evento de manifestacao, quando aceito.';
comment on column poseidon.dpc_dfe_manifestacao.qtd_tentativa is
  'Tentativas de envio. A chave unica por nota+evento impede manifestar em duplicidade, que e o risco juridico desta rotina';
comment on column poseidon.dpc_dfe_manifestacao.det_erro is
  'Detalhe da falha, para diagnostico sem precisar reproduzir.';
comment on column poseidon.dpc_dfe_manifestacao.xml_retorno is
  'Envelope de retorno do Sefaz, guardado para auditoria fiscal';
comment on column poseidon.dpc_dfe_manifestacao.dta_envio is
  'Quando o evento foi aceito pela SEFAZ.';
comment on column poseidon.dpc_dfe_manifestacao.dta_ultima_tentativa is
  'Quando foi tentado por ultimo. Com STATUS_ENVIO alimenta o indice DPC_DFE_MANIF_IX1, que e a fila de reenvio.';
comment on column poseidon.dpc_dfe_manifestacao.dta_atualizacao is
  'Ultima alteracao da linha.';
comment on column poseidon.dpc_dfe_manifestacao.created_at is
  'Data de inclusao da linha.';
comment on column poseidon.dpc_dfe_manifestacao.created_by is
  'Rotina que incluiu a linha (DFE INGERIR, DFE NORMALIZAR, DFE CONCILIAR, CARGA INICIAL).';

--  ---------- DPC_DFE_CTE ----------
comment on table poseidon.dpc_dfe_cte is
  'CT-e normalizado, um por empresa+chave. Separado de dpc_dfe_nota porque o CT-e tem cinco papeis (emitente/remetente/expedidor/recebedor/destinatario) mais o tomador, e valor de PRESTACAO em vez de valor de mercadoria.';
comment on column poseidon.dpc_dfe_cte.cod_dfe_cte is
  'PK. Preenchida pela trigger DPCT_DFE_CTE - a aplicacao nunca informa.';
comment on column poseidon.dpc_dfe_cte.cod_dfe_empresa is
  'FK para DPC_DFE_EMPRESA: o estabelecimento a quem a SEFAZ entregou o CT-e.';
comment on column poseidon.dpc_dfe_cte.chave_cte is
  'Chave de acesso do CT-e, 44 digitos sem mascara.';
comment on column poseidon.dpc_dfe_cte.nro_nsu is
  'NSU que gerou ou atualizou esta linha.';
comment on column poseidon.dpc_dfe_cte.dsc_tipo_doc is
  'resCTe = so o resumo chegou; procCTe = XML completo. So o procCTe traz as chaves das notas transportadas.';
comment on column poseidon.dpc_dfe_cte.nro_modelo is
  '57-CT-e, 67-CT-e OS.';
comment on column poseidon.dpc_dfe_cte.nro_serie is
  'Serie do CT-e.';
comment on column poseidon.dpc_dfe_cte.nro_cte is
  'Numero do CT-e.';
comment on column poseidon.dpc_dfe_cte.dta_emissao is
  'Data de emissao, sem hora.';
comment on column poseidon.dpc_dfe_cte.cod_cfop is
  'CFOP da prestacao.';
comment on column poseidon.dpc_dfe_cte.dsc_natureza_oper is
  'Natureza da operacao declarada.';
comment on column poseidon.dpc_dfe_cte.cod_modal is
  '01-Rodoviario 02-Aereo 03-Aquaviario 04-Ferroviario 05-Dutoviario 06-Multimodal.';
comment on column poseidon.dpc_dfe_cte.cod_tipo_servico is
  '0-Normal 1-Subcontratacao 2-Redespacho 3-Redespacho intermediario 4-Vinculado a multimodal.';
comment on column poseidon.dpc_dfe_cte.cod_tipo_cte is
  '0-Normal 1-Complemento de valor 2-Anulacao 3-Substituto.';
comment on column poseidon.dpc_dfe_cte.dsc_municipio_ini is
  'Municipio de inicio da prestacao.';
comment on column poseidon.dpc_dfe_cte.sig_uf_ini is
  'UF de inicio da prestacao.';
comment on column poseidon.dpc_dfe_cte.dsc_municipio_fim is
  'Municipio de fim da prestacao.';
comment on column poseidon.dpc_dfe_cte.sig_uf_fim is
  'UF de fim da prestacao.';
comment on column poseidon.dpc_dfe_cte.num_cnpj_emitente is
  'CNPJ da transportadora, sem mascara.';
comment on column poseidon.dpc_dfe_cte.dsc_razao_emitente is
  'Razao social da transportadora. Guardada aqui, e nao em DPC_DFE_EMITENTE, porque transportadora nao e fornecedora de mercadoria - misturar as duas tornaria aquela tabela ambigua.';
comment on column poseidon.dpc_dfe_cte.num_cnpj_remetente is
  'CNPJ do remetente. Nulo no resumo: so o procCTe traz as partes.';
comment on column poseidon.dpc_dfe_cte.num_cnpj_expedidor is
  'CNPJ do expedidor. Nulo no resumo.';
comment on column poseidon.dpc_dfe_cte.num_cnpj_recebedor is
  'CNPJ do recebedor. Nulo no resumo.';
comment on column poseidon.dpc_dfe_cte.num_cnpj_destinat is
  'CNPJ do destinatario. Nulo no resumo.';
comment on column poseidon.dpc_dfe_cte.cod_tomador is
  'Tag toma do CT-e: 0-Remetente 1-Expedidor 2-Recebedor 3-Destinatario 4-Outros. Quem PAGA o frete.';
comment on column poseidon.dpc_dfe_cte.sig_papel_empresa is
  'Papel da NOSSA empresa neste CT-e: REM, EXPED, RECEB, DEST, TOMA ou OUTRO. O CTeDistribuicaoDFe entrega todo CT-e em que o CNPJ apareca em qualquer papel; sem esta coluna nao ha como separar frete contratado por nos de frete de terceiro em que apenas aparecemos.';
comment on column poseidon.dpc_dfe_cte.vlr_prestacao is
  'vTPrest - valor total da prestacao do servico de transporte. NAO e valor de mercadoria.';
comment on column poseidon.dpc_dfe_cte.vlr_receber is
  'Valor a receber pela prestacao.';
comment on column poseidon.dpc_dfe_cte.nro_protocolo is
  'Protocolo de autorizacao.';
comment on column poseidon.dpc_dfe_cte.cod_situacao is
  '1-Autorizado 3-Cancelado.';
comment on column poseidon.dpc_dfe_cte.dsc_situacao is
  'Texto da situacao, pronto para exibir.';
comment on column poseidon.dpc_dfe_cte.created_at is
  'Data de inclusao da linha.';
comment on column poseidon.dpc_dfe_cte.created_by is
  'Rotina que incluiu a linha (DFE INGERIR, DFE NORMALIZAR, DFE CONCILIAR, CARGA INICIAL).';
comment on column poseidon.dpc_dfe_cte.updated_at is
  'Data da ultima alteracao.';
comment on column poseidon.dpc_dfe_cte.updated_by is
  'Rotina que alterou a linha por ultimo.';

--  ---------- DPC_DFE_CTE_NFE ----------
comment on table poseidon.dpc_dfe_cte_nfe is
  'NF-e transportadas por um CT-e (infCTeNorm/infDoc/infNFe). Liga o acervo de CT-e ao de NF-e pela chave de acesso.';
comment on column poseidon.dpc_dfe_cte_nfe.cod_dfe_cte_nfe is
  'PK. Preenchida pela trigger DPCT_DFE_CTE_NFE - a aplicacao nunca informa.';
comment on column poseidon.dpc_dfe_cte_nfe.cod_dfe_cte is
  'FK para DPC_DFE_CTE.';
comment on column poseidon.dpc_dfe_cte_nfe.chave_nf is
  'Chave da NF-e transportada, 44 digitos. Pode nao existir em DPC_DFE_NOTA: nota de terceiro, ou emitida fora da janela de retencao. A juncao e sempre LEFT JOIN.';
comment on column poseidon.dpc_dfe_cte_nfe.created_at is
  'Data de inclusao da linha.';
comment on column poseidon.dpc_dfe_cte_nfe.created_by is
  'Rotina que incluiu a linha (DFE INGERIR, DFE NORMALIZAR, DFE CONCILIAR, CARGA INICIAL).';

--  ---------- DPC_DFE_CTE_EVENTO ----------
comment on table poseidon.dpc_dfe_cte_evento is
  'Eventos de CT-e recebidos pelo CTeDistribuicaoDFe. Tabela SEPARADA da de eventos de NF-e porque a chave e a FK apontam para outro documento (chave_cte / dpc_dfe_cte) - reaproveitar dpc_dfe_evento obrigaria a guardar chave de CT-e numa coluna chamada chave_nf, com a FK para a nota sempre nula. Aceita evento ORFAO: cod_dfe_cte nulo enquanto o CT-e nao chegou.';
comment on column poseidon.dpc_dfe_cte_evento.cod_dfe_cte_evento is
  'PK, autoincremento pela trigger DPCT_DFE_CTE_EVENTO. A aplicacao NUNCA seta este valor';
comment on column poseidon.dpc_dfe_cte_evento.cod_dfe_empresa is
  'Estabelecimento por cuja consulta o evento chegou. Nao e o autor do evento - para isso ha num_cnpj_autor';
comment on column poseidon.dpc_dfe_cte_evento.cod_dfe_cte is
  'CT-e a que o evento pertence. NULO quando o evento chegou ANTES do CT-e - situacao normal, e nao erro: o religamento acontece quando o documento aparecer. Descartar orfao seria perda definitiva, porque a SEFAZ retem por 90 dias';
comment on column poseidon.dpc_dfe_cte_evento.chave_cte is
  'Chave do CT-e (tag chCTe). E o que permite religar o evento orfao depois, e por isso e NOT NULL mesmo quando cod_dfe_cte e nulo';
comment on column poseidon.dpc_dfe_cte_evento.nro_nsu is
  'NSU que trouxe este evento. Serve para rastrear de qual chamada ele veio, na trilha de dpc_dfe_execucao';
comment on column poseidon.dpc_dfe_cte_evento.cod_tipo_evento is
  'tpEvento. Medidos nesta base: 110180 Comprovante de Entrega, 110181 Cancelamento do Comprovante, 110111 Cancelamento do CT-e, 110110 Carta de Correcao, 310610 MDF-e Autorizado';
comment on column poseidon.dpc_dfe_cte_evento.dsc_evento is
  'descEvento do detEvento, ou xEvento do retorno. Texto da SEFAZ, guardado como veio';
comment on column poseidon.dpc_dfe_cte_evento.nro_seq_evento is
  'nSeqEvento. Compoe a UK com chave_cte e cod_tipo_evento: e o que torna a gravacao idempotente. Vem as vezes com zeros a esquerda (001) e por isso e convertido para inteiro';
comment on column poseidon.dpc_dfe_cte_evento.nro_protocolo is
  'nProt do retEventoCTe - protocolo de registro do EVENTO na SEFAZ, nao o do CT-e';
comment on column poseidon.dpc_dfe_cte_evento.cod_status is
  'cStat do retEventoCTe. 135 e o normal: evento registrado e vinculado ao CT-e';
comment on column poseidon.dpc_dfe_cte_evento.dsc_motivo is
  'xMotivo do retEventoCTe, correspondente ao cod_status';
comment on column poseidon.dpc_dfe_cte_evento.dta_evento is
  'dhEvento - quando o evento ocorreu, na origem. Chega com fuso variavel no XML (vimos -03:00 e -04:00 na mesma base)';
comment on column poseidon.dpc_dfe_cte_evento.num_cnpj_autor is
  'CNPJ de quem emitiu o EVENTO, que nao e necessariamente o emitente do CT-e. No comprovante de entrega e a transportadora; no MDF-e Autorizado pode ser outro transportador da mesma carga';
comment on column poseidon.dpc_dfe_cte_evento.dta_entrega is
  'dhEntrega do evCECTe - quando a mercadoria foi entregue. So no evento 110180. E a prova eletronica de entrega: serve em auditoria de frete e em disputa de mercadoria faltante';
comment on column poseidon.dpc_dfe_cte_evento.num_doc_recebedor is
  'nDoc do evCECTe - documento de quem recebeu. Chega MASCARADO em parte dos eventos (literalmente ".."), entao pode ser inutil mesmo quando presente';
comment on column poseidon.dpc_dfe_cte_evento.dsc_nome_recebedor is
  'xNome do evCECTe - nome de quem recebeu. Mesma ressalva do nDoc: vem mascarado com frequencia';
comment on column poseidon.dpc_dfe_cte_evento.dsc_hash_entrega is
  'hashEntrega do evCECTe - hash da imagem do comprovante. Nao guardamos a imagem, so o hash';
comment on column poseidon.dpc_dfe_cte_evento.chave_mdfe is
  'chMDFe do evCTeAutorizadoMDFe. So no evento 310610, e diz em qual manifesto este CT-e viajou - ou seja, que a carga saiu';
comment on column poseidon.dpc_dfe_cte_evento.created_at is
  'Quando a linha foi gravada aqui. Diferente de dta_evento (quando o evento ocorreu na origem) e de dta_entrega';
comment on column poseidon.dpc_dfe_cte_evento.created_by is
  'Quem gravou. DFE NORMALIZAR para o fluxo automatico';

--  ---------- DPC_DFE_NFSE ----------
comment on table poseidon.dpc_dfe_nfse is
  'NFS-e normalizada, capturada do ADN Nacional. Diferente de dpc_dfe_nota, NAO tem conciliacao com o ERP: a DPC nao registra NFS-e recebida em lugar nenhum do ERP, entao esta tabela E o registro, nao uma copia.';
comment on column poseidon.dpc_dfe_nfse.cod_dfe_nfse is
  'PK. Preenchida pela trigger DPCT_DFE_NFSE - a aplicacao nunca informa.';
comment on column poseidon.dpc_dfe_nfse.cod_dfe_empresa is
  'FK para DPC_DFE_EMPRESA: o estabelecimento a quem o ADN entregou a NFS-e.';
comment on column poseidon.dpc_dfe_nfse.chave_nfse is
  'Chave de acesso da NFS-e: 50 caracteres (nao 44 como NF-e/CT-e). Vem do atributo Id de infNFSe com o prefixo NFS.';
comment on column poseidon.dpc_dfe_nfse.nro_nsu is
  'NSU do ADN que gerou esta linha.';
comment on column poseidon.dpc_dfe_nfse.dsc_tipo_doc is
  'adnNFSe ou adnDPS. O prefixo adn existe para o TipoDocumento do ADN nao colidir com o vocabulario de evento da NF-e no mesmo campo.';
comment on column poseidon.dpc_dfe_nfse.nro_nfse is
  'Numero da NFS-e. VARCHAR2 porque a numeracao e municipal e nao ha garantia de ser numerica.';
comment on column poseidon.dpc_dfe_nfse.dta_processamento is
  'Quando o ADN processou o documento. NAO serve de filtro contabil: pode ser meses depois da competencia.';
comment on column poseidon.dpc_dfe_nfse.dta_competencia is
  'Mes de competencia do servico. E o filtro que a contabilidade usa.';
comment on column poseidon.dpc_dfe_nfse.cod_situacao is
  '1-Autorizada 3-Cancelada.';
comment on column poseidon.dpc_dfe_nfse.dsc_situacao is
  'Texto da situacao, pronto para exibir.';
comment on column poseidon.dpc_dfe_nfse.sig_papel_empresa is
  'PREST (nossa empresa prestou), TOMA (contratou), INTERM ou OUTRO. O ADN entrega documento em que o CNPJ do certificado apareca em qualquer um desses papeis.';
comment on column poseidon.dpc_dfe_nfse.num_cnpj_cpf_prest is
  'CNPJ ou CPF do prestador, sem mascara. Pode ser CPF: prestador autonomo emite NFS-e.';
comment on column poseidon.dpc_dfe_nfse.dsc_razao_prest is
  'Razao social ou nome do prestador.';
comment on column poseidon.dpc_dfe_nfse.num_insc_munic_prest is
  'Inscricao municipal do prestador.';
comment on column poseidon.dpc_dfe_nfse.cod_municipio_prest is
  'Codigo IBGE do municipio do prestador. Nem sempre igual ao de incidencia do ISSQN.';
comment on column poseidon.dpc_dfe_nfse.sig_uf_prest is
  'UF do prestador.';
comment on column poseidon.dpc_dfe_nfse.num_cnpj_cpf_toma is
  'CNPJ ou CPF do tomador, sem mascara.';
comment on column poseidon.dpc_dfe_nfse.dsc_razao_toma is
  'Razao social ou nome do tomador.';
comment on column poseidon.dpc_dfe_nfse.cod_municipio_incid is
  'Codigo IBGE do municipio de incidencia do ISSQN, que nem sempre e o do prestador. E a coluna que mede a cobertura do padrao nacional por municipio.';
comment on column poseidon.dpc_dfe_nfse.dsc_municipio_incid is
  'Nome do municipio de incidencia, pronto para exibir. Agrupamento e relatorio devem usar COD_MUNICIPIO_INCID: a grafia do nome e digitada por quem emite, e o mesmo codigo chega em caixas diferentes.';
comment on column poseidon.dpc_dfe_nfse.cod_trib_nacional is
  'cTribNac - item da lista nacional de servicos. Ex.: 100901 = representacao de qualquer natureza.';
comment on column poseidon.dpc_dfe_nfse.cod_trib_municipal is
  'Codigo de tributacao do proprio municipio (cTribMun).';
comment on column poseidon.dpc_dfe_nfse.dsc_servico is
  'Descricao livre do servico prestado (xDescServ).';
comment on column poseidon.dpc_dfe_nfse.vlr_servico is
  'Valor bruto da prestacao (vServ). Diferente de VLR_LIQUIDO: sao dois blocos de valor no documento, e a tela precisa mostrar bruto, retencoes e liquido para fechar com o pagamento.';
comment on column poseidon.dpc_dfe_nfse.vlr_base_calculo is
  'Base de calculo do ISSQN.';
comment on column poseidon.dpc_dfe_nfse.pct_aliquota is
  'Aliquota de ISSQN aplicada.';
comment on column poseidon.dpc_dfe_nfse.vlr_issqn is
  'ISSQN apurado.';
comment on column poseidon.dpc_dfe_nfse.vlr_retido is
  'vTotalRet - total retido. Importa para contas a pagar: o liquido difere do valor do servico.';
comment on column poseidon.dpc_dfe_nfse.vlr_liquido is
  'Valor liquido a pagar, apos retencoes.';
comment on column poseidon.dpc_dfe_nfse.created_at is
  'Data de inclusao da linha.';
comment on column poseidon.dpc_dfe_nfse.created_by is
  'Rotina que incluiu a linha (DFE INGERIR, DFE NORMALIZAR, DFE CONCILIAR, CARGA INICIAL).';
comment on column poseidon.dpc_dfe_nfse.updated_at is
  'Data da ultima alteracao.';
comment on column poseidon.dpc_dfe_nfse.updated_by is
  'Rotina que alterou a linha por ultimo.';


-- ###########################################################################
--  8. CONFERENCIA RAPIDA
--  O detalhamento esta no 01_04_validacao_dbeaver.sql. Isto aqui e o suficiente
--  para saber se a instalacao terminou.
--
--  SEM CONTAGEM GLOBAL ESCRITA A MAO. Ate 09/09/2026 esta secao comparava
--  contra 12 tabelas, 52 constraints e 242 colunas comentadas - os numeros de
--  antes das colunas de etapa no ERP. Quem instalasse numa base limpa leria
--  "esperado 12, achado 13" e concluiria que a instalacao falhou.
--
--  Numero que envelhece sozinho e pior que numero nenhum. As duas consultas
--  abaixo trocam a contagem global por INVARIANTES - relacoes que continuam
--  verdadeiras quando o modulo cresce - e, onde o numero e inevitavel, por uma
--  contagem POR TABELA, que muda junto com o create table da secao 2.
-- ###########################################################################

--  1) INVARIANTES. Nao envelhecem: nenhuma delas cita quantidade.
--     ESPERADO: as quatro linhas com qtd = 0.
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
select 'objeto invalido', count(*)
  from all_objects
 where owner = 'POSEIDON' and object_name like '%DFE%' and status <> 'VALID';


--  2) COLUNA POR TABELA. Treze numeros, e nao 273: quando uma coluna entra no
--     modulo, muda UM deles. A lista sai do mesmo create table da secao 2.
--     ESPERADO: diferenca toda em zero, e nenhuma linha com achado nulo.
with esperado as (
  select 'dpc_dfe_empresa'        as tabela,  11 as esperado from dual union all
  select 'dpc_dfe_cursor'                  ,  16             from dual union all
  select 'dpc_dfe_emitente'                ,   8             from dual union all
  select 'dpc_dfe_documento'               ,  13             from dual union all
  select 'dpc_dfe_nota'                    ,  37             from dual union all
  select 'dpc_dfe_nota_item'               ,  51             from dual union all
  select 'dpc_dfe_evento'                  ,  14             from dual union all
  select 'dpc_dfe_execucao'                ,  15             from dual union all
  select 'dpc_dfe_manifestacao'            ,  15             from dual union all
  select 'dpc_dfe_cte'                     ,  35             from dual union all
  select 'dpc_dfe_cte_nfe'                 ,   5             from dual union all
  select 'dpc_dfe_cte_evento'              ,  20             from dual union all
  select 'dpc_dfe_nfse'                    ,  33             from dual
), achado as (
  select lower(table_name) as tabela, count(*) as qtd
    from all_tab_columns
   where owner = 'POSEIDON' and table_name like 'DPC_DFE%'
   group by table_name
)
select e.tabela, e.esperado, a.qtd as achado,
       nvl(a.qtd, 0) - e.esperado as diferenca
  from esperado e
  left join achado a on a.tabela = e.tabela
 order by case when nvl(a.qtd, 0) - e.esperado <> 0 then 0 else 1 end, e.tabela;
