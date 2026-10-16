-- ============================================================================
--  MODULO DFe - ESTRUTURA DO MOTOR (ddl/01_estrutura_motor)
-- ============================================================================
--  Captura propria de documento fiscal de ENTRADA: NF-e, CT-e e NFS-e. Schema POSEIDON, tablespace TSD_POSEIDON.
--  Estado FINAL de 17 tabelas: empresa, cursor, emitente, execucao, documento, nota (+ item, total, transporte,
--  cobranca), cte (+ cte_nfe, cte_evento), nfse, evento, manifestacao e manif_pedido.
--
--  ==========================================================================
--   UM CAMINHO SO, CONVERGENTE
--  ==========================================================================
--  Leva a estrutura ao estado correto partindo de QUALQUER base: vazia, parcial ou ja completa. Cada objeto e
--  criado somente se nao existir, cada coluna e conferida uma a uma, CHECK e UNIQUE sao redefinidas quando a
--  definicao difere, e o que reexecutar reescreve (comentarios e triggers) e identico. Rodar duas vezes produz
--  o mesmo resultado da primeira. Nao existe script de "alteracao": coluna nova entra na secao 2 (create) e
--  na secao 3 (lista de colunas) deste arquivo.
--
--  Este arquivo consolida, em 13/10/2026, o antigo 01_01 e todos os blocos de alteracao que vieram depois dele
--  (04_01, 07_01, 08_01, 08_02, 09_01, 12_01, 13_01). Esta tudo no git; o catalogo (docs/09) diz onde achar.
--
--  ==========================================================================
--   O QUE NAO FAZ
--  ==========================================================================
--   - nao cadastra empresa nem cria fluxo (isso e dado, e vive em homolog/ ou vem da replicacao)
--   - nao carrega parametro (ddl/03_parametros)
--   - nao cria as tabelas de tela (ddl/02_estrutura_telas): o motor nao sabe o que e um usuario
--   - nao mexe em nada fora do schema POSEIDON; nao le nem altera nada do ERP
--   - nao altera tipo nem tamanho de coluna que ja existe
--
--  ==========================================================================
--   DECISOES DE PROJETO QUE ESTE ESTADO FINAL CARREGA
--  ==========================================================================
--   - PK por TRIGGER + SEQUENCE, so quando a PK vem nula: preserva a chave informada de proposito (carga,
--     correcao e o dfe:replicar, que copia homolog -> producao com as MESMAS chaves).
--   - O NSU e sequencial POR FLUXO: a UNIQUE do documento e (cursor, nsu), e nao (empresa, nsu). A antiga
--     (empresa, nsu) transformaria a protecao contra duplicidade em PERDA de documento.
--   - Identidade fiscal (empresa) e estado de leitura (cursor) sao tabelas distintas: uma por CNPJ, um cursor
--     por CNPJ e tipo (NFE, CTE, MDFE, NFSE).
--   - cod_cfop_xml, cod_dfe_manif_pedido e as 31 colunas do XML da NF-e sao ANULAVEIS e sem DEFAULT: nulo
--     significa "ainda nao calculado" e evita reescrever a tabela ao acrescentar a coluna.
--   - A CATEGORIA da nota (Compras, Suprimentos, Devolucao) vem do GRUPO do emitente no cadastro de pessoas do ERP,
--     gravado em dpc_dfe_emitente.dsc_grupo_erp pelo dfe:conciliar (regra do time fiscal, 13/10/2026). Fica
--     em coluna, e nao em join com o Consinco, porque o CASE roda no WHERE de contagens e filtros.
--   - O COMPRADOR exibido e o do FORNECEDOR no ERP (maf_fornecdivisao, divisao 1), gravado em
--     dpc_dfe_emitente.seq_comprador_erp/dsc_comprador_erp so para emitente FORNECEDOR ou FORNECEDOR CONSUMO
--     (pedido do time fiscal, 13/10/2026). As colunas de comprador de dpc_dfe_nota (item de maior valor) ficam
--     sem uso.
--   - Evento orfao (cod_dfe_nota nulo) e valido: o NFeDistribuicaoDFe entrega evento de nota que ainda nao
--     foi capturada, e nao pode ser descartado.
--   - DPC_DFE_EMPRESA_CK1/IX1 e DPC_DFE_DOCUMENTO_UK1 NAO existem de proposito (ver secoes 4 e 5).
--
--  ==========================================================================
--   COMO RODAR (DBeaver)
--  ==========================================================================
--  Conectado como POSEIDON, arquivo INTEIRO com Alt+X. Sem "/" para terminar bloco. E CRLF de proposito: em LF
--  o divisor de statements do DBeaver corta o bloco PL/SQL no fim do IF e devolve PLS-00103. Nenhum bloco tem
--  linha em branco dentro (o DBeaver trata linha em branco como fim de statement).
--
--  LIGUE O DBMS_OUTPUT (aba Output do editor de SQL): a secao 3 avisa por ali o que acrescentou e o que exige
--  decisao humana; sem o Output ligado esses avisos passam invisiveis.
--
--  Se algo falhar no meio, corrija e rode o arquivo de novo - o que ja passou nao e refeito nem duplicado.
-- ============================================================================


-- ###########################################################################
--  0. PRE-REQUISITOS
--  Somente leitura. Diz quem voce e, se o tablespace existe e quantos objetos do modulo ja existem.
--  Objeto preexistente nao impede a execucao (o arquivo e convergente), mas voce quer saber ANTES se esta
--  instalando de zero ou completando.
-- ###########################################################################
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
--  Uma por tabela que usa trigger. A PK NUNCA e informada pela aplicacao: quem preenche e a trigger da secao 6,
--  lendo daqui. Padrao do ecossistema DPC. As tabelas de tela usam IDENTITY e nao tem sequence propria.
--  cache 20 em todas.
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
   where sequence_owner = 'POSEIDON' and sequence_name = 'DPCS_DFE_EXECUCAO';
  if qtd = 0 then
    execute immediate q'[create sequence poseidon.dpcs_dfe_execucao minvalue 1 start with 1 increment by 1 cache 20]';
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
   where sequence_owner = 'POSEIDON' and sequence_name = 'DPCS_DFE_MANIFESTACAO';
  if qtd = 0 then
    execute immediate q'[create sequence poseidon.dpcs_dfe_manifestacao minvalue 1 start with 1 increment by 1 cache 20]';
  end if;
end;

-- ###########################################################################
--  2. TABELAS
--  Ordem de dependencia: a tabela referenciada por FK vem antes.
--  As constraints ficam na secao 4, para que uma falha de FK nao interrompa a criacao das tabelas.
--  Este e o estado FINAL de cada tabela. Numa base que ja tem a tabela, o create e pulado e e a secao 3
--  (COLUNAS) que acrescenta o que faltar.
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
          cod_dfe_empresa            NUMBER not null,
          nro_empresa                NUMBER not null,
          num_cnpj                   VARCHAR2(14) not null,
          status_manifestar          VARCHAR2(1) default 'S' not null,
          dsc_razao_social           VARCHAR2(120) not null,
          sig_uf                     VARCHAR2(2) not null,
          num_inscr_estadual         VARCHAR2(20),
          created_at                 DATE default sysdate,
          created_by                 VARCHAR2(50),
          updated_at                 DATE,
          updated_by                 VARCHAR2(50),
          status_manif_auto_ciencia  VARCHAR2(1) default 'N' not null,
          status_manif_auto_confirmacao VARCHAR2(1) default 'N' not null,
          dta_inicio_manif_auto_conf DATE
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
          cod_dfe_cursor             NUMBER not null,
          cod_dfe_empresa            NUMBER not null,
          cod_tipo_dfe               VARCHAR2(4) not null,
          status_sincronismo         VARCHAR2(1) default 'A' not null,
          nro_ultimo_nsu             NUMBER default 0 not null,
          nro_maximo_nsu             NUMBER default 0 not null,
          qtd_min_entre_consulta     NUMBER default 3 not null,
          qtd_min_em_dia             NUMBER default 60 not null,
          dta_ultima_consulta        TIMESTAMP(6),
          dta_liberado_em            TIMESTAMP(6),
          cod_ultimo_status          VARCHAR2(5),
          dsc_ultimo_motivo          VARCHAR2(255),
          created_at                 DATE default sysdate,
          created_by                 VARCHAR2(50),
          updated_at                 DATE,
          updated_by                 VARCHAR2(50)
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
          cod_dfe_emitente           NUMBER not null,
          num_cnpj_cpf               VARCHAR2(14) not null,
          dsc_razao_social           VARCHAR2(120),
          num_inscr_estadual         VARCHAR2(20),
          created_at                 DATE default sysdate,
          created_by                 VARCHAR2(50),
          updated_at                 DATE,
          updated_by                 VARCHAR2(50),
          dsc_grupo_erp              VARCHAR2(40),
          seq_pessoa_erp             NUMBER,
          dta_conferencia_erp        TIMESTAMP(6),
          seq_comprador_erp          NUMBER,
          dsc_comprador_erp          VARCHAR2(40)
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
          cod_dfe_execucao           NUMBER not null,
          cod_dfe_cursor             NUMBER not null,
          cod_dfe_empresa            NUMBER not null,
          dta_inicio                 TIMESTAMP(6) default systimestamp not null,
          dta_fim                    TIMESTAMP(6),
          nro_nsu_inicial            NUMBER,
          nro_nsu_final              NUMBER,
          qtd_consulta               NUMBER default 0 not null,
          qtd_documento              NUMBER default 0 not null,
          qtd_nota                   NUMBER default 0 not null,
          qtd_evento                 NUMBER default 0 not null,
          qtd_erro                   NUMBER default 0 not null,
          cod_resultado              VARCHAR2(20),
          dsc_resultado              VARCHAR2(4000),
          created_by                 VARCHAR2(50)
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
          cod_dfe_documento          NUMBER not null,
          cod_dfe_cursor             NUMBER not null,
          cod_dfe_empresa            NUMBER not null,
          nro_nsu                    NUMBER not null,
          dsc_schema                 VARCHAR2(60),
          dsc_tipo_doc               VARCHAR2(10),
          chave_nf                   VARCHAR2(50),
          bin_documento              BLOB,
          status_process             VARCHAR2(1) default 'P' not null,
          qtd_tentativa              NUMBER default 0 not null,
          det_erro                   VARCHAR2(4000),
          dta_recebimento            TIMESTAMP(6) default systimestamp not null,
          dta_processado             TIMESTAMP(6)
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
          cod_dfe_nota               NUMBER not null,
          cod_dfe_empresa            NUMBER not null,
          cod_dfe_emitente           NUMBER,
          chave_nf                   VARCHAR2(44) not null,
          nro_nsu                    NUMBER,
          dsc_tipo_doc               VARCHAR2(10),
          nro_modelo                 NUMBER,
          nro_serie                  NUMBER,
          nro_nf                     NUMBER,
          tipo_nf                    NUMBER,
          vlr_nota                   NUMBER,
          vlr_total_produto          NUMBER,
          dta_emissao                DATE,
          dta_recibo                 DATE,
          nro_protocolo              VARCHAR2(20),
          cod_situacao               NUMBER,
          dsc_situacao               VARCHAR2(20),
          status_manifestacao        VARCHAR2(1) default 'N' not null,
          sig_papel_empresa          VARCHAR2(6),
          status_recebimento         VARCHAR2(1) default 'N' not null,
          seq_nf_erp                 NUMBER,
          dta_entrada_erp            DATE,
          dta_conciliacao            TIMESTAMP(6),
          sig_estado_erp             VARCHAR2(20),
          num_estado_erp             NUMBER(1),
          num_estado_erp_max         NUMBER(1),
          dta_estado_erp             TIMESTAMP(6),
          seq_notamestre_erp         NUMBER,
          dta_lancamento_erp         DATE,
          cod_cfop_erp               NUMBER(5),
          dsc_ocorr_dev_erp          VARCHAR2(5),
          seq_comprador_erp          NUMBER,
          dsc_comprador_erp          VARCHAR2(40),
          created_at                 DATE default sysdate,
          created_by                 VARCHAR2(50),
          updated_at                 DATE,
          updated_by                 VARCHAR2(50),
          dsc_natureza_operacao      VARCHAR2(60),
          cod_finalidade             NUMBER(1),
          cod_consumidor_final       NUMBER(1),
          cod_presenca               NUMBER(1),
          cod_regime_trib_emit       NUMBER(1),
          num_inscr_est_st_emit      VARCHAR2(14),
          dsc_logradouro_emit        VARCHAR2(60),
          nro_endereco_emit          VARCHAR2(60),
          dsc_complemento_emit       VARCHAR2(60),
          dsc_bairro_emit            VARCHAR2(60),
          cod_municipio_emit         VARCHAR2(7),
          dsc_municipio_emit         VARCHAR2(60),
          sig_uf_emit                VARCHAR2(2),
          num_cep_emit               VARCHAR2(8),
          num_fone_emit              VARCHAR2(14),
          num_cnpj_cpf_dest          VARCHAR2(14),
          num_inscr_estadual_dest    VARCHAR2(14),
          cod_ind_ie_dest            NUMBER(1),
          dsc_logradouro_dest        VARCHAR2(60),
          nro_endereco_dest          VARCHAR2(60),
          dsc_complemento_dest       VARCHAR2(60),
          dsc_bairro_dest            VARCHAR2(60),
          cod_municipio_dest         VARCHAR2(7),
          dsc_municipio_dest         VARCHAR2(60),
          sig_uf_dest                VARCHAR2(2),
          num_cep_dest               VARCHAR2(8),
          num_fone_dest              VARCHAR2(14),
          dsc_inf_complementar       CLOB,
          dsc_inf_fisco              VARCHAR2(2000),
          dsc_nfe_referenciada       VARCHAR2(500),
          dsc_pedido_compra          VARCHAR2(500),
          cod_cfop_xml               NUMBER(4)
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
          cod_dfe_nota_item          NUMBER not null,
          cod_dfe_nota               NUMBER not null,
          nro_item                   NUMBER not null,
          cod_produto                VARCHAR2(60),
          cod_ean                    VARCHAR2(20),
          dsc_produto                VARCHAR2(120),
          cod_ncm                    VARCHAR2(8),
          cod_cest                   VARCHAR2(7),
          cod_ex_tipi                VARCHAR2(3),
          cod_cfop                   VARCHAR2(4),
          cod_beneficio              VARCHAR2(10),
          sig_unid_com               VARCHAR2(6),
          qtd_comercial              NUMBER,
          vlr_unit_com               NUMBER,
          vlr_produto                NUMBER,
          sig_unid_trib              VARCHAR2(6),
          qtd_tributavel             NUMBER,
          vlr_unit_trib              NUMBER,
          vlr_frete                  NUMBER,
          vlr_seguro                 NUMBER,
          vlr_desconto               NUMBER,
          vlr_outros                 NUMBER,
          status_compoe_total        VARCHAR2(1),
          vlr_item                   NUMBER,
          dsc_inf_adic               VARCHAR2(500),
          cod_cst_icms               VARCHAR2(4),
          cod_origem                 VARCHAR2(1),
          vlr_bc_icms                NUMBER,
          pct_icms                   NUMBER,
          vlr_icms                   NUMBER,
          vlr_bc_icms_st             NUMBER,
          vlr_icms_st                NUMBER,
          cod_cst_ipi                VARCHAR2(2),
          vlr_bc_ipi                 NUMBER,
          pct_ipi                    NUMBER,
          vlr_ipi                    NUMBER,
          cod_cst_pis                VARCHAR2(2),
          vlr_bc_pis                 NUMBER,
          pct_pis                    NUMBER,
          vlr_pis                    NUMBER,
          cod_cst_cofins             VARCHAR2(2),
          vlr_bc_cofins              NUMBER,
          pct_cofins                 NUMBER,
          vlr_cofins                 NUMBER,
          cod_cst_ibscbs             VARCHAR2(3),
          cod_class_trib             VARCHAR2(6),
          vlr_bc_ibscbs              NUMBER,
          vlr_ibs                    NUMBER,
          vlr_cbs                    NUMBER,
          created_at                 DATE default sysdate,
          created_by                 VARCHAR2(50)
        )
        tablespace TSD_POSEIDON
        ]';
  end if;
end;

-- ---------- DPC_DFE_NOTA_TOTAL ----------
declare
  qtd number;
begin
  select count(*) into qtd from all_tables
   where owner = 'POSEIDON' and table_name = 'DPC_DFE_NOTA_TOTAL';
  if qtd = 0 then
    execute immediate q'[create table poseidon.dpc_dfe_nota_total
        (
          cod_dfe_nota               NUMBER not null,
          vlr_bc_icms                NUMBER,
          vlr_icms                   NUMBER,
          vlr_icms_deson             NUMBER,
          vlr_fcp_uf_dest            NUMBER,
          vlr_icms_uf_dest           NUMBER,
          vlr_icms_uf_remet          NUMBER,
          vlr_fcp                    NUMBER,
          vlr_bc_icms_st             NUMBER,
          vlr_icms_st                NUMBER,
          vlr_fcp_st                 NUMBER,
          vlr_fcp_st_ret             NUMBER,
          vlr_frete                  NUMBER,
          vlr_seguro                 NUMBER,
          vlr_desconto               NUMBER,
          vlr_ii                     NUMBER,
          vlr_ipi                    NUMBER,
          vlr_ipi_devol              NUMBER,
          vlr_pis                    NUMBER,
          vlr_cofins                 NUMBER,
          vlr_outros                 NUMBER,
          vlr_total_tributo          NUMBER,
          vlr_bc_ibscbs              NUMBER,
          vlr_ibs                    NUMBER,
          vlr_ibs_uf                 NUMBER,
          vlr_ibs_mun                NUMBER,
          vlr_cbs                    NUMBER,
          vlr_nota_total             NUMBER,
          created_at                 DATE default sysdate not null,
          created_by                 VARCHAR2(50),
          updated_at                 DATE,
          updated_by                 VARCHAR2(50)
        )
        tablespace TSD_POSEIDON
        ]';
  end if;
end;

-- ---------- DPC_DFE_NOTA_TRANSPORTE ----------
declare
  qtd number;
begin
  select count(*) into qtd from all_tables
   where owner = 'POSEIDON' and table_name = 'DPC_DFE_NOTA_TRANSPORTE';
  if qtd = 0 then
    execute immediate q'[create table poseidon.dpc_dfe_nota_transporte
        (
          cod_dfe_nota               NUMBER not null,
          cod_modalidade_frete       NUMBER(1),
          num_cnpj_cpf_transp        VARCHAR2(14),
          dsc_razao_transp           VARCHAR2(60),
          num_inscr_estadual_transp  VARCHAR2(14),
          dsc_endereco_transp        VARCHAR2(60),
          dsc_municipio_transp       VARCHAR2(60),
          sig_uf_transp              VARCHAR2(2),
          num_placa_veiculo          VARCHAR2(8),
          sig_uf_veiculo             VARCHAR2(2),
          num_rntc                   VARCHAR2(20),
          qtd_volume                 NUMBER,
          vlr_peso_liquido           NUMBER,
          vlr_peso_bruto             NUMBER,
          dsc_especie_volume         VARCHAR2(1000),
          dsc_marca_volume           VARCHAR2(1000),
          dsc_numeracao_volume       VARCHAR2(1000),
          created_at                 DATE default sysdate not null,
          created_by                 VARCHAR2(50),
          updated_at                 DATE,
          updated_by                 VARCHAR2(50)
        )
        tablespace TSD_POSEIDON
        ]';
  end if;
end;

-- ---------- DPC_DFE_NOTA_COBRANCA ----------
declare
  qtd number;
begin
  select count(*) into qtd from all_tables
   where owner = 'POSEIDON' and table_name = 'DPC_DFE_NOTA_COBRANCA';
  if qtd = 0 then
    execute immediate q'[create table poseidon.dpc_dfe_nota_cobranca
        (
          cod_dfe_nota               NUMBER not null,
          num_fatura                 VARCHAR2(60),
          vlr_original               NUMBER,
          vlr_desconto               NUMBER,
          vlr_liquido                NUMBER,
          dsc_forma_pagto            VARCHAR2(200),
          dsc_indicador_pagto        VARCHAR2(50),
          vlr_pago                   NUMBER,
          vlr_troco                  NUMBER,
          created_at                 DATE default sysdate not null,
          created_by                 VARCHAR2(50),
          updated_at                 DATE,
          updated_by                 VARCHAR2(50)
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
          cod_dfe_cte                NUMBER not null,
          cod_dfe_empresa            NUMBER not null,
          chave_cte                  VARCHAR2(44) not null,
          nro_nsu                    NUMBER,
          dsc_tipo_doc               VARCHAR2(10),
          nro_modelo                 NUMBER,
          nro_serie                  NUMBER,
          nro_cte                    NUMBER,
          dta_emissao                DATE,
          cod_cfop                   VARCHAR2(4),
          dsc_natureza_oper          VARCHAR2(60),
          cod_modal                  VARCHAR2(2),
          cod_tipo_servico           VARCHAR2(1),
          cod_tipo_cte               VARCHAR2(1),
          dsc_municipio_ini          VARCHAR2(60),
          sig_uf_ini                 VARCHAR2(2),
          dsc_municipio_fim          VARCHAR2(60),
          sig_uf_fim                 VARCHAR2(2),
          num_cnpj_emitente          VARCHAR2(14),
          dsc_razao_emitente         VARCHAR2(120),
          num_cnpj_remetente         VARCHAR2(14),
          num_cnpj_expedidor         VARCHAR2(14),
          num_cnpj_recebedor         VARCHAR2(14),
          num_cnpj_destinat          VARCHAR2(14),
          cod_tomador                VARCHAR2(1),
          sig_papel_empresa          VARCHAR2(6),
          vlr_prestacao              NUMBER,
          vlr_receber                NUMBER,
          nro_protocolo              VARCHAR2(20),
          cod_situacao               NUMBER,
          dsc_situacao               VARCHAR2(20),
          created_at                 DATE default sysdate,
          created_by                 VARCHAR2(50),
          updated_at                 DATE,
          updated_by                 VARCHAR2(50),
          dsc_razao_remetente        VARCHAR2(120),
          dsc_razao_destinat         VARCHAR2(120),
          dsc_razao_expedidor        VARCHAR2(120),
          dsc_razao_recebedor        VARCHAR2(120),
          num_cnpj_tomador4          VARCHAR2(14),
          dsc_razao_tomador4         VARCHAR2(120),
          cod_cst_icms               VARCHAR2(2),
          vlr_bc_icms                NUMBER,
          vlr_icms                   NUMBER,
          pct_icms                   NUMBER,
          dta_autorizacao            DATE,
          chave_cte_complementado    VARCHAR2(44),
          vlr_ibs_mun                NUMBER,
          vlr_ibs_uf                 NUMBER,
          vlr_cbs                    NUMBER
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
          cod_dfe_cte_nfe            NUMBER not null,
          cod_dfe_cte                NUMBER not null,
          chave_nf                   VARCHAR2(44) not null,
          created_at                 DATE default sysdate,
          created_by                 VARCHAR2(50)
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
          cod_dfe_cte_evento         NUMBER not null,
          cod_dfe_empresa            NUMBER not null,
          cod_dfe_cte                NUMBER,
          chave_cte                  VARCHAR2(44) not null,
          nro_nsu                    NUMBER,
          cod_tipo_evento            VARCHAR2(6),
          dsc_evento                 VARCHAR2(255),
          nro_seq_evento             NUMBER default 1 not null,
          nro_protocolo              VARCHAR2(20),
          cod_status                 VARCHAR2(5),
          dsc_motivo                 VARCHAR2(255),
          dta_evento                 TIMESTAMP(6),
          num_cnpj_autor             VARCHAR2(14),
          dta_entrega                TIMESTAMP(6),
          num_doc_recebedor          VARCHAR2(60),
          dsc_nome_recebedor         VARCHAR2(60),
          dsc_hash_entrega           VARCHAR2(60),
          chave_mdfe                 VARCHAR2(44),
          created_at                 DATE default sysdate,
          created_by                 VARCHAR2(50)
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
          cod_dfe_nfse               NUMBER not null,
          cod_dfe_empresa            NUMBER not null,
          chave_nfse                 VARCHAR2(50) not null,
          nro_nsu                    NUMBER,
          dsc_tipo_doc               VARCHAR2(10),
          nro_nfse                   VARCHAR2(15),
          dta_processamento          DATE,
          dta_competencia            DATE,
          cod_situacao               NUMBER,
          dsc_situacao               VARCHAR2(20),
          sig_papel_empresa          VARCHAR2(6),
          num_cnpj_cpf_prest         VARCHAR2(14),
          dsc_razao_prest            VARCHAR2(120),
          num_insc_munic_prest       VARCHAR2(20),
          cod_municipio_prest        VARCHAR2(7),
          sig_uf_prest               VARCHAR2(2),
          num_cnpj_cpf_toma          VARCHAR2(14),
          dsc_razao_toma             VARCHAR2(120),
          cod_municipio_incid        VARCHAR2(7),
          dsc_municipio_incid        VARCHAR2(60),
          cod_trib_nacional          VARCHAR2(10),
          cod_trib_municipal         VARCHAR2(20),
          dsc_servico                VARCHAR2(2000),
          vlr_servico                NUMBER,
          vlr_base_calculo           NUMBER,
          pct_aliquota               NUMBER,
          vlr_issqn                  NUMBER,
          vlr_retido                 NUMBER,
          vlr_liquido                NUMBER,
          created_at                 DATE default sysdate,
          created_by                 VARCHAR2(50),
          updated_at                 DATE,
          updated_by                 VARCHAR2(50),
          cod_tipo_emissao           NUMBER(3),
          dsc_tipo_emissao           VARCHAR2(40),
          dta_emissao                DATE,
          dta_cancelamento           DATE,
          chave_nfse_substituta      VARCHAR2(50),
          dsc_local_emissao          VARCHAR2(150),
          dsc_local_prestacao        VARCHAR2(150),
          dsc_logradouro_prest       VARCHAR2(255),
          nro_endereco_prest         VARCHAR2(60),
          dsc_complemento_prest      VARCHAR2(156),
          dsc_bairro_prest           VARCHAR2(60),
          num_cep_prest              VARCHAR2(8)
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
          cod_dfe_evento             NUMBER not null,
          cod_dfe_empresa            NUMBER not null,
          cod_dfe_nota               NUMBER,
          chave_nf                   VARCHAR2(44) not null,
          nro_nsu                    NUMBER,
          cod_tipo_evento            VARCHAR2(6),
          dsc_evento                 VARCHAR2(255),
          nro_seq_evento             NUMBER default 1 not null,
          nro_protocolo              VARCHAR2(20),
          cod_status                 VARCHAR2(5),
          dsc_motivo                 VARCHAR2(255),
          dta_evento                 TIMESTAMP(6),
          created_at                 DATE default sysdate,
          created_by                 VARCHAR2(50)
        )
        tablespace TSD_POSEIDON
        ]';
  end if;
end;

-- ---------- DPC_DFE_MANIF_PEDIDO ----------
declare
  qtd number;
begin
  select count(*) into qtd from all_tables
   where owner = 'POSEIDON' and table_name = 'DPC_DFE_MANIF_PEDIDO';
  if qtd = 0 then
    execute immediate q'[create table poseidon.dpc_dfe_manif_pedido
        (
          cod_dfe_manif_pedido       NUMBER generated by default as identity not null,
          cod_tipo_evento            VARCHAR2(6) not null,
          usuario                    VARCHAR2(100) not null,
          qtd_solicitada             NUMBER not null,
          qtd_aceita                 NUMBER not null,
          qtd_recusada               NUMBER not null,
          status_pedido              VARCHAR2(1) default 'A' not null,
          usuario_cancelamento       VARCHAR2(100),
          dta_cancelamento           DATE,
          created_at                 DATE default sysdate not null
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
          cod_dfe_manifestacao       NUMBER not null,
          cod_dfe_nota               NUMBER not null,
          cod_tipo_evento            VARCHAR2(6) not null,
          status_envio               VARCHAR2(1) default 'P' not null,
          cod_status_retorno         VARCHAR2(5),
          dsc_status_retorno         VARCHAR2(255),
          nro_protocolo              VARCHAR2(20),
          qtd_tentativa              NUMBER default 0 not null,
          det_erro                   VARCHAR2(4000),
          xml_retorno                CLOB,
          dta_envio                  TIMESTAMP(6),
          dta_ultima_tentativa       TIMESTAMP(6),
          dta_atualizacao            TIMESTAMP(6),
          created_at                 DATE default sysdate,
          created_by                 VARCHAR2(50),
          nro_seq_evento             NUMBER default 1 not null,
          dsc_justificativa          VARCHAR2(255),
          dta_registro_evento        TIMESTAMP(6),
          cod_dfe_empresa            NUMBER,
          dsc_id_lote                VARCHAR2(20),
          dta_proxima_tentativa      TIMESTAMP(6),
          cod_dfe_manif_pedido       NUMBER
        )
        tablespace TSD_POSEIDON
        ]';
  end if;
end;

-- ###########################################################################
--  3. COLUNAS
--  E esta secao que faz o arquivo servir a QUALQUER base: o create table da secao 2 e PULADO quando a tabela
--  existe, entao numa base instalada por uma versao anterior as tabelas estao no lugar e as colunas novas nao.
--  Aqui a lista de colunas de cada tabela e conferida uma a uma e a que faltar e acrescentada. Numa base
--  recem-criada pela secao 2 a secao inteira e no-op.
--
--  MANUTENCAO: coluna nova entra em DOIS lugares - no create table da secao 2 e na lista desta secao. Sao a
--  mesma lista; a secao 1 do 04_validacao compara a contagem contra o banco.
--
--  CADA COLUNA TEM EXCEPTION PROPRIA: coluna NOT NULL sem DEFAULT acrescentada a tabela que JA TEM LINHAS falha
--  com ORA-01758 - e falhar e o certo, nao ha valor para as linhas antigas. Sem o handler a primeira dessas
--  abortaria o arquivo; com ele o script termina e o DBMS_OUTPUT diz qual coluna exige decisao humana.
--
--  NAO altera tipo nem tamanho de coluna existente: ALTER MODIFY pode falhar por causa do dado e nao cabe em
--  script automatico. A divergencia aparece no 04_validacao (secao 4) e no dfe:replicar --estrutura.
-- ###########################################################################
-- ---------- DPC_DFE_EMPRESA ----------
declare
  qtd number;
begin
  for c in (
    select 'cod_dfe_empresa' as nome, q'[NUMBER not null]' as def from dual union all
    select 'nro_empresa', q'[NUMBER not null]' from dual union all
    select 'num_cnpj', q'[VARCHAR2(14) not null]' from dual union all
    select 'status_manifestar', q'[VARCHAR2(1) default 'S' not null]' from dual union all
    select 'dsc_razao_social', q'[VARCHAR2(120) not null]' from dual union all
    select 'sig_uf', q'[VARCHAR2(2) not null]' from dual union all
    select 'num_inscr_estadual', q'[VARCHAR2(20)]' from dual union all
    select 'created_at', q'[DATE default sysdate]' from dual union all
    select 'created_by', q'[VARCHAR2(50)]' from dual union all
    select 'updated_at', q'[DATE]' from dual union all
    select 'updated_by', q'[VARCHAR2(50)]' from dual union all
    select 'status_manif_auto_ciencia', q'[VARCHAR2(1) default 'N' not null]' from dual union all
    select 'status_manif_auto_confirmacao', q'[VARCHAR2(1) default 'N' not null]' from dual union all
    select 'dta_inicio_manif_auto_conf', q'[DATE]' from dual
  ) loop
    begin
      select count(*) into qtd from all_tab_columns
       where owner = 'POSEIDON' and table_name = 'DPC_DFE_EMPRESA'
         and column_name = upper(c.nome);
      if qtd = 0 then
        execute immediate 'alter table poseidon.dpc_dfe_empresa add (' || c.nome || ' ' || c.def || ')';
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
    select 'cod_dfe_cursor' as nome, q'[NUMBER not null]' as def from dual union all
    select 'cod_dfe_empresa', q'[NUMBER not null]' from dual union all
    select 'cod_tipo_dfe', q'[VARCHAR2(4) not null]' from dual union all
    select 'status_sincronismo', q'[VARCHAR2(1) default 'A' not null]' from dual union all
    select 'nro_ultimo_nsu', q'[NUMBER default 0 not null]' from dual union all
    select 'nro_maximo_nsu', q'[NUMBER default 0 not null]' from dual union all
    select 'qtd_min_entre_consulta', q'[NUMBER default 3 not null]' from dual union all
    select 'qtd_min_em_dia', q'[NUMBER default 60 not null]' from dual union all
    select 'dta_ultima_consulta', q'[TIMESTAMP(6)]' from dual union all
    select 'dta_liberado_em', q'[TIMESTAMP(6)]' from dual union all
    select 'cod_ultimo_status', q'[VARCHAR2(5)]' from dual union all
    select 'dsc_ultimo_motivo', q'[VARCHAR2(255)]' from dual union all
    select 'created_at', q'[DATE default sysdate]' from dual union all
    select 'created_by', q'[VARCHAR2(50)]' from dual union all
    select 'updated_at', q'[DATE]' from dual union all
    select 'updated_by', q'[VARCHAR2(50)]' from dual
  ) loop
    begin
      select count(*) into qtd from all_tab_columns
       where owner = 'POSEIDON' and table_name = 'DPC_DFE_CURSOR'
         and column_name = upper(c.nome);
      if qtd = 0 then
        execute immediate 'alter table poseidon.dpc_dfe_cursor add (' || c.nome || ' ' || c.def || ')';
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
    select 'cod_dfe_emitente' as nome, q'[NUMBER not null]' as def from dual union all
    select 'num_cnpj_cpf', q'[VARCHAR2(14) not null]' from dual union all
    select 'dsc_razao_social', q'[VARCHAR2(120)]' from dual union all
    select 'num_inscr_estadual', q'[VARCHAR2(20)]' from dual union all
    select 'created_at', q'[DATE default sysdate]' from dual union all
    select 'created_by', q'[VARCHAR2(50)]' from dual union all
    select 'updated_at', q'[DATE]' from dual union all
    select 'updated_by', q'[VARCHAR2(50)]' from dual union all
    select 'dsc_grupo_erp', q'[VARCHAR2(40)]' from dual union all
    select 'seq_pessoa_erp', q'[NUMBER]' from dual union all
    select 'dta_conferencia_erp', q'[TIMESTAMP(6)]' from dual union all
    select 'seq_comprador_erp', q'[NUMBER]' from dual union all
    select 'dsc_comprador_erp', q'[VARCHAR2(40)]' from dual
  ) loop
    begin
      select count(*) into qtd from all_tab_columns
       where owner = 'POSEIDON' and table_name = 'DPC_DFE_EMITENTE'
         and column_name = upper(c.nome);
      if qtd = 0 then
        execute immediate 'alter table poseidon.dpc_dfe_emitente add (' || c.nome || ' ' || c.def || ')';
        dbms_output.put_line('DPC_DFE_EMITENTE: acrescentada -> ' || c.nome);
      end if;
    exception
      when others then
        dbms_output.put_line('DPC_DFE_EMITENTE: FALHOU em ' || c.nome || ' -> ' || sqlerrm);
    end;
  end loop;
end;

-- ---------- DPC_DFE_EXECUCAO ----------
declare
  qtd number;
begin
  for c in (
    select 'cod_dfe_execucao' as nome, q'[NUMBER not null]' as def from dual union all
    select 'cod_dfe_cursor', q'[NUMBER not null]' from dual union all
    select 'cod_dfe_empresa', q'[NUMBER not null]' from dual union all
    select 'dta_inicio', q'[TIMESTAMP(6) default systimestamp not null]' from dual union all
    select 'dta_fim', q'[TIMESTAMP(6)]' from dual union all
    select 'nro_nsu_inicial', q'[NUMBER]' from dual union all
    select 'nro_nsu_final', q'[NUMBER]' from dual union all
    select 'qtd_consulta', q'[NUMBER default 0 not null]' from dual union all
    select 'qtd_documento', q'[NUMBER default 0 not null]' from dual union all
    select 'qtd_nota', q'[NUMBER default 0 not null]' from dual union all
    select 'qtd_evento', q'[NUMBER default 0 not null]' from dual union all
    select 'qtd_erro', q'[NUMBER default 0 not null]' from dual union all
    select 'cod_resultado', q'[VARCHAR2(20)]' from dual union all
    select 'dsc_resultado', q'[VARCHAR2(4000)]' from dual union all
    select 'created_by', q'[VARCHAR2(50)]' from dual
  ) loop
    begin
      select count(*) into qtd from all_tab_columns
       where owner = 'POSEIDON' and table_name = 'DPC_DFE_EXECUCAO'
         and column_name = upper(c.nome);
      if qtd = 0 then
        execute immediate 'alter table poseidon.dpc_dfe_execucao add (' || c.nome || ' ' || c.def || ')';
        dbms_output.put_line('DPC_DFE_EXECUCAO: acrescentada -> ' || c.nome);
      end if;
    exception
      when others then
        dbms_output.put_line('DPC_DFE_EXECUCAO: FALHOU em ' || c.nome || ' -> ' || sqlerrm);
    end;
  end loop;
end;

-- ---------- DPC_DFE_DOCUMENTO ----------
declare
  qtd number;
begin
  for c in (
    select 'cod_dfe_documento' as nome, q'[NUMBER not null]' as def from dual union all
    select 'cod_dfe_cursor', q'[NUMBER not null]' from dual union all
    select 'cod_dfe_empresa', q'[NUMBER not null]' from dual union all
    select 'nro_nsu', q'[NUMBER not null]' from dual union all
    select 'dsc_schema', q'[VARCHAR2(60)]' from dual union all
    select 'dsc_tipo_doc', q'[VARCHAR2(10)]' from dual union all
    select 'chave_nf', q'[VARCHAR2(50)]' from dual union all
    select 'bin_documento', q'[BLOB]' from dual union all
    select 'status_process', q'[VARCHAR2(1) default 'P' not null]' from dual union all
    select 'qtd_tentativa', q'[NUMBER default 0 not null]' from dual union all
    select 'det_erro', q'[VARCHAR2(4000)]' from dual union all
    select 'dta_recebimento', q'[TIMESTAMP(6) default systimestamp not null]' from dual union all
    select 'dta_processado', q'[TIMESTAMP(6)]' from dual
  ) loop
    begin
      select count(*) into qtd from all_tab_columns
       where owner = 'POSEIDON' and table_name = 'DPC_DFE_DOCUMENTO'
         and column_name = upper(c.nome);
      if qtd = 0 then
        execute immediate 'alter table poseidon.dpc_dfe_documento add (' || c.nome || ' ' || c.def || ')';
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
    select 'cod_dfe_nota' as nome, q'[NUMBER not null]' as def from dual union all
    select 'cod_dfe_empresa', q'[NUMBER not null]' from dual union all
    select 'cod_dfe_emitente', q'[NUMBER]' from dual union all
    select 'chave_nf', q'[VARCHAR2(44) not null]' from dual union all
    select 'nro_nsu', q'[NUMBER]' from dual union all
    select 'dsc_tipo_doc', q'[VARCHAR2(10)]' from dual union all
    select 'nro_modelo', q'[NUMBER]' from dual union all
    select 'nro_serie', q'[NUMBER]' from dual union all
    select 'nro_nf', q'[NUMBER]' from dual union all
    select 'tipo_nf', q'[NUMBER]' from dual union all
    select 'vlr_nota', q'[NUMBER]' from dual union all
    select 'vlr_total_produto', q'[NUMBER]' from dual union all
    select 'dta_emissao', q'[DATE]' from dual union all
    select 'dta_recibo', q'[DATE]' from dual union all
    select 'nro_protocolo', q'[VARCHAR2(20)]' from dual union all
    select 'cod_situacao', q'[NUMBER]' from dual union all
    select 'dsc_situacao', q'[VARCHAR2(20)]' from dual union all
    select 'status_manifestacao', q'[VARCHAR2(1) default 'N' not null]' from dual union all
    select 'sig_papel_empresa', q'[VARCHAR2(6)]' from dual union all
    select 'status_recebimento', q'[VARCHAR2(1) default 'N' not null]' from dual union all
    select 'seq_nf_erp', q'[NUMBER]' from dual union all
    select 'dta_entrada_erp', q'[DATE]' from dual union all
    select 'dta_conciliacao', q'[TIMESTAMP(6)]' from dual union all
    select 'sig_estado_erp', q'[VARCHAR2(20)]' from dual union all
    select 'num_estado_erp', q'[NUMBER(1)]' from dual union all
    select 'num_estado_erp_max', q'[NUMBER(1)]' from dual union all
    select 'dta_estado_erp', q'[TIMESTAMP(6)]' from dual union all
    select 'seq_notamestre_erp', q'[NUMBER]' from dual union all
    select 'dta_lancamento_erp', q'[DATE]' from dual union all
    select 'cod_cfop_erp', q'[NUMBER(5)]' from dual union all
    select 'dsc_ocorr_dev_erp', q'[VARCHAR2(5)]' from dual union all
    select 'seq_comprador_erp', q'[NUMBER]' from dual union all
    select 'dsc_comprador_erp', q'[VARCHAR2(40)]' from dual union all
    select 'created_at', q'[DATE default sysdate]' from dual union all
    select 'created_by', q'[VARCHAR2(50)]' from dual union all
    select 'updated_at', q'[DATE]' from dual union all
    select 'updated_by', q'[VARCHAR2(50)]' from dual union all
    select 'dsc_natureza_operacao', q'[VARCHAR2(60)]' from dual union all
    select 'cod_finalidade', q'[NUMBER(1)]' from dual union all
    select 'cod_consumidor_final', q'[NUMBER(1)]' from dual union all
    select 'cod_presenca', q'[NUMBER(1)]' from dual union all
    select 'cod_regime_trib_emit', q'[NUMBER(1)]' from dual union all
    select 'num_inscr_est_st_emit', q'[VARCHAR2(14)]' from dual union all
    select 'dsc_logradouro_emit', q'[VARCHAR2(60)]' from dual union all
    select 'nro_endereco_emit', q'[VARCHAR2(60)]' from dual union all
    select 'dsc_complemento_emit', q'[VARCHAR2(60)]' from dual union all
    select 'dsc_bairro_emit', q'[VARCHAR2(60)]' from dual union all
    select 'cod_municipio_emit', q'[VARCHAR2(7)]' from dual union all
    select 'dsc_municipio_emit', q'[VARCHAR2(60)]' from dual union all
    select 'sig_uf_emit', q'[VARCHAR2(2)]' from dual union all
    select 'num_cep_emit', q'[VARCHAR2(8)]' from dual union all
    select 'num_fone_emit', q'[VARCHAR2(14)]' from dual union all
    select 'num_cnpj_cpf_dest', q'[VARCHAR2(14)]' from dual union all
    select 'num_inscr_estadual_dest', q'[VARCHAR2(14)]' from dual union all
    select 'cod_ind_ie_dest', q'[NUMBER(1)]' from dual union all
    select 'dsc_logradouro_dest', q'[VARCHAR2(60)]' from dual union all
    select 'nro_endereco_dest', q'[VARCHAR2(60)]' from dual union all
    select 'dsc_complemento_dest', q'[VARCHAR2(60)]' from dual union all
    select 'dsc_bairro_dest', q'[VARCHAR2(60)]' from dual union all
    select 'cod_municipio_dest', q'[VARCHAR2(7)]' from dual union all
    select 'dsc_municipio_dest', q'[VARCHAR2(60)]' from dual union all
    select 'sig_uf_dest', q'[VARCHAR2(2)]' from dual union all
    select 'num_cep_dest', q'[VARCHAR2(8)]' from dual union all
    select 'num_fone_dest', q'[VARCHAR2(14)]' from dual union all
    select 'dsc_inf_complementar', q'[CLOB]' from dual union all
    select 'dsc_inf_fisco', q'[VARCHAR2(2000)]' from dual union all
    select 'dsc_nfe_referenciada', q'[VARCHAR2(500)]' from dual union all
    select 'dsc_pedido_compra', q'[VARCHAR2(500)]' from dual union all
    select 'cod_cfop_xml', q'[NUMBER(4)]' from dual
  ) loop
    begin
      select count(*) into qtd from all_tab_columns
       where owner = 'POSEIDON' and table_name = 'DPC_DFE_NOTA'
         and column_name = upper(c.nome);
      if qtd = 0 then
        execute immediate 'alter table poseidon.dpc_dfe_nota add (' || c.nome || ' ' || c.def || ')';
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
    select 'cod_dfe_nota_item' as nome, q'[NUMBER not null]' as def from dual union all
    select 'cod_dfe_nota', q'[NUMBER not null]' from dual union all
    select 'nro_item', q'[NUMBER not null]' from dual union all
    select 'cod_produto', q'[VARCHAR2(60)]' from dual union all
    select 'cod_ean', q'[VARCHAR2(20)]' from dual union all
    select 'dsc_produto', q'[VARCHAR2(120)]' from dual union all
    select 'cod_ncm', q'[VARCHAR2(8)]' from dual union all
    select 'cod_cest', q'[VARCHAR2(7)]' from dual union all
    select 'cod_ex_tipi', q'[VARCHAR2(3)]' from dual union all
    select 'cod_cfop', q'[VARCHAR2(4)]' from dual union all
    select 'cod_beneficio', q'[VARCHAR2(10)]' from dual union all
    select 'sig_unid_com', q'[VARCHAR2(6)]' from dual union all
    select 'qtd_comercial', q'[NUMBER]' from dual union all
    select 'vlr_unit_com', q'[NUMBER]' from dual union all
    select 'vlr_produto', q'[NUMBER]' from dual union all
    select 'sig_unid_trib', q'[VARCHAR2(6)]' from dual union all
    select 'qtd_tributavel', q'[NUMBER]' from dual union all
    select 'vlr_unit_trib', q'[NUMBER]' from dual union all
    select 'vlr_frete', q'[NUMBER]' from dual union all
    select 'vlr_seguro', q'[NUMBER]' from dual union all
    select 'vlr_desconto', q'[NUMBER]' from dual union all
    select 'vlr_outros', q'[NUMBER]' from dual union all
    select 'status_compoe_total', q'[VARCHAR2(1)]' from dual union all
    select 'vlr_item', q'[NUMBER]' from dual union all
    select 'dsc_inf_adic', q'[VARCHAR2(500)]' from dual union all
    select 'cod_cst_icms', q'[VARCHAR2(4)]' from dual union all
    select 'cod_origem', q'[VARCHAR2(1)]' from dual union all
    select 'vlr_bc_icms', q'[NUMBER]' from dual union all
    select 'pct_icms', q'[NUMBER]' from dual union all
    select 'vlr_icms', q'[NUMBER]' from dual union all
    select 'vlr_bc_icms_st', q'[NUMBER]' from dual union all
    select 'vlr_icms_st', q'[NUMBER]' from dual union all
    select 'cod_cst_ipi', q'[VARCHAR2(2)]' from dual union all
    select 'vlr_bc_ipi', q'[NUMBER]' from dual union all
    select 'pct_ipi', q'[NUMBER]' from dual union all
    select 'vlr_ipi', q'[NUMBER]' from dual union all
    select 'cod_cst_pis', q'[VARCHAR2(2)]' from dual union all
    select 'vlr_bc_pis', q'[NUMBER]' from dual union all
    select 'pct_pis', q'[NUMBER]' from dual union all
    select 'vlr_pis', q'[NUMBER]' from dual union all
    select 'cod_cst_cofins', q'[VARCHAR2(2)]' from dual union all
    select 'vlr_bc_cofins', q'[NUMBER]' from dual union all
    select 'pct_cofins', q'[NUMBER]' from dual union all
    select 'vlr_cofins', q'[NUMBER]' from dual union all
    select 'cod_cst_ibscbs', q'[VARCHAR2(3)]' from dual union all
    select 'cod_class_trib', q'[VARCHAR2(6)]' from dual union all
    select 'vlr_bc_ibscbs', q'[NUMBER]' from dual union all
    select 'vlr_ibs', q'[NUMBER]' from dual union all
    select 'vlr_cbs', q'[NUMBER]' from dual union all
    select 'created_at', q'[DATE default sysdate]' from dual union all
    select 'created_by', q'[VARCHAR2(50)]' from dual
  ) loop
    begin
      select count(*) into qtd from all_tab_columns
       where owner = 'POSEIDON' and table_name = 'DPC_DFE_NOTA_ITEM'
         and column_name = upper(c.nome);
      if qtd = 0 then
        execute immediate 'alter table poseidon.dpc_dfe_nota_item add (' || c.nome || ' ' || c.def || ')';
        dbms_output.put_line('DPC_DFE_NOTA_ITEM: acrescentada -> ' || c.nome);
      end if;
    exception
      when others then
        dbms_output.put_line('DPC_DFE_NOTA_ITEM: FALHOU em ' || c.nome || ' -> ' || sqlerrm);
    end;
  end loop;
end;

-- ---------- DPC_DFE_NOTA_TOTAL ----------
declare
  qtd number;
begin
  for c in (
    select 'cod_dfe_nota' as nome, q'[NUMBER not null]' as def from dual union all
    select 'vlr_bc_icms', q'[NUMBER]' from dual union all
    select 'vlr_icms', q'[NUMBER]' from dual union all
    select 'vlr_icms_deson', q'[NUMBER]' from dual union all
    select 'vlr_fcp_uf_dest', q'[NUMBER]' from dual union all
    select 'vlr_icms_uf_dest', q'[NUMBER]' from dual union all
    select 'vlr_icms_uf_remet', q'[NUMBER]' from dual union all
    select 'vlr_fcp', q'[NUMBER]' from dual union all
    select 'vlr_bc_icms_st', q'[NUMBER]' from dual union all
    select 'vlr_icms_st', q'[NUMBER]' from dual union all
    select 'vlr_fcp_st', q'[NUMBER]' from dual union all
    select 'vlr_fcp_st_ret', q'[NUMBER]' from dual union all
    select 'vlr_frete', q'[NUMBER]' from dual union all
    select 'vlr_seguro', q'[NUMBER]' from dual union all
    select 'vlr_desconto', q'[NUMBER]' from dual union all
    select 'vlr_ii', q'[NUMBER]' from dual union all
    select 'vlr_ipi', q'[NUMBER]' from dual union all
    select 'vlr_ipi_devol', q'[NUMBER]' from dual union all
    select 'vlr_pis', q'[NUMBER]' from dual union all
    select 'vlr_cofins', q'[NUMBER]' from dual union all
    select 'vlr_outros', q'[NUMBER]' from dual union all
    select 'vlr_total_tributo', q'[NUMBER]' from dual union all
    select 'vlr_bc_ibscbs', q'[NUMBER]' from dual union all
    select 'vlr_ibs', q'[NUMBER]' from dual union all
    select 'vlr_ibs_uf', q'[NUMBER]' from dual union all
    select 'vlr_ibs_mun', q'[NUMBER]' from dual union all
    select 'vlr_cbs', q'[NUMBER]' from dual union all
    select 'vlr_nota_total', q'[NUMBER]' from dual union all
    select 'created_at', q'[DATE default sysdate not null]' from dual union all
    select 'created_by', q'[VARCHAR2(50)]' from dual union all
    select 'updated_at', q'[DATE]' from dual union all
    select 'updated_by', q'[VARCHAR2(50)]' from dual
  ) loop
    begin
      select count(*) into qtd from all_tab_columns
       where owner = 'POSEIDON' and table_name = 'DPC_DFE_NOTA_TOTAL'
         and column_name = upper(c.nome);
      if qtd = 0 then
        execute immediate 'alter table poseidon.dpc_dfe_nota_total add (' || c.nome || ' ' || c.def || ')';
        dbms_output.put_line('DPC_DFE_NOTA_TOTAL: acrescentada -> ' || c.nome);
      end if;
    exception
      when others then
        dbms_output.put_line('DPC_DFE_NOTA_TOTAL: FALHOU em ' || c.nome || ' -> ' || sqlerrm);
    end;
  end loop;
end;

-- ---------- DPC_DFE_NOTA_TRANSPORTE ----------
declare
  qtd number;
begin
  for c in (
    select 'cod_dfe_nota' as nome, q'[NUMBER not null]' as def from dual union all
    select 'cod_modalidade_frete', q'[NUMBER(1)]' from dual union all
    select 'num_cnpj_cpf_transp', q'[VARCHAR2(14)]' from dual union all
    select 'dsc_razao_transp', q'[VARCHAR2(60)]' from dual union all
    select 'num_inscr_estadual_transp', q'[VARCHAR2(14)]' from dual union all
    select 'dsc_endereco_transp', q'[VARCHAR2(60)]' from dual union all
    select 'dsc_municipio_transp', q'[VARCHAR2(60)]' from dual union all
    select 'sig_uf_transp', q'[VARCHAR2(2)]' from dual union all
    select 'num_placa_veiculo', q'[VARCHAR2(8)]' from dual union all
    select 'sig_uf_veiculo', q'[VARCHAR2(2)]' from dual union all
    select 'num_rntc', q'[VARCHAR2(20)]' from dual union all
    select 'qtd_volume', q'[NUMBER]' from dual union all
    select 'vlr_peso_liquido', q'[NUMBER]' from dual union all
    select 'vlr_peso_bruto', q'[NUMBER]' from dual union all
    select 'dsc_especie_volume', q'[VARCHAR2(1000)]' from dual union all
    select 'dsc_marca_volume', q'[VARCHAR2(1000)]' from dual union all
    select 'dsc_numeracao_volume', q'[VARCHAR2(1000)]' from dual union all
    select 'created_at', q'[DATE default sysdate not null]' from dual union all
    select 'created_by', q'[VARCHAR2(50)]' from dual union all
    select 'updated_at', q'[DATE]' from dual union all
    select 'updated_by', q'[VARCHAR2(50)]' from dual
  ) loop
    begin
      select count(*) into qtd from all_tab_columns
       where owner = 'POSEIDON' and table_name = 'DPC_DFE_NOTA_TRANSPORTE'
         and column_name = upper(c.nome);
      if qtd = 0 then
        execute immediate 'alter table poseidon.dpc_dfe_nota_transporte add (' || c.nome || ' ' || c.def || ')';
        dbms_output.put_line('DPC_DFE_NOTA_TRANSPORTE: acrescentada -> ' || c.nome);
      end if;
    exception
      when others then
        dbms_output.put_line('DPC_DFE_NOTA_TRANSPORTE: FALHOU em ' || c.nome || ' -> ' || sqlerrm);
    end;
  end loop;
end;

-- ---------- DPC_DFE_NOTA_COBRANCA ----------
declare
  qtd number;
begin
  for c in (
    select 'cod_dfe_nota' as nome, q'[NUMBER not null]' as def from dual union all
    select 'num_fatura', q'[VARCHAR2(60)]' from dual union all
    select 'vlr_original', q'[NUMBER]' from dual union all
    select 'vlr_desconto', q'[NUMBER]' from dual union all
    select 'vlr_liquido', q'[NUMBER]' from dual union all
    select 'dsc_forma_pagto', q'[VARCHAR2(200)]' from dual union all
    select 'dsc_indicador_pagto', q'[VARCHAR2(50)]' from dual union all
    select 'vlr_pago', q'[NUMBER]' from dual union all
    select 'vlr_troco', q'[NUMBER]' from dual union all
    select 'created_at', q'[DATE default sysdate not null]' from dual union all
    select 'created_by', q'[VARCHAR2(50)]' from dual union all
    select 'updated_at', q'[DATE]' from dual union all
    select 'updated_by', q'[VARCHAR2(50)]' from dual
  ) loop
    begin
      select count(*) into qtd from all_tab_columns
       where owner = 'POSEIDON' and table_name = 'DPC_DFE_NOTA_COBRANCA'
         and column_name = upper(c.nome);
      if qtd = 0 then
        execute immediate 'alter table poseidon.dpc_dfe_nota_cobranca add (' || c.nome || ' ' || c.def || ')';
        dbms_output.put_line('DPC_DFE_NOTA_COBRANCA: acrescentada -> ' || c.nome);
      end if;
    exception
      when others then
        dbms_output.put_line('DPC_DFE_NOTA_COBRANCA: FALHOU em ' || c.nome || ' -> ' || sqlerrm);
    end;
  end loop;
end;

-- ---------- DPC_DFE_CTE ----------
declare
  qtd number;
begin
  for c in (
    select 'cod_dfe_cte' as nome, q'[NUMBER not null]' as def from dual union all
    select 'cod_dfe_empresa', q'[NUMBER not null]' from dual union all
    select 'chave_cte', q'[VARCHAR2(44) not null]' from dual union all
    select 'nro_nsu', q'[NUMBER]' from dual union all
    select 'dsc_tipo_doc', q'[VARCHAR2(10)]' from dual union all
    select 'nro_modelo', q'[NUMBER]' from dual union all
    select 'nro_serie', q'[NUMBER]' from dual union all
    select 'nro_cte', q'[NUMBER]' from dual union all
    select 'dta_emissao', q'[DATE]' from dual union all
    select 'cod_cfop', q'[VARCHAR2(4)]' from dual union all
    select 'dsc_natureza_oper', q'[VARCHAR2(60)]' from dual union all
    select 'cod_modal', q'[VARCHAR2(2)]' from dual union all
    select 'cod_tipo_servico', q'[VARCHAR2(1)]' from dual union all
    select 'cod_tipo_cte', q'[VARCHAR2(1)]' from dual union all
    select 'dsc_municipio_ini', q'[VARCHAR2(60)]' from dual union all
    select 'sig_uf_ini', q'[VARCHAR2(2)]' from dual union all
    select 'dsc_municipio_fim', q'[VARCHAR2(60)]' from dual union all
    select 'sig_uf_fim', q'[VARCHAR2(2)]' from dual union all
    select 'num_cnpj_emitente', q'[VARCHAR2(14)]' from dual union all
    select 'dsc_razao_emitente', q'[VARCHAR2(120)]' from dual union all
    select 'num_cnpj_remetente', q'[VARCHAR2(14)]' from dual union all
    select 'num_cnpj_expedidor', q'[VARCHAR2(14)]' from dual union all
    select 'num_cnpj_recebedor', q'[VARCHAR2(14)]' from dual union all
    select 'num_cnpj_destinat', q'[VARCHAR2(14)]' from dual union all
    select 'cod_tomador', q'[VARCHAR2(1)]' from dual union all
    select 'sig_papel_empresa', q'[VARCHAR2(6)]' from dual union all
    select 'vlr_prestacao', q'[NUMBER]' from dual union all
    select 'vlr_receber', q'[NUMBER]' from dual union all
    select 'nro_protocolo', q'[VARCHAR2(20)]' from dual union all
    select 'cod_situacao', q'[NUMBER]' from dual union all
    select 'dsc_situacao', q'[VARCHAR2(20)]' from dual union all
    select 'created_at', q'[DATE default sysdate]' from dual union all
    select 'created_by', q'[VARCHAR2(50)]' from dual union all
    select 'updated_at', q'[DATE]' from dual union all
    select 'updated_by', q'[VARCHAR2(50)]' from dual union all
    select 'dsc_razao_remetente', q'[VARCHAR2(120)]' from dual union all
    select 'dsc_razao_destinat', q'[VARCHAR2(120)]' from dual union all
    select 'dsc_razao_expedidor', q'[VARCHAR2(120)]' from dual union all
    select 'dsc_razao_recebedor', q'[VARCHAR2(120)]' from dual union all
    select 'num_cnpj_tomador4', q'[VARCHAR2(14)]' from dual union all
    select 'dsc_razao_tomador4', q'[VARCHAR2(120)]' from dual union all
    select 'cod_cst_icms', q'[VARCHAR2(2)]' from dual union all
    select 'vlr_bc_icms', q'[NUMBER]' from dual union all
    select 'vlr_icms', q'[NUMBER]' from dual union all
    select 'pct_icms', q'[NUMBER]' from dual union all
    select 'dta_autorizacao', q'[DATE]' from dual union all
    select 'chave_cte_complementado', q'[VARCHAR2(44)]' from dual union all
    select 'vlr_ibs_mun', q'[NUMBER]' from dual union all
    select 'vlr_ibs_uf', q'[NUMBER]' from dual union all
    select 'vlr_cbs', q'[NUMBER]' from dual
  ) loop
    begin
      select count(*) into qtd from all_tab_columns
       where owner = 'POSEIDON' and table_name = 'DPC_DFE_CTE'
         and column_name = upper(c.nome);
      if qtd = 0 then
        execute immediate 'alter table poseidon.dpc_dfe_cte add (' || c.nome || ' ' || c.def || ')';
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
    select 'cod_dfe_cte_nfe' as nome, q'[NUMBER not null]' as def from dual union all
    select 'cod_dfe_cte', q'[NUMBER not null]' from dual union all
    select 'chave_nf', q'[VARCHAR2(44) not null]' from dual union all
    select 'created_at', q'[DATE default sysdate]' from dual union all
    select 'created_by', q'[VARCHAR2(50)]' from dual
  ) loop
    begin
      select count(*) into qtd from all_tab_columns
       where owner = 'POSEIDON' and table_name = 'DPC_DFE_CTE_NFE'
         and column_name = upper(c.nome);
      if qtd = 0 then
        execute immediate 'alter table poseidon.dpc_dfe_cte_nfe add (' || c.nome || ' ' || c.def || ')';
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
    select 'cod_dfe_cte_evento' as nome, q'[NUMBER not null]' as def from dual union all
    select 'cod_dfe_empresa', q'[NUMBER not null]' from dual union all
    select 'cod_dfe_cte', q'[NUMBER]' from dual union all
    select 'chave_cte', q'[VARCHAR2(44) not null]' from dual union all
    select 'nro_nsu', q'[NUMBER]' from dual union all
    select 'cod_tipo_evento', q'[VARCHAR2(6)]' from dual union all
    select 'dsc_evento', q'[VARCHAR2(255)]' from dual union all
    select 'nro_seq_evento', q'[NUMBER default 1 not null]' from dual union all
    select 'nro_protocolo', q'[VARCHAR2(20)]' from dual union all
    select 'cod_status', q'[VARCHAR2(5)]' from dual union all
    select 'dsc_motivo', q'[VARCHAR2(255)]' from dual union all
    select 'dta_evento', q'[TIMESTAMP(6)]' from dual union all
    select 'num_cnpj_autor', q'[VARCHAR2(14)]' from dual union all
    select 'dta_entrega', q'[TIMESTAMP(6)]' from dual union all
    select 'num_doc_recebedor', q'[VARCHAR2(60)]' from dual union all
    select 'dsc_nome_recebedor', q'[VARCHAR2(60)]' from dual union all
    select 'dsc_hash_entrega', q'[VARCHAR2(60)]' from dual union all
    select 'chave_mdfe', q'[VARCHAR2(44)]' from dual union all
    select 'created_at', q'[DATE default sysdate]' from dual union all
    select 'created_by', q'[VARCHAR2(50)]' from dual
  ) loop
    begin
      select count(*) into qtd from all_tab_columns
       where owner = 'POSEIDON' and table_name = 'DPC_DFE_CTE_EVENTO'
         and column_name = upper(c.nome);
      if qtd = 0 then
        execute immediate 'alter table poseidon.dpc_dfe_cte_evento add (' || c.nome || ' ' || c.def || ')';
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
    select 'cod_dfe_nfse' as nome, q'[NUMBER not null]' as def from dual union all
    select 'cod_dfe_empresa', q'[NUMBER not null]' from dual union all
    select 'chave_nfse', q'[VARCHAR2(50) not null]' from dual union all
    select 'nro_nsu', q'[NUMBER]' from dual union all
    select 'dsc_tipo_doc', q'[VARCHAR2(10)]' from dual union all
    select 'nro_nfse', q'[VARCHAR2(15)]' from dual union all
    select 'dta_processamento', q'[DATE]' from dual union all
    select 'dta_competencia', q'[DATE]' from dual union all
    select 'cod_situacao', q'[NUMBER]' from dual union all
    select 'dsc_situacao', q'[VARCHAR2(20)]' from dual union all
    select 'sig_papel_empresa', q'[VARCHAR2(6)]' from dual union all
    select 'num_cnpj_cpf_prest', q'[VARCHAR2(14)]' from dual union all
    select 'dsc_razao_prest', q'[VARCHAR2(120)]' from dual union all
    select 'num_insc_munic_prest', q'[VARCHAR2(20)]' from dual union all
    select 'cod_municipio_prest', q'[VARCHAR2(7)]' from dual union all
    select 'sig_uf_prest', q'[VARCHAR2(2)]' from dual union all
    select 'num_cnpj_cpf_toma', q'[VARCHAR2(14)]' from dual union all
    select 'dsc_razao_toma', q'[VARCHAR2(120)]' from dual union all
    select 'cod_municipio_incid', q'[VARCHAR2(7)]' from dual union all
    select 'dsc_municipio_incid', q'[VARCHAR2(60)]' from dual union all
    select 'cod_trib_nacional', q'[VARCHAR2(10)]' from dual union all
    select 'cod_trib_municipal', q'[VARCHAR2(20)]' from dual union all
    select 'dsc_servico', q'[VARCHAR2(2000)]' from dual union all
    select 'vlr_servico', q'[NUMBER]' from dual union all
    select 'vlr_base_calculo', q'[NUMBER]' from dual union all
    select 'pct_aliquota', q'[NUMBER]' from dual union all
    select 'vlr_issqn', q'[NUMBER]' from dual union all
    select 'vlr_retido', q'[NUMBER]' from dual union all
    select 'vlr_liquido', q'[NUMBER]' from dual union all
    select 'created_at', q'[DATE default sysdate]' from dual union all
    select 'created_by', q'[VARCHAR2(50)]' from dual union all
    select 'updated_at', q'[DATE]' from dual union all
    select 'updated_by', q'[VARCHAR2(50)]' from dual union all
    select 'cod_tipo_emissao', q'[NUMBER(3)]' from dual union all
    select 'dsc_tipo_emissao', q'[VARCHAR2(40)]' from dual union all
    select 'dta_emissao', q'[DATE]' from dual union all
    select 'dta_cancelamento', q'[DATE]' from dual union all
    select 'chave_nfse_substituta', q'[VARCHAR2(50)]' from dual union all
    select 'dsc_local_emissao', q'[VARCHAR2(150)]' from dual union all
    select 'dsc_local_prestacao', q'[VARCHAR2(150)]' from dual union all
    select 'dsc_logradouro_prest', q'[VARCHAR2(255)]' from dual union all
    select 'nro_endereco_prest', q'[VARCHAR2(60)]' from dual union all
    select 'dsc_complemento_prest', q'[VARCHAR2(156)]' from dual union all
    select 'dsc_bairro_prest', q'[VARCHAR2(60)]' from dual union all
    select 'num_cep_prest', q'[VARCHAR2(8)]' from dual
  ) loop
    begin
      select count(*) into qtd from all_tab_columns
       where owner = 'POSEIDON' and table_name = 'DPC_DFE_NFSE'
         and column_name = upper(c.nome);
      if qtd = 0 then
        execute immediate 'alter table poseidon.dpc_dfe_nfse add (' || c.nome || ' ' || c.def || ')';
        dbms_output.put_line('DPC_DFE_NFSE: acrescentada -> ' || c.nome);
      end if;
    exception
      when others then
        dbms_output.put_line('DPC_DFE_NFSE: FALHOU em ' || c.nome || ' -> ' || sqlerrm);
    end;
  end loop;
end;

-- ---------- DPC_DFE_EVENTO ----------
declare
  qtd number;
begin
  for c in (
    select 'cod_dfe_evento' as nome, q'[NUMBER not null]' as def from dual union all
    select 'cod_dfe_empresa', q'[NUMBER not null]' from dual union all
    select 'cod_dfe_nota', q'[NUMBER]' from dual union all
    select 'chave_nf', q'[VARCHAR2(44) not null]' from dual union all
    select 'nro_nsu', q'[NUMBER]' from dual union all
    select 'cod_tipo_evento', q'[VARCHAR2(6)]' from dual union all
    select 'dsc_evento', q'[VARCHAR2(255)]' from dual union all
    select 'nro_seq_evento', q'[NUMBER default 1 not null]' from dual union all
    select 'nro_protocolo', q'[VARCHAR2(20)]' from dual union all
    select 'cod_status', q'[VARCHAR2(5)]' from dual union all
    select 'dsc_motivo', q'[VARCHAR2(255)]' from dual union all
    select 'dta_evento', q'[TIMESTAMP(6)]' from dual union all
    select 'created_at', q'[DATE default sysdate]' from dual union all
    select 'created_by', q'[VARCHAR2(50)]' from dual
  ) loop
    begin
      select count(*) into qtd from all_tab_columns
       where owner = 'POSEIDON' and table_name = 'DPC_DFE_EVENTO'
         and column_name = upper(c.nome);
      if qtd = 0 then
        execute immediate 'alter table poseidon.dpc_dfe_evento add (' || c.nome || ' ' || c.def || ')';
        dbms_output.put_line('DPC_DFE_EVENTO: acrescentada -> ' || c.nome);
      end if;
    exception
      when others then
        dbms_output.put_line('DPC_DFE_EVENTO: FALHOU em ' || c.nome || ' -> ' || sqlerrm);
    end;
  end loop;
end;

-- ---------- DPC_DFE_MANIF_PEDIDO ----------
declare
  qtd number;
begin
  for c in (
    select 'cod_dfe_manif_pedido' as nome, q'[NUMBER generated by default as identity not null]' as def from dual union all
    select 'cod_tipo_evento', q'[VARCHAR2(6) not null]' from dual union all
    select 'usuario', q'[VARCHAR2(100) not null]' from dual union all
    select 'qtd_solicitada', q'[NUMBER not null]' from dual union all
    select 'qtd_aceita', q'[NUMBER not null]' from dual union all
    select 'qtd_recusada', q'[NUMBER not null]' from dual union all
    select 'status_pedido', q'[VARCHAR2(1) default 'A' not null]' from dual union all
    select 'usuario_cancelamento', q'[VARCHAR2(100)]' from dual union all
    select 'dta_cancelamento', q'[DATE]' from dual union all
    select 'created_at', q'[DATE default sysdate not null]' from dual
  ) loop
    begin
      select count(*) into qtd from all_tab_columns
       where owner = 'POSEIDON' and table_name = 'DPC_DFE_MANIF_PEDIDO'
         and column_name = upper(c.nome);
      if qtd = 0 then
        execute immediate 'alter table poseidon.dpc_dfe_manif_pedido add (' || c.nome || ' ' || c.def || ')';
        dbms_output.put_line('DPC_DFE_MANIF_PEDIDO: acrescentada -> ' || c.nome);
      end if;
    exception
      when others then
        dbms_output.put_line('DPC_DFE_MANIF_PEDIDO: FALHOU em ' || c.nome || ' -> ' || sqlerrm);
    end;
  end loop;
end;

-- ---------- DPC_DFE_MANIFESTACAO ----------
declare
  qtd number;
begin
  for c in (
    select 'cod_dfe_manifestacao' as nome, q'[NUMBER not null]' as def from dual union all
    select 'cod_dfe_nota', q'[NUMBER not null]' from dual union all
    select 'cod_tipo_evento', q'[VARCHAR2(6) not null]' from dual union all
    select 'status_envio', q'[VARCHAR2(1) default 'P' not null]' from dual union all
    select 'cod_status_retorno', q'[VARCHAR2(5)]' from dual union all
    select 'dsc_status_retorno', q'[VARCHAR2(255)]' from dual union all
    select 'nro_protocolo', q'[VARCHAR2(20)]' from dual union all
    select 'qtd_tentativa', q'[NUMBER default 0 not null]' from dual union all
    select 'det_erro', q'[VARCHAR2(4000)]' from dual union all
    select 'xml_retorno', q'[CLOB]' from dual union all
    select 'dta_envio', q'[TIMESTAMP(6)]' from dual union all
    select 'dta_ultima_tentativa', q'[TIMESTAMP(6)]' from dual union all
    select 'dta_atualizacao', q'[TIMESTAMP(6)]' from dual union all
    select 'created_at', q'[DATE default sysdate]' from dual union all
    select 'created_by', q'[VARCHAR2(50)]' from dual union all
    select 'nro_seq_evento', q'[NUMBER default 1 not null]' from dual union all
    select 'dsc_justificativa', q'[VARCHAR2(255)]' from dual union all
    select 'dta_registro_evento', q'[TIMESTAMP(6)]' from dual union all
    select 'cod_dfe_empresa', q'[NUMBER]' from dual union all
    select 'dsc_id_lote', q'[VARCHAR2(20)]' from dual union all
    select 'dta_proxima_tentativa', q'[TIMESTAMP(6)]' from dual union all
    select 'cod_dfe_manif_pedido', q'[NUMBER]' from dual
  ) loop
    begin
      select count(*) into qtd from all_tab_columns
       where owner = 'POSEIDON' and table_name = 'DPC_DFE_MANIFESTACAO'
         and column_name = upper(c.nome);
      if qtd = 0 then
        execute immediate 'alter table poseidon.dpc_dfe_manifestacao add (' || c.nome || ' ' || c.def || ')';
        dbms_output.put_line('DPC_DFE_MANIFESTACAO: acrescentada -> ' || c.nome);
      end if;
    exception
      when others then
        dbms_output.put_line('DPC_DFE_MANIFESTACAO: FALHOU em ' || c.nome || ' -> ' || sqlerrm);
    end;
  end loop;
end;

-- ###########################################################################
--  4. CONSTRAINTS
--  CHECK e UNIQUE sao CONVERGENTES: se a definicao no banco difere da deste arquivo, a constraint e derrubada
--  e recriada (uma UK que ganhou coluna, um CHECK que aceitou valor novo). PK e FK so sao criadas se faltarem.
--
--  Ausencias DELIBERADAS, cada uma com historia:
--   DPC_DFE_EMPRESA_CK1 - era sobre status_sincronismo, coluna que saiu desta tabela para DPC_DFE_CURSOR.
--   DPC_DFE_DOCUMENTO_UK1 (empresa, nsu) - substituida pela UK2 (cursor, nsu).
--
--  DPC_DFE_CTE_CK1 registra um detalhe do CT-e: os papeis aceitos sao REM, EXPED, RECEB, DEST, TOMA e OUTRO - NAO
--  existe EMIT. Quando a propria DPC emite o CT-e, o CNPJ nao aparece em nenhum dos quatro papeis que o parser
--  le, e a linha fica como OUTRO.
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
  v_cols varchar2(4000);
begin
  select listagg(column_name, ',') within group (order by position) into v_cols from all_cons_columns
   where owner = 'POSEIDON' and constraint_name = 'DPC_DFE_EMPRESA_UK1';
  if v_cols is null then
    execute immediate q'[alter table poseidon.dpc_dfe_empresa add constraint DPC_DFE_EMPRESA_UK1 unique (num_cnpj) using index tablespace TSD_POSEIDON]';
  elsif v_cols <> 'NUM_CNPJ' then
    execute immediate 'alter table poseidon.dpc_dfe_empresa drop constraint DPC_DFE_EMPRESA_UK1';
    execute immediate q'[alter table poseidon.dpc_dfe_empresa add constraint DPC_DFE_EMPRESA_UK1 unique (num_cnpj) using index tablespace TSD_POSEIDON]';
    dbms_output.put_line('DPC_DFE_EMPRESA_UK1: redefinida' );
  end if;
end;

declare
  v_cond varchar2(4000);
begin
  select search_condition_vc into v_cond from all_constraints
   where owner = 'POSEIDON' and constraint_name = 'DPC_DFE_EMPRESA_CK2';
  if lower(regexp_replace(v_cond, '[[:space:]]', '')) <> q'[status_manifestarin('n','s')]' then
    execute immediate 'alter table poseidon.dpc_dfe_empresa drop constraint DPC_DFE_EMPRESA_CK2';
    execute immediate q'[alter table poseidon.dpc_dfe_empresa add constraint DPC_DFE_EMPRESA_CK2 check (status_manifestar in ('N','S'))]';
    dbms_output.put_line('DPC_DFE_EMPRESA_CK2: redefinida' );
  end if;
exception
  when no_data_found then
    execute immediate q'[alter table poseidon.dpc_dfe_empresa add constraint DPC_DFE_EMPRESA_CK2 check (status_manifestar in ('N','S'))]';
end;

declare
  v_cond varchar2(4000);
begin
  select search_condition_vc into v_cond from all_constraints
   where owner = 'POSEIDON' and constraint_name = 'DPC_DFE_EMPRESA_CK3';
  if lower(regexp_replace(v_cond, '[[:space:]]', '')) <> q'[status_manif_auto_cienciain('n','s')]' then
    execute immediate 'alter table poseidon.dpc_dfe_empresa drop constraint DPC_DFE_EMPRESA_CK3';
    execute immediate q'[alter table poseidon.dpc_dfe_empresa add constraint DPC_DFE_EMPRESA_CK3 check (status_manif_auto_ciencia in ('N','S'))]';
    dbms_output.put_line('DPC_DFE_EMPRESA_CK3: redefinida' );
  end if;
exception
  when no_data_found then
    execute immediate q'[alter table poseidon.dpc_dfe_empresa add constraint DPC_DFE_EMPRESA_CK3 check (status_manif_auto_ciencia in ('N','S'))]';
end;

declare
  v_cond varchar2(4000);
begin
  select search_condition_vc into v_cond from all_constraints
   where owner = 'POSEIDON' and constraint_name = 'DPC_DFE_EMPRESA_CK4';
  if lower(regexp_replace(v_cond, '[[:space:]]', '')) <> q'[status_manif_auto_confirmacaoin('n','s')]' then
    execute immediate 'alter table poseidon.dpc_dfe_empresa drop constraint DPC_DFE_EMPRESA_CK4';
    execute immediate q'[alter table poseidon.dpc_dfe_empresa add constraint DPC_DFE_EMPRESA_CK4 check (status_manif_auto_confirmacao in ('N','S'))]';
    dbms_output.put_line('DPC_DFE_EMPRESA_CK4: redefinida' );
  end if;
exception
  when no_data_found then
    execute immediate q'[alter table poseidon.dpc_dfe_empresa add constraint DPC_DFE_EMPRESA_CK4 check (status_manif_auto_confirmacao in ('N','S'))]';
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
  v_cols varchar2(4000);
begin
  select listagg(column_name, ',') within group (order by position) into v_cols from all_cons_columns
   where owner = 'POSEIDON' and constraint_name = 'DPC_DFE_CURSOR_UK1';
  if v_cols is null then
    execute immediate q'[alter table poseidon.dpc_dfe_cursor add constraint DPC_DFE_CURSOR_UK1 unique (cod_dfe_empresa, cod_tipo_dfe) using index tablespace TSD_POSEIDON]';
  elsif v_cols <> 'COD_DFE_EMPRESA,COD_TIPO_DFE' then
    execute immediate 'alter table poseidon.dpc_dfe_cursor drop constraint DPC_DFE_CURSOR_UK1';
    execute immediate q'[alter table poseidon.dpc_dfe_cursor add constraint DPC_DFE_CURSOR_UK1 unique (cod_dfe_empresa, cod_tipo_dfe) using index tablespace TSD_POSEIDON]';
    dbms_output.put_line('DPC_DFE_CURSOR_UK1: redefinida' );
  end if;
end;

declare
  v_cond varchar2(4000);
begin
  select search_condition_vc into v_cond from all_constraints
   where owner = 'POSEIDON' and constraint_name = 'DPC_DFE_CURSOR_CK1';
  if lower(regexp_replace(v_cond, '[[:space:]]', '')) <> q'[cod_tipo_dfein('nfe','cte','mdfe','nfse')]' then
    execute immediate 'alter table poseidon.dpc_dfe_cursor drop constraint DPC_DFE_CURSOR_CK1';
    execute immediate q'[alter table poseidon.dpc_dfe_cursor add constraint DPC_DFE_CURSOR_CK1 check (cod_tipo_dfe in ('NFE','CTE','MDFE','NFSE'))]';
    dbms_output.put_line('DPC_DFE_CURSOR_CK1: redefinida' );
  end if;
exception
  when no_data_found then
    execute immediate q'[alter table poseidon.dpc_dfe_cursor add constraint DPC_DFE_CURSOR_CK1 check (cod_tipo_dfe in ('NFE','CTE','MDFE','NFSE'))]';
end;

declare
  v_cond varchar2(4000);
begin
  select search_condition_vc into v_cond from all_constraints
   where owner = 'POSEIDON' and constraint_name = 'DPC_DFE_CURSOR_CK2';
  if lower(regexp_replace(v_cond, '[[:space:]]', '')) <> q'[status_sincronismoin('a','p','b','c')]' then
    execute immediate 'alter table poseidon.dpc_dfe_cursor drop constraint DPC_DFE_CURSOR_CK2';
    execute immediate q'[alter table poseidon.dpc_dfe_cursor add constraint DPC_DFE_CURSOR_CK2 check (status_sincronismo in ('A','P','B','C'))]';
    dbms_output.put_line('DPC_DFE_CURSOR_CK2: redefinida' );
  end if;
exception
  when no_data_found then
    execute immediate q'[alter table poseidon.dpc_dfe_cursor add constraint DPC_DFE_CURSOR_CK2 check (status_sincronismo in ('A','P','B','C'))]';
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
   where owner = 'POSEIDON' and constraint_name = 'DPC_DFE_EMITENTE_PK';
  if qtd = 0 then
    execute immediate q'[alter table poseidon.dpc_dfe_emitente add constraint DPC_DFE_EMITENTE_PK primary key (cod_dfe_emitente) using index tablespace TSD_POSEIDON]';
  end if;
end;

declare
  v_cols varchar2(4000);
begin
  select listagg(column_name, ',') within group (order by position) into v_cols from all_cons_columns
   where owner = 'POSEIDON' and constraint_name = 'DPC_DFE_EMITENTE_UK1';
  if v_cols is null then
    execute immediate q'[alter table poseidon.dpc_dfe_emitente add constraint DPC_DFE_EMITENTE_UK1 unique (num_cnpj_cpf) using index tablespace TSD_POSEIDON]';
  elsif v_cols <> 'NUM_CNPJ_CPF' then
    execute immediate 'alter table poseidon.dpc_dfe_emitente drop constraint DPC_DFE_EMITENTE_UK1';
    execute immediate q'[alter table poseidon.dpc_dfe_emitente add constraint DPC_DFE_EMITENTE_UK1 unique (num_cnpj_cpf) using index tablespace TSD_POSEIDON]';
    dbms_output.put_line('DPC_DFE_EMITENTE_UK1: redefinida' );
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
   where owner = 'POSEIDON' and constraint_name = 'DPC_DFE_DOCUMENTO_PK';
  if qtd = 0 then
    execute immediate q'[alter table poseidon.dpc_dfe_documento add constraint DPC_DFE_DOCUMENTO_PK primary key (cod_dfe_documento) using index tablespace TSD_POSEIDON]';
  end if;
end;

declare
  v_cols varchar2(4000);
begin
  select listagg(column_name, ',') within group (order by position) into v_cols from all_cons_columns
   where owner = 'POSEIDON' and constraint_name = 'DPC_DFE_DOCUMENTO_UK2';
  if v_cols is null then
    execute immediate q'[alter table poseidon.dpc_dfe_documento add constraint DPC_DFE_DOCUMENTO_UK2 unique (cod_dfe_cursor, nro_nsu) using index tablespace TSD_POSEIDON]';
  elsif v_cols <> 'COD_DFE_CURSOR,NRO_NSU' then
    execute immediate 'alter table poseidon.dpc_dfe_documento drop constraint DPC_DFE_DOCUMENTO_UK2';
    execute immediate q'[alter table poseidon.dpc_dfe_documento add constraint DPC_DFE_DOCUMENTO_UK2 unique (cod_dfe_cursor, nro_nsu) using index tablespace TSD_POSEIDON]';
    dbms_output.put_line('DPC_DFE_DOCUMENTO_UK2: redefinida' );
  end if;
end;

declare
  v_cond varchar2(4000);
begin
  select search_condition_vc into v_cond from all_constraints
   where owner = 'POSEIDON' and constraint_name = 'DPC_DFE_DOCUMENTO_CK1';
  if lower(regexp_replace(v_cond, '[[:space:]]', '')) <> q'[status_processin('p','a','c','e','i')]' then
    execute immediate 'alter table poseidon.dpc_dfe_documento drop constraint DPC_DFE_DOCUMENTO_CK1';
    execute immediate q'[alter table poseidon.dpc_dfe_documento add constraint DPC_DFE_DOCUMENTO_CK1 check (status_process in ('P','A','C','E','I'))]';
    dbms_output.put_line('DPC_DFE_DOCUMENTO_CK1: redefinida' );
  end if;
exception
  when no_data_found then
    execute immediate q'[alter table poseidon.dpc_dfe_documento add constraint DPC_DFE_DOCUMENTO_CK1 check (status_process in ('P','A','C','E','I'))]';
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
   where owner = 'POSEIDON' and constraint_name = 'DPC_DFE_NOTA_PK';
  if qtd = 0 then
    execute immediate q'[alter table poseidon.dpc_dfe_nota add constraint DPC_DFE_NOTA_PK primary key (cod_dfe_nota) using index tablespace TSD_POSEIDON]';
  end if;
end;

declare
  v_cols varchar2(4000);
begin
  select listagg(column_name, ',') within group (order by position) into v_cols from all_cons_columns
   where owner = 'POSEIDON' and constraint_name = 'DPC_DFE_NOTA_UK1';
  if v_cols is null then
    execute immediate q'[alter table poseidon.dpc_dfe_nota add constraint DPC_DFE_NOTA_UK1 unique (cod_dfe_empresa, chave_nf) using index tablespace TSD_POSEIDON]';
  elsif v_cols <> 'COD_DFE_EMPRESA,CHAVE_NF' then
    execute immediate 'alter table poseidon.dpc_dfe_nota drop constraint DPC_DFE_NOTA_UK1';
    execute immediate q'[alter table poseidon.dpc_dfe_nota add constraint DPC_DFE_NOTA_UK1 unique (cod_dfe_empresa, chave_nf) using index tablespace TSD_POSEIDON]';
    dbms_output.put_line('DPC_DFE_NOTA_UK1: redefinida' );
  end if;
end;

declare
  v_cond varchar2(4000);
begin
  select search_condition_vc into v_cond from all_constraints
   where owner = 'POSEIDON' and constraint_name = 'DPC_DFE_NOTA_CK1';
  if lower(regexp_replace(v_cond, '[[:space:]]', '')) <> q'[status_manifestacaoin('n','c','x')]' then
    execute immediate 'alter table poseidon.dpc_dfe_nota drop constraint DPC_DFE_NOTA_CK1';
    execute immediate q'[alter table poseidon.dpc_dfe_nota add constraint DPC_DFE_NOTA_CK1 check (status_manifestacao in ('N','C','X'))]';
    dbms_output.put_line('DPC_DFE_NOTA_CK1: redefinida' );
  end if;
exception
  when no_data_found then
    execute immediate q'[alter table poseidon.dpc_dfe_nota add constraint DPC_DFE_NOTA_CK1 check (status_manifestacao in ('N','C','X'))]';
end;

declare
  v_cond varchar2(4000);
begin
  select search_condition_vc into v_cond from all_constraints
   where owner = 'POSEIDON' and constraint_name = 'DPC_DFE_NOTA_CK2';
  if lower(regexp_replace(v_cond, '[[:space:]]', '')) <> q'[status_recebimentoin('n','s')]' then
    execute immediate 'alter table poseidon.dpc_dfe_nota drop constraint DPC_DFE_NOTA_CK2';
    execute immediate q'[alter table poseidon.dpc_dfe_nota add constraint DPC_DFE_NOTA_CK2 check (status_recebimento in ('N','S'))]';
    dbms_output.put_line('DPC_DFE_NOTA_CK2: redefinida' );
  end if;
exception
  when no_data_found then
    execute immediate q'[alter table poseidon.dpc_dfe_nota add constraint DPC_DFE_NOTA_CK2 check (status_recebimento in ('N','S'))]';
end;

declare
  v_cond varchar2(4000);
begin
  select search_condition_vc into v_cond from all_constraints
   where owner = 'POSEIDON' and constraint_name = 'DPC_DFE_NOTA_CK3';
  if lower(regexp_replace(v_cond, '[[:space:]]', '')) <> q'[sig_papel_empresain('dest','emit','transp','autxml','outro','indef')]' then
    execute immediate 'alter table poseidon.dpc_dfe_nota drop constraint DPC_DFE_NOTA_CK3';
    execute immediate q'[alter table poseidon.dpc_dfe_nota add constraint DPC_DFE_NOTA_CK3 check (sig_papel_empresa in ('DEST','EMIT','TRANSP','AUTXML','OUTRO','INDEF'))]';
    dbms_output.put_line('DPC_DFE_NOTA_CK3: redefinida' );
  end if;
exception
  when no_data_found then
    execute immediate q'[alter table poseidon.dpc_dfe_nota add constraint DPC_DFE_NOTA_CK3 check (sig_papel_empresa in ('DEST','EMIT','TRANSP','AUTXML','OUTRO','INDEF'))]';
end;

declare
  v_cond varchar2(4000);
begin
  select search_condition_vc into v_cond from all_constraints
   where owner = 'POSEIDON' and constraint_name = 'DPC_DFE_NOTA_CK4';
  if lower(regexp_replace(v_cond, '[[:space:]]', '')) <> q'[(sig_estado_erpisnullandnum_estado_erpisnull)or(sig_estado_erp='aguardando_entrada'andnum_estado_erp=0)or(sig_estado_erp='em_digitacao'andnum_estado_erp=1)or(sig_estado_erp='recebida'andnum_estado_erp=2)or(sig_estado_erp='escriturada'andnum_estado_erp=3)]' then
    execute immediate 'alter table poseidon.dpc_dfe_nota drop constraint DPC_DFE_NOTA_CK4';
    execute immediate q'[alter table poseidon.dpc_dfe_nota add constraint DPC_DFE_NOTA_CK4 check ((sig_estado_erp is null and num_estado_erp is null) or (sig_estado_erp = 'AGUARDANDO_ENTRADA' and num_estado_erp = 0) or (sig_estado_erp = 'EM_DIGITACAO' and num_estado_erp = 1) or (sig_estado_erp = 'RECEBIDA' and num_estado_erp = 2) or (sig_estado_erp = 'ESCRITURADA' and num_estado_erp = 3))]';
    dbms_output.put_line('DPC_DFE_NOTA_CK4: redefinida' );
  end if;
exception
  when no_data_found then
    execute immediate q'[alter table poseidon.dpc_dfe_nota add constraint DPC_DFE_NOTA_CK4 check ((sig_estado_erp is null and num_estado_erp is null) or (sig_estado_erp = 'AGUARDANDO_ENTRADA' and num_estado_erp = 0) or (sig_estado_erp = 'EM_DIGITACAO' and num_estado_erp = 1) or (sig_estado_erp = 'RECEBIDA' and num_estado_erp = 2) or (sig_estado_erp = 'ESCRITURADA' and num_estado_erp = 3))]';
end;

declare
  v_cond varchar2(4000);
begin
  select search_condition_vc into v_cond from all_constraints
   where owner = 'POSEIDON' and constraint_name = 'DPC_DFE_NOTA_CK5';
  if lower(regexp_replace(v_cond, '[[:space:]]', '')) <> q'[num_estado_erp_maxisnullornum_estado_erp_maxbetween0and3]' then
    execute immediate 'alter table poseidon.dpc_dfe_nota drop constraint DPC_DFE_NOTA_CK5';
    execute immediate q'[alter table poseidon.dpc_dfe_nota add constraint DPC_DFE_NOTA_CK5 check (num_estado_erp_max is null or num_estado_erp_max between 0 and 3)]';
    dbms_output.put_line('DPC_DFE_NOTA_CK5: redefinida' );
  end if;
exception
  when no_data_found then
    execute immediate q'[alter table poseidon.dpc_dfe_nota add constraint DPC_DFE_NOTA_CK5 check (num_estado_erp_max is null or num_estado_erp_max between 0 and 3)]';
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
   where owner = 'POSEIDON' and constraint_name = 'DPC_DFE_NOTA_ITEM_PK';
  if qtd = 0 then
    execute immediate q'[alter table poseidon.dpc_dfe_nota_item add constraint DPC_DFE_NOTA_ITEM_PK primary key (cod_dfe_nota_item) using index tablespace TSD_POSEIDON]';
  end if;
end;

declare
  v_cols varchar2(4000);
begin
  select listagg(column_name, ',') within group (order by position) into v_cols from all_cons_columns
   where owner = 'POSEIDON' and constraint_name = 'DPC_DFE_NOTA_ITEM_UK1';
  if v_cols is null then
    execute immediate q'[alter table poseidon.dpc_dfe_nota_item add constraint DPC_DFE_NOTA_ITEM_UK1 unique (cod_dfe_nota, nro_item) using index tablespace TSD_POSEIDON]';
  elsif v_cols <> 'COD_DFE_NOTA,NRO_ITEM' then
    execute immediate 'alter table poseidon.dpc_dfe_nota_item drop constraint DPC_DFE_NOTA_ITEM_UK1';
    execute immediate q'[alter table poseidon.dpc_dfe_nota_item add constraint DPC_DFE_NOTA_ITEM_UK1 unique (cod_dfe_nota, nro_item) using index tablespace TSD_POSEIDON]';
    dbms_output.put_line('DPC_DFE_NOTA_ITEM_UK1: redefinida' );
  end if;
end;

declare
  v_cond varchar2(4000);
begin
  select search_condition_vc into v_cond from all_constraints
   where owner = 'POSEIDON' and constraint_name = 'DPC_DFE_NOTA_ITEM_CK1';
  if lower(regexp_replace(v_cond, '[[:space:]]', '')) <> q'[status_compoe_totalin('0','1')]' then
    execute immediate 'alter table poseidon.dpc_dfe_nota_item drop constraint DPC_DFE_NOTA_ITEM_CK1';
    execute immediate q'[alter table poseidon.dpc_dfe_nota_item add constraint DPC_DFE_NOTA_ITEM_CK1 check (status_compoe_total in ('0','1'))]';
    dbms_output.put_line('DPC_DFE_NOTA_ITEM_CK1: redefinida' );
  end if;
exception
  when no_data_found then
    execute immediate q'[alter table poseidon.dpc_dfe_nota_item add constraint DPC_DFE_NOTA_ITEM_CK1 check (status_compoe_total in ('0','1'))]';
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
   where owner = 'POSEIDON' and constraint_name = 'DPC_DFE_NOTA_TOTAL_PK';
  if qtd = 0 then
    execute immediate q'[alter table poseidon.dpc_dfe_nota_total add constraint DPC_DFE_NOTA_TOTAL_PK primary key (cod_dfe_nota) using index tablespace TSD_POSEIDON]';
  end if;
end;

declare
  qtd number;
begin
  select count(*) into qtd from all_constraints
   where owner = 'POSEIDON' and constraint_name = 'DPC_DFE_NOTA_TOTAL_FK1';
  if qtd = 0 then
    execute immediate q'[alter table poseidon.dpc_dfe_nota_total add constraint DPC_DFE_NOTA_TOTAL_FK1 foreign key (cod_dfe_nota) references poseidon.dpc_dfe_nota (cod_dfe_nota)]';
  end if;
end;

declare
  qtd number;
begin
  select count(*) into qtd from all_constraints
   where owner = 'POSEIDON' and constraint_name = 'DPC_DFE_NOTA_TRANSPORTE_PK';
  if qtd = 0 then
    execute immediate q'[alter table poseidon.dpc_dfe_nota_transporte add constraint DPC_DFE_NOTA_TRANSPORTE_PK primary key (cod_dfe_nota) using index tablespace TSD_POSEIDON]';
  end if;
end;

declare
  qtd number;
begin
  select count(*) into qtd from all_constraints
   where owner = 'POSEIDON' and constraint_name = 'DPC_DFE_NOTA_TRANSPORTE_FK1';
  if qtd = 0 then
    execute immediate q'[alter table poseidon.dpc_dfe_nota_transporte add constraint DPC_DFE_NOTA_TRANSPORTE_FK1 foreign key (cod_dfe_nota) references poseidon.dpc_dfe_nota (cod_dfe_nota)]';
  end if;
end;

declare
  qtd number;
begin
  select count(*) into qtd from all_constraints
   where owner = 'POSEIDON' and constraint_name = 'DPC_DFE_NOTA_COBRANCA_PK';
  if qtd = 0 then
    execute immediate q'[alter table poseidon.dpc_dfe_nota_cobranca add constraint DPC_DFE_NOTA_COBRANCA_PK primary key (cod_dfe_nota) using index tablespace TSD_POSEIDON]';
  end if;
end;

declare
  qtd number;
begin
  select count(*) into qtd from all_constraints
   where owner = 'POSEIDON' and constraint_name = 'DPC_DFE_NOTA_COBRANCA_FK1';
  if qtd = 0 then
    execute immediate q'[alter table poseidon.dpc_dfe_nota_cobranca add constraint DPC_DFE_NOTA_COBRANCA_FK1 foreign key (cod_dfe_nota) references poseidon.dpc_dfe_nota (cod_dfe_nota)]';
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
  v_cols varchar2(4000);
begin
  select listagg(column_name, ',') within group (order by position) into v_cols from all_cons_columns
   where owner = 'POSEIDON' and constraint_name = 'DPC_DFE_CTE_UK1';
  if v_cols is null then
    execute immediate q'[alter table poseidon.dpc_dfe_cte add constraint DPC_DFE_CTE_UK1 unique (cod_dfe_empresa, chave_cte) using index tablespace TSD_POSEIDON]';
  elsif v_cols <> 'COD_DFE_EMPRESA,CHAVE_CTE' then
    execute immediate 'alter table poseidon.dpc_dfe_cte drop constraint DPC_DFE_CTE_UK1';
    execute immediate q'[alter table poseidon.dpc_dfe_cte add constraint DPC_DFE_CTE_UK1 unique (cod_dfe_empresa, chave_cte) using index tablespace TSD_POSEIDON]';
    dbms_output.put_line('DPC_DFE_CTE_UK1: redefinida' );
  end if;
end;

declare
  v_cond varchar2(4000);
begin
  select search_condition_vc into v_cond from all_constraints
   where owner = 'POSEIDON' and constraint_name = 'DPC_DFE_CTE_CK1';
  if lower(regexp_replace(v_cond, '[[:space:]]', '')) <> q'[sig_papel_empresain('rem','exped','receb','dest','toma','outro')]' then
    execute immediate 'alter table poseidon.dpc_dfe_cte drop constraint DPC_DFE_CTE_CK1';
    execute immediate q'[alter table poseidon.dpc_dfe_cte add constraint DPC_DFE_CTE_CK1 check (sig_papel_empresa in ('REM','EXPED','RECEB','DEST','TOMA','OUTRO'))]';
    dbms_output.put_line('DPC_DFE_CTE_CK1: redefinida' );
  end if;
exception
  when no_data_found then
    execute immediate q'[alter table poseidon.dpc_dfe_cte add constraint DPC_DFE_CTE_CK1 check (sig_papel_empresa in ('REM','EXPED','RECEB','DEST','TOMA','OUTRO'))]';
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
   where owner = 'POSEIDON' and constraint_name = 'DPC_DFE_CTE_NFE_PK';
  if qtd = 0 then
    execute immediate q'[alter table poseidon.dpc_dfe_cte_nfe add constraint DPC_DFE_CTE_NFE_PK primary key (cod_dfe_cte_nfe) using index tablespace TSD_POSEIDON]';
  end if;
end;

declare
  v_cols varchar2(4000);
begin
  select listagg(column_name, ',') within group (order by position) into v_cols from all_cons_columns
   where owner = 'POSEIDON' and constraint_name = 'DPC_DFE_CTE_NFE_UK1';
  if v_cols is null then
    execute immediate q'[alter table poseidon.dpc_dfe_cte_nfe add constraint DPC_DFE_CTE_NFE_UK1 unique (cod_dfe_cte, chave_nf) using index tablespace TSD_POSEIDON]';
  elsif v_cols <> 'COD_DFE_CTE,CHAVE_NF' then
    execute immediate 'alter table poseidon.dpc_dfe_cte_nfe drop constraint DPC_DFE_CTE_NFE_UK1';
    execute immediate q'[alter table poseidon.dpc_dfe_cte_nfe add constraint DPC_DFE_CTE_NFE_UK1 unique (cod_dfe_cte, chave_nf) using index tablespace TSD_POSEIDON]';
    dbms_output.put_line('DPC_DFE_CTE_NFE_UK1: redefinida' );
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
  v_cols varchar2(4000);
begin
  select listagg(column_name, ',') within group (order by position) into v_cols from all_cons_columns
   where owner = 'POSEIDON' and constraint_name = 'DPC_DFE_CTE_EVENTO_UK1';
  if v_cols is null then
    execute immediate q'[alter table poseidon.dpc_dfe_cte_evento add constraint DPC_DFE_CTE_EVENTO_UK1 unique (chave_cte, cod_tipo_evento, nro_seq_evento) using index tablespace TSD_POSEIDON]';
  elsif v_cols <> 'CHAVE_CTE,COD_TIPO_EVENTO,NRO_SEQ_EVENTO' then
    execute immediate 'alter table poseidon.dpc_dfe_cte_evento drop constraint DPC_DFE_CTE_EVENTO_UK1';
    execute immediate q'[alter table poseidon.dpc_dfe_cte_evento add constraint DPC_DFE_CTE_EVENTO_UK1 unique (chave_cte, cod_tipo_evento, nro_seq_evento) using index tablespace TSD_POSEIDON]';
    dbms_output.put_line('DPC_DFE_CTE_EVENTO_UK1: redefinida' );
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
  v_cols varchar2(4000);
begin
  select listagg(column_name, ',') within group (order by position) into v_cols from all_cons_columns
   where owner = 'POSEIDON' and constraint_name = 'DPC_DFE_NFSE_UK1';
  if v_cols is null then
    execute immediate q'[alter table poseidon.dpc_dfe_nfse add constraint DPC_DFE_NFSE_UK1 unique (cod_dfe_empresa, chave_nfse) using index tablespace TSD_POSEIDON]';
  elsif v_cols <> 'COD_DFE_EMPRESA,CHAVE_NFSE' then
    execute immediate 'alter table poseidon.dpc_dfe_nfse drop constraint DPC_DFE_NFSE_UK1';
    execute immediate q'[alter table poseidon.dpc_dfe_nfse add constraint DPC_DFE_NFSE_UK1 unique (cod_dfe_empresa, chave_nfse) using index tablespace TSD_POSEIDON]';
    dbms_output.put_line('DPC_DFE_NFSE_UK1: redefinida' );
  end if;
end;

declare
  v_cond varchar2(4000);
begin
  select search_condition_vc into v_cond from all_constraints
   where owner = 'POSEIDON' and constraint_name = 'DPC_DFE_NFSE_CK1';
  if lower(regexp_replace(v_cond, '[[:space:]]', '')) <> q'[sig_papel_empresain('prest','toma','interm','outro')]' then
    execute immediate 'alter table poseidon.dpc_dfe_nfse drop constraint DPC_DFE_NFSE_CK1';
    execute immediate q'[alter table poseidon.dpc_dfe_nfse add constraint DPC_DFE_NFSE_CK1 check (sig_papel_empresa in ('PREST','TOMA','INTERM','OUTRO'))]';
    dbms_output.put_line('DPC_DFE_NFSE_CK1: redefinida' );
  end if;
exception
  when no_data_found then
    execute immediate q'[alter table poseidon.dpc_dfe_nfse add constraint DPC_DFE_NFSE_CK1 check (sig_papel_empresa in ('PREST','TOMA','INTERM','OUTRO'))]';
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
   where owner = 'POSEIDON' and constraint_name = 'DPC_DFE_EVENTO_PK';
  if qtd = 0 then
    execute immediate q'[alter table poseidon.dpc_dfe_evento add constraint DPC_DFE_EVENTO_PK primary key (cod_dfe_evento) using index tablespace TSD_POSEIDON]';
  end if;
end;

declare
  v_cols varchar2(4000);
begin
  select listagg(column_name, ',') within group (order by position) into v_cols from all_cons_columns
   where owner = 'POSEIDON' and constraint_name = 'DPC_DFE_EVENTO_UK1';
  if v_cols is null then
    execute immediate q'[alter table poseidon.dpc_dfe_evento add constraint DPC_DFE_EVENTO_UK1 unique (chave_nf, cod_tipo_evento, nro_seq_evento) using index tablespace TSD_POSEIDON]';
  elsif v_cols <> 'CHAVE_NF,COD_TIPO_EVENTO,NRO_SEQ_EVENTO' then
    execute immediate 'alter table poseidon.dpc_dfe_evento drop constraint DPC_DFE_EVENTO_UK1';
    execute immediate q'[alter table poseidon.dpc_dfe_evento add constraint DPC_DFE_EVENTO_UK1 unique (chave_nf, cod_tipo_evento, nro_seq_evento) using index tablespace TSD_POSEIDON]';
    dbms_output.put_line('DPC_DFE_EVENTO_UK1: redefinida' );
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
   where owner = 'POSEIDON' and constraint_name = 'DPC_DFE_MANIF_PEDIDO_PK';
  if qtd = 0 then
    execute immediate q'[alter table poseidon.dpc_dfe_manif_pedido add constraint DPC_DFE_MANIF_PEDIDO_PK primary key (cod_dfe_manif_pedido) using index tablespace TSD_POSEIDON]';
  end if;
end;

declare
  v_cond varchar2(4000);
begin
  select search_condition_vc into v_cond from all_constraints
   where owner = 'POSEIDON' and constraint_name = 'DPC_DFE_MANIF_PEDIDO_CK1';
  if lower(regexp_replace(v_cond, '[[:space:]]', '')) <> q'[cod_tipo_eventoin('210210','210200')]' then
    execute immediate 'alter table poseidon.dpc_dfe_manif_pedido drop constraint DPC_DFE_MANIF_PEDIDO_CK1';
    execute immediate q'[alter table poseidon.dpc_dfe_manif_pedido add constraint DPC_DFE_MANIF_PEDIDO_CK1 check (cod_tipo_evento in ('210210', '210200'))]';
    dbms_output.put_line('DPC_DFE_MANIF_PEDIDO_CK1: redefinida' );
  end if;
exception
  when no_data_found then
    execute immediate q'[alter table poseidon.dpc_dfe_manif_pedido add constraint DPC_DFE_MANIF_PEDIDO_CK1 check (cod_tipo_evento in ('210210', '210200'))]';
end;

declare
  v_cond varchar2(4000);
begin
  select search_condition_vc into v_cond from all_constraints
   where owner = 'POSEIDON' and constraint_name = 'DPC_DFE_MANIF_PEDIDO_CK2';
  if lower(regexp_replace(v_cond, '[[:space:]]', '')) <> q'[status_pedidoin('a','c')]' then
    execute immediate 'alter table poseidon.dpc_dfe_manif_pedido drop constraint DPC_DFE_MANIF_PEDIDO_CK2';
    execute immediate q'[alter table poseidon.dpc_dfe_manif_pedido add constraint DPC_DFE_MANIF_PEDIDO_CK2 check (status_pedido in ('A', 'C'))]';
    dbms_output.put_line('DPC_DFE_MANIF_PEDIDO_CK2: redefinida' );
  end if;
exception
  when no_data_found then
    execute immediate q'[alter table poseidon.dpc_dfe_manif_pedido add constraint DPC_DFE_MANIF_PEDIDO_CK2 check (status_pedido in ('A', 'C'))]';
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
  v_cols varchar2(4000);
begin
  select listagg(column_name, ',') within group (order by position) into v_cols from all_cons_columns
   where owner = 'POSEIDON' and constraint_name = 'DPC_DFE_MANIF_UK1';
  if v_cols is null then
    execute immediate q'[alter table poseidon.dpc_dfe_manifestacao add constraint DPC_DFE_MANIF_UK1 unique (cod_dfe_nota, cod_tipo_evento, nro_seq_evento) using index tablespace TSD_POSEIDON]';
  elsif v_cols <> 'COD_DFE_NOTA,COD_TIPO_EVENTO,NRO_SEQ_EVENTO' then
    execute immediate 'alter table poseidon.dpc_dfe_manifestacao drop constraint DPC_DFE_MANIF_UK1';
    execute immediate q'[alter table poseidon.dpc_dfe_manifestacao add constraint DPC_DFE_MANIF_UK1 unique (cod_dfe_nota, cod_tipo_evento, nro_seq_evento) using index tablespace TSD_POSEIDON]';
    dbms_output.put_line('DPC_DFE_MANIF_UK1: redefinida' );
  end if;
end;

declare
  v_cond varchar2(4000);
begin
  select search_condition_vc into v_cond from all_constraints
   where owner = 'POSEIDON' and constraint_name = 'DPC_DFE_MANIF_CK1';
  if lower(regexp_replace(v_cond, '[[:space:]]', '')) <> q'[status_envioin('p','e','f')]' then
    execute immediate 'alter table poseidon.dpc_dfe_manifestacao drop constraint DPC_DFE_MANIF_CK1';
    execute immediate q'[alter table poseidon.dpc_dfe_manifestacao add constraint DPC_DFE_MANIF_CK1 check (status_envio in ('P','E','F'))]';
    dbms_output.put_line('DPC_DFE_MANIF_CK1: redefinida' );
  end if;
exception
  when no_data_found then
    execute immediate q'[alter table poseidon.dpc_dfe_manifestacao add constraint DPC_DFE_MANIF_CK1 check (status_envio in ('P','E','F'))]';
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
   where owner = 'POSEIDON' and constraint_name = 'DPC_DFE_MANIF_FK2';
  if qtd = 0 then
    execute immediate q'[alter table poseidon.dpc_dfe_manifestacao add constraint DPC_DFE_MANIF_FK2 foreign key (cod_dfe_manif_pedido) references poseidon.dpc_dfe_manif_pedido (cod_dfe_manif_pedido)]';
  end if;
end;

-- ###########################################################################
--  5. INDICES
--  Somente os que nao vem de constraint: PK e UK ja criam o seu.
--  FK sem indice faz lock de tabela no filho quando se apaga linha do pai.
-- ###########################################################################
--   fila de elegiveis: quem esta ativo e com cooldown vencido
declare
  qtd number;
begin
  select count(*) into qtd from all_indexes
   where owner = 'POSEIDON' and index_name = 'DPCI_DFE_CURSOR';
  if qtd = 0 then
    execute immediate q'[create index poseidon.DPCI_DFE_CURSOR on poseidon.dpc_dfe_cursor (status_sincronismo, dta_liberado_em) tablespace TSD_POSEIDON]';
  end if;
end;

--   trilha por fluxo. DESC porque a consulta e sempre pelo ciclo mais recente
declare
  qtd number;
begin
  select count(*) into qtd from all_indexes
   where owner = 'POSEIDON' and index_name = 'DPCI_DFE_EXECUCAO_CURSOR';
  if qtd = 0 then
    execute immediate q'[create index poseidon.DPCI_DFE_EXECUCAO_CURSOR on poseidon.dpc_dfe_execucao (cod_dfe_cursor, dta_inicio desc) tablespace TSD_POSEIDON]';
  end if;
end;

--   trilha por estabelecimento
declare
  qtd number;
begin
  select count(*) into qtd from all_indexes
   where owner = 'POSEIDON' and index_name = 'DPC_DFE_EXECUCAO_IX1';
  if qtd = 0 then
    execute immediate q'[create index poseidon.DPC_DFE_EXECUCAO_IX1 on poseidon.dpc_dfe_execucao (cod_dfe_empresa, dta_inicio) tablespace TSD_POSEIDON]';
  end if;
end;

--   fila do bruto, e o alerta de documento parado ha mais de 24h
declare
  qtd number;
begin
  select count(*) into qtd from all_indexes
   where owner = 'POSEIDON' and index_name = 'DPC_DFE_DOCUMENTO_IX1';
  if qtd = 0 then
    execute immediate q'[create index poseidon.DPC_DFE_DOCUMENTO_IX1 on poseidon.dpc_dfe_documento (status_process, dta_recebimento) tablespace TSD_POSEIDON]';
  end if;
end;

--   download do XML pela chave
declare
  qtd number;
begin
  select count(*) into qtd from all_indexes
   where owner = 'POSEIDON' and index_name = 'DPC_DFE_DOCUMENTO_IX2';
  if qtd = 0 then
    execute immediate q'[create index poseidon.DPC_DFE_DOCUMENTO_IX2 on poseidon.dpc_dfe_documento (chave_nf) tablespace TSD_POSEIDON]';
  end if;
end;

--   FK sem indice faz lock de tabela no filho quando se apaga linha do pai, e
--   este filho e o que guarda os BLOB. Tambem serve ao delete por empresa do
--   98/99_rollback. Achado em 09/09/2026 pelo assert "FK sem indice" da
--   validacao, que acusava 1 numa base tida por completa.
declare
  qtd number;
begin
  select count(*) into qtd from all_indexes
   where owner = 'POSEIDON' and index_name = 'DPC_DFE_DOCUMENTO_IX3';
  if qtd = 0 then
    execute immediate q'[create index poseidon.DPC_DFE_DOCUMENTO_IX3 on poseidon.dpc_dfe_documento (cod_dfe_empresa) tablespace TSD_POSEIDON]';
  end if;
end;

declare
  qtd number;
begin
  select count(*) into qtd from all_indexes
   where owner = 'POSEIDON' and index_name = 'DPCI_DFE_NOTA_COMPRADOR';
  if qtd = 0 then
    execute immediate q'[create index poseidon.DPCI_DFE_NOTA_COMPRADOR on poseidon.dpc_dfe_nota (cod_dfe_empresa, seq_comprador_erp) tablespace TSD_POSEIDON]';
  end if;
end;

--   a lista que a contabilidade pede: nota que ainda nao entrou no ERP
declare
  qtd number;
begin
  select count(*) into qtd from all_indexes
   where owner = 'POSEIDON' and index_name = 'DPCI_DFE_NOTA_CONC';
  if qtd = 0 then
    execute immediate q'[create index poseidon.DPCI_DFE_NOTA_CONC on poseidon.dpc_dfe_nota (status_recebimento, dta_emissao) tablespace TSD_POSEIDON]';
  end if;
end;

--   as quatro abas da tela: recorta o mesmo acervo por papel, dentro de um estabelecimento e um periodo
declare
  qtd number;
begin
  select count(*) into qtd from all_indexes
   where owner = 'POSEIDON' and index_name = 'DPCI_DFE_NOTA_PAPEL';
  if qtd = 0 then
    execute immediate q'[create index poseidon.DPCI_DFE_NOTA_PAPEL on poseidon.dpc_dfe_nota (cod_dfe_empresa, sig_papel_empresa, dta_emissao) tablespace TSD_POSEIDON]';
  end if;
end;

--   FK sem indice faz lock de tabela no pai; e tambem o filtro por fornecedor
declare
  qtd number;
begin
  select count(*) into qtd from all_indexes
   where owner = 'POSEIDON' and index_name = 'DPC_DFE_NOTA_IX1';
  if qtd = 0 then
    execute immediate q'[create index poseidon.DPC_DFE_NOTA_IX1 on poseidon.dpc_dfe_nota (cod_dfe_emitente) tablespace TSD_POSEIDON]';
  end if;
end;

--   busca por chave sem informar a empresa - a UK1 tem empresa na frente
declare
  qtd number;
begin
  select count(*) into qtd from all_indexes
   where owner = 'POSEIDON' and index_name = 'DPC_DFE_NOTA_IX2';
  if qtd = 0 then
    execute immediate q'[create index poseidon.DPC_DFE_NOTA_IX2 on poseidon.dpc_dfe_nota (chave_nf) tablespace TSD_POSEIDON]';
  end if;
end;

--   classificacao fiscal e o filtro analitico da tabela. O acesso dominante - itens de uma nota - ja e servido pela UK1, cujo prefixo e cod_dfe_nota
declare
  qtd number;
begin
  select count(*) into qtd from all_indexes
   where owner = 'POSEIDON' and index_name = 'DPCI_DFE_NOTA_ITEM_NCM';
  if qtd = 0 then
    execute immediate q'[create index poseidon.DPCI_DFE_NOTA_ITEM_NCM on poseidon.dpc_dfe_nota_item (cod_ncm) tablespace TSD_POSEIDON]';
  end if;
end;

--   listagem de CT-e por periodo
declare
  qtd number;
begin
  select count(*) into qtd from all_indexes
   where owner = 'POSEIDON' and index_name = 'DPCI_DFE_CTE_EMISSAO';
  if qtd = 0 then
    execute immediate q'[create index poseidon.DPCI_DFE_CTE_EMISSAO on poseidon.dpc_dfe_cte (cod_dfe_empresa, dta_emissao) tablespace TSD_POSEIDON]';
  end if;
end;

--   frete que a DPC contratou (TOMA), separado do que apenas nos cita
declare
  qtd number;
begin
  select count(*) into qtd from all_indexes
   where owner = 'POSEIDON' and index_name = 'DPCI_DFE_CTE_PAPEL';
  if qtd = 0 then
    execute immediate q'[create index poseidon.DPCI_DFE_CTE_PAPEL on poseidon.dpc_dfe_cte (sig_papel_empresa, dta_emissao) tablespace TSD_POSEIDON]';
  end if;
end;

--   caminho inverso: qual frete trouxe esta nota
declare
  qtd number;
begin
  select count(*) into qtd from all_indexes
   where owner = 'POSEIDON' and index_name = 'DPCI_DFE_CTE_NFE_CHAVE';
  if qtd = 0 then
    execute immediate q'[create index poseidon.DPCI_DFE_CTE_NFE_CHAVE on poseidon.dpc_dfe_cte_nfe (chave_nf) tablespace TSD_POSEIDON]';
  end if;
end;

--   comprovante de entrega por periodo - a consulta que motivou a tabela. Nulo na maioria das linhas (so o evento 110180 preenche), e indice Oracle NAO indexa nulo: o indice fica pequeno e serve exatamente a busca util
declare
  qtd number;
begin
  select count(*) into qtd from all_indexes
   where owner = 'POSEIDON' and index_name = 'DPCI_DFE_CTE_EVENTO_ENTR';
  if qtd = 0 then
    execute immediate q'[create index poseidon.DPCI_DFE_CTE_EVENTO_ENTR on poseidon.dpc_dfe_cte_evento (dta_entrega) tablespace TSD_POSEIDON]';
  end if;
end;

--   eventos de um CT-e, e o religamento de orfao
declare
  qtd number;
begin
  select count(*) into qtd from all_indexes
   where owner = 'POSEIDON' and index_name = 'DPC_DFE_CTE_EVENTO_IX1';
  if qtd = 0 then
    execute immediate q'[create index poseidon.DPC_DFE_CTE_EVENTO_IX1 on poseidon.dpc_dfe_cte_evento (cod_dfe_cte) tablespace TSD_POSEIDON]';
  end if;
end;

--   FK sem indice
declare
  qtd number;
begin
  select count(*) into qtd from all_indexes
   where owner = 'POSEIDON' and index_name = 'DPC_DFE_CTE_EVENTO_IX2';
  if qtd = 0 then
    execute immediate q'[create index poseidon.DPC_DFE_CTE_EVENTO_IX2 on poseidon.dpc_dfe_cte_evento (cod_dfe_empresa) tablespace TSD_POSEIDON]';
  end if;
end;

--   fechamento contabil por competencia
declare
  qtd number;
begin
  select count(*) into qtd from all_indexes
   where owner = 'POSEIDON' and index_name = 'DPCI_DFE_NFSE_COMPET';
  if qtd = 0 then
    execute immediate q'[create index poseidon.DPCI_DFE_NFSE_COMPET on poseidon.dpc_dfe_nfse (cod_dfe_empresa, dta_competencia) tablespace TSD_POSEIDON]';
  end if;
end;

--   cobertura do padrao nacional por municipio de incidencia
declare
  qtd number;
begin
  select count(*) into qtd from all_indexes
   where owner = 'POSEIDON' and index_name = 'DPCI_DFE_NFSE_MUNIC';
  if qtd = 0 then
    execute immediate q'[create index poseidon.DPCI_DFE_NFSE_MUNIC on poseidon.dpc_dfe_nfse (cod_municipio_incid) tablespace TSD_POSEIDON]';
  end if;
end;

--   historico por prestador
declare
  qtd number;
begin
  select count(*) into qtd from all_indexes
   where owner = 'POSEIDON' and index_name = 'DPCI_DFE_NFSE_PREST';
  if qtd = 0 then
    execute immediate q'[create index poseidon.DPCI_DFE_NFSE_PREST on poseidon.dpc_dfe_nfse (num_cnpj_cpf_prest, dta_competencia) tablespace TSD_POSEIDON]';
  end if;
end;

--   eventos de uma nota, e o religamento de orfao
declare
  qtd number;
begin
  select count(*) into qtd from all_indexes
   where owner = 'POSEIDON' and index_name = 'DPC_DFE_EVENTO_IX1';
  if qtd = 0 then
    execute immediate q'[create index poseidon.DPC_DFE_EVENTO_IX1 on poseidon.dpc_dfe_evento (cod_dfe_nota) tablespace TSD_POSEIDON]';
  end if;
end;

--   FK sem indice
declare
  qtd number;
begin
  select count(*) into qtd from all_indexes
   where owner = 'POSEIDON' and index_name = 'DPC_DFE_EVENTO_IX2';
  if qtd = 0 then
    execute immediate q'[create index poseidon.DPC_DFE_EVENTO_IX2 on poseidon.dpc_dfe_evento (cod_dfe_empresa) tablespace TSD_POSEIDON]';
  end if;
end;

--   fila de reenvio da manifestacao
declare
  qtd number;
begin
  select count(*) into qtd from all_indexes
   where owner = 'POSEIDON' and index_name = 'DPC_DFE_MANIF_IX1';
  if qtd = 0 then
    execute immediate q'[create index poseidon.DPC_DFE_MANIF_IX1 on poseidon.dpc_dfe_manifestacao (status_envio, dta_ultima_tentativa) tablespace TSD_POSEIDON]';
  end if;
end;

declare
  qtd number;
begin
  select count(*) into qtd from all_indexes
   where owner = 'POSEIDON' and index_name = 'DPC_DFE_MANIF_IX2';
  if qtd = 0 then
    execute immediate q'[create index poseidon.DPC_DFE_MANIF_IX2 on poseidon.dpc_dfe_manifestacao (cod_dfe_manif_pedido, status_envio) tablespace TSD_POSEIDON]';
  end if;
end;

-- ###########################################################################
--  6. TRIGGERS
--  PK por trigger + sequence, padrao do ecossistema DPC: a aplicacao nunca seta a chave. O IF ... IS NULL
--  preserva um valor informado de proposito - necessario em carga (dfe:replicar copia com as MESMAS chaves)
--  e em correcao pontual. CREATE OR REPLACE nao precisa de guarda: reexecutar e inofensivo.
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

create or replace trigger poseidon.dpct_dfe_execucao
  before insert on poseidon.dpc_dfe_execucao
  for each row
begin
  if :new.cod_dfe_execucao is null then
    :new.cod_dfe_execucao := poseidon.dpcs_dfe_execucao.nextval;
  end if;
end dpct_dfe_execucao;

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

create or replace trigger poseidon.dpct_dfe_evento
  before insert on poseidon.dpc_dfe_evento
  for each row
begin
  if :new.cod_dfe_evento is null then
    :new.cod_dfe_evento := poseidon.dpcs_dfe_evento.nextval;
  end if;
end dpct_dfe_evento;

create or replace trigger poseidon.dpct_dfe_manifestacao
  before insert on poseidon.dpc_dfe_manifestacao
  for each row
begin
  if :new.cod_dfe_manifestacao is null then
    :new.cod_dfe_manifestacao := poseidon.dpcs_dfe_manifestacao.nextval;
  end if;
end dpct_dfe_manifestacao;

-- ###########################################################################
--  7. COMENTARIOS
--  Obrigatorios pela convencao do projeto, e nao e burocracia: um SELECT nesta base sem comentario obriga
--  quem chega a ler codigo PHP para saber o que a coluna significa. COMMENT ON e idempotente: reexecutar
--  reescreve igual. Todas as colunas de todas as tabelas deste arquivo estao documentadas.
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
  'N-Nao manifestar | S-Pode manifestar. Chave-mestra da manifestacao da empresa (manual pela tela e base das automaticas). Default S desde 16/10/2026 por decisao do usuario; manifestacao e ato fiscal sem desfazer, entao as flags de automacao seguem N.';
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
comment on column poseidon.dpc_dfe_empresa.status_manif_auto_ciencia is
  'N-Nao | S-Sim. Habilita a Ciencia da Operacao (210210) AUTOMATICA para esta empresa. Exige status_manifestar = S junto: aquele e a chave-mestra, este governa so a automacao. Default N.';
comment on column poseidon.dpc_dfe_empresa.status_manif_auto_confirmacao is
  'N-Nao | S-Sim. Habilita a Confirmacao da Operacao (210200) AUTOMATICA para esta empresa, disparada quando a nota chega a ESCRITURADA no ERP. Exige status_manifestar = S junto. Default N, e so deve ser ligado depois da Ciencia estar estavel na filial piloto: a Confirmacao tem peso declaratorio maior.';
comment on column poseidon.dpc_dfe_empresa.dta_inicio_manif_auto_conf is
  'Data a partir da qual a Confirmacao automatica (210200) passa a considerar as notas desta empresa. NULL = a automacao nao roda, mesmo com status_manif_auto_confirmacao=S (segunda trava). Decisao de 24/09/2026: nao drenar o backlog anterior (707 notas so na empresa 29 dentro do prazo de 90 dias) por automacao, so por acao manual na tela.';

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
comment on column poseidon.dpc_dfe_emitente.dsc_grupo_erp is
  'Grupo do emitente no cadastro de pessoas do ERP (consinco.ge_pessoa.grupo): FORNECEDOR = fornecedor de revenda, FORNECEDOR CONSUMO, CLIENTE... Define a categoria da nota na Gestao de NFe (Compras, Suprimentos ou Devolucao). Nulo = CNPJ nao encontrado no ERP, ou ainda nao conferido (ver dta_conferencia_erp). Gravado pelo dfe:conciliar.';
comment on column poseidon.dpc_dfe_emitente.seq_pessoa_erp is
  'ge_pessoa.seqpessoa do emitente no ERP, para rastrear o cadastro de origem. Nulo quando o CNPJ nao foi encontrado.';
comment on column poseidon.dpc_dfe_emitente.dta_conferencia_erp is
  'Quando o dfe:conciliar conferiu este CNPJ no cadastro do ERP. Nulo = nunca conferido; preenchido com dsc_grupo_erp nulo = conferido e nao encontrado.';
comment on column poseidon.dpc_dfe_emitente.seq_comprador_erp is
  'max_comprador.seqcomprador do comprador do FORNECEDOR no ERP (maf_fornecdivisao, divisao 1, fornecedor e comprador ativos). Gravado pelo dfe:conciliar so quando dsc_grupo_erp e FORNECEDOR ou FORNECEDOR CONSUMO; nulo para os demais grupos e para fornecedor sem comprador.';
comment on column poseidon.dpc_dfe_emitente.dsc_comprador_erp is
  'Nome do comprador do fornecedor no ERP (max_comprador.comprador). E o que a coluna Comprador da Gestao de NFe e da tela NF-e mostra. Nulo quando o emitente nao e fornecedor ou nao tem comprador.';

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
comment on column poseidon.dpc_dfe_nota.dsc_natureza_operacao is
  'Natureza da operacao, como o emitente a descreveu. Tag: ide/natOp.';
comment on column poseidon.dpc_dfe_nota.cod_finalidade is
  '1 normal, 2 complementar, 3 de ajuste, 4 devolucao. Tag: ide/finNFe.';
comment on column poseidon.dpc_dfe_nota.cod_consumidor_final is
  '0 normal, 1 consumidor final. Tag: ide/indFinal.';
comment on column poseidon.dpc_dfe_nota.cod_presenca is
  'Presenca do comprador: 0 nao se aplica, 1 presencial, 2 internet, 3 teleatendimento, 4 entrega a domicilio, 5 presencial fora do estabelecimento, 9 outros. Tag: ide/indPres.';
comment on column poseidon.dpc_dfe_nota.cod_regime_trib_emit is
  'Regime tributario do emitente: 1 Simples Nacional, 2 Simples com excesso de sublimite, 3 Regime Normal, 4 MEI. Tag: emit/CRT.';
comment on column poseidon.dpc_dfe_nota.num_inscr_est_st_emit is
  'IE do substituto tributario do emitente. Em 2% das notas medidas. Tag: emit/IEST.';
comment on column poseidon.dpc_dfe_nota.dsc_logradouro_emit is
  'Logradouro do emitente. Tag: emit/enderEmit/xLgr.';
comment on column poseidon.dpc_dfe_nota.nro_endereco_emit is
  'Numero do endereco do emitente. E TEXTO: o XML traz coisas como ''LOTE Nr.8'' e ''SN''. Tag: emit/enderEmit/nro.';
comment on column poseidon.dpc_dfe_nota.dsc_complemento_emit is
  'Complemento do endereco do emitente. Tag: emit/enderEmit/xCpl.';
comment on column poseidon.dpc_dfe_nota.dsc_bairro_emit is
  'Bairro do emitente. Tag: emit/enderEmit/xBairro.';
comment on column poseidon.dpc_dfe_nota.cod_municipio_emit is
  'Codigo IBGE do municipio do emitente. Tag: emit/enderEmit/cMun.';
comment on column poseidon.dpc_dfe_nota.dsc_municipio_emit is
  'Municipio do emitente. Tag: emit/enderEmit/xMun.';
comment on column poseidon.dpc_dfe_nota.sig_uf_emit is
  'UF do emitente - a ''UF Origem'' da tela. Tag: emit/enderEmit/UF.';
comment on column poseidon.dpc_dfe_nota.num_cep_emit is
  'CEP do emitente, com os zeros a esquerda. Tag: emit/enderEmit/CEP.';
comment on column poseidon.dpc_dfe_nota.num_fone_emit is
  'Telefone do emitente. Fica dentro de enderEmit, NAO em emit. Tag: emit/enderEmit/fone.';
comment on column poseidon.dpc_dfe_nota.num_cnpj_cpf_dest is
  'Destinatario. So digitos. Uma coluna para os dois, como o parser ja faz nas demais partes. Tag: dest/CNPJ ou dest/CPF.';
comment on column poseidon.dpc_dfe_nota.num_inscr_estadual_dest is
  'Inscricao estadual do destinatario. Tag: dest/IE.';
comment on column poseidon.dpc_dfe_nota.cod_ind_ie_dest is
  '1 contribuinte de ICMS, 2 isento, 9 nao contribuinte. Tag: dest/indIEDest.';
comment on column poseidon.dpc_dfe_nota.dsc_logradouro_dest is
  'Logradouro do destinatario. Tag: dest/enderDest/xLgr.';
comment on column poseidon.dpc_dfe_nota.nro_endereco_dest is
  'Numero do endereco do destinatario. E TEXTO. Tag: dest/enderDest/nro.';
comment on column poseidon.dpc_dfe_nota.dsc_complemento_dest is
  'Complemento do endereco do destinatario. Tag: dest/enderDest/xCpl.';
comment on column poseidon.dpc_dfe_nota.dsc_bairro_dest is
  'Bairro do destinatario. Tag: dest/enderDest/xBairro.';
comment on column poseidon.dpc_dfe_nota.cod_municipio_dest is
  'Codigo IBGE do municipio do destinatario - o ''Codigo Destino'' da tela. Tag: dest/enderDest/cMun.';
comment on column poseidon.dpc_dfe_nota.dsc_municipio_dest is
  'Municipio do destinatario. Tag: dest/enderDest/xMun.';
comment on column poseidon.dpc_dfe_nota.sig_uf_dest is
  'UF do destinatario. Tag: dest/enderDest/UF.';
comment on column poseidon.dpc_dfe_nota.num_cep_dest is
  'CEP do destinatario. Tag: dest/enderDest/CEP.';
comment on column poseidon.dpc_dfe_nota.num_fone_dest is
  'Telefone do destinatario. Tag: dest/enderDest/fone.';
comment on column poseidon.dpc_dfe_nota.dsc_inf_complementar is
  'Informacoes complementares de interesse do contribuinte. CLOB porque o leiaute admite 5.000 caracteres - acima do limite de 4.000 do VARCHAR2. Maior medido: 1.809. Tag: infAdic/infCpl.';
comment on column poseidon.dpc_dfe_nota.dsc_inf_fisco is
  'Informacoes de interesse do fisco. Limite do leiaute: 2.000. Em 8% das notas medidas. Tag: infAdic/infAdFisco.';
comment on column poseidon.dpc_dfe_nota.dsc_nfe_referenciada is
  'Chaves das NF-e referenciadas, separadas por virgula. 1:N - ate 2 por nota no medido. Em 24% das notas. Tag: ide/NFref/refNFe.';
comment on column poseidon.dpc_dfe_nota.dsc_pedido_compra is
  'Pedidos de compra distintos citados nos itens, separados por virgula. Em 21% das notas medidas. Tag: det/prod/xPed.';
comment on column poseidon.dpc_dfe_nota.cod_cfop_xml is
  'CFOP do XML: o do item de maior valor (empate: menor item). Nulo = nao calculado ou so resumo. NAO substitui cod_cfop_erp: serve para PREVER a categoria antes da escrituracao.';

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

--  ---------- DPC_DFE_NOTA_TOTAL ----------
comment on table poseidon.dpc_dfe_nota_total is
  'Totais da NF-e (bloco total do XML): ICMS, ST, IPI, PIS, COFINS, frete, seguro e os valores da reforma tributaria. Uma linha por nota, so para NF-e completa (procNF).';
comment on column poseidon.dpc_dfe_nota_total.cod_dfe_nota is
  'PK e FK para DPC_DFE_NOTA: relacao 1:1 (uma linha por nota), sem trigger nem sequence.';
comment on column poseidon.dpc_dfe_nota_total.vlr_bc_icms is
  'Base de calculo do ICMS. Tag: total/ICMSTot/vBC.';
comment on column poseidon.dpc_dfe_nota_total.vlr_icms is
  'Valor do ICMS. Tag: total/ICMSTot/vICMS.';
comment on column poseidon.dpc_dfe_nota_total.vlr_icms_deson is
  'ICMS desonerado. Tag: total/ICMSTot/vICMSDeson.';
comment on column poseidon.dpc_dfe_nota_total.vlr_fcp_uf_dest is
  'FCP retido por ST para a UF de destino (partilha EC 87/2015). Tag: total/ICMSTot/vFCPUFDest.';
comment on column poseidon.dpc_dfe_nota_total.vlr_icms_uf_dest is
  'ICMS de partilha devido a UF de destino. Tag: total/ICMSTot/vICMSUFDest.';
comment on column poseidon.dpc_dfe_nota_total.vlr_icms_uf_remet is
  'ICMS de partilha devido a UF do remetente. Tag: total/ICMSTot/vICMSUFRemet.';
comment on column poseidon.dpc_dfe_nota_total.vlr_fcp is
  'Fundo de Combate a Pobreza. Tag: total/ICMSTot/vFCP.';
comment on column poseidon.dpc_dfe_nota_total.vlr_bc_icms_st is
  'Base de calculo do ICMS por substituicao tributaria. Tag: total/ICMSTot/vBCST.';
comment on column poseidon.dpc_dfe_nota_total.vlr_icms_st is
  'Valor do ICMS por substituicao tributaria. Tag: total/ICMSTot/vST.';
comment on column poseidon.dpc_dfe_nota_total.vlr_fcp_st is
  'FCP retido por substituicao tributaria. Tag: total/ICMSTot/vFCPST.';
comment on column poseidon.dpc_dfe_nota_total.vlr_fcp_st_ret is
  'FCP retido anteriormente por substituicao tributaria. Tag: total/ICMSTot/vFCPSTRet.';
comment on column poseidon.dpc_dfe_nota_total.vlr_frete is
  'Valor do frete. Tag: total/ICMSTot/vFrete.';
comment on column poseidon.dpc_dfe_nota_total.vlr_seguro is
  'Valor do seguro. Tag: total/ICMSTot/vSeg.';
comment on column poseidon.dpc_dfe_nota_total.vlr_desconto is
  'Valor do desconto. Tag: total/ICMSTot/vDesc.';
comment on column poseidon.dpc_dfe_nota_total.vlr_ii is
  'Imposto de importacao. Tag: total/ICMSTot/vII.';
comment on column poseidon.dpc_dfe_nota_total.vlr_ipi is
  'Valor do IPI. Tag: total/ICMSTot/vIPI.';
comment on column poseidon.dpc_dfe_nota_total.vlr_ipi_devol is
  'IPI devolvido. Tag: total/ICMSTot/vIPIDevol.';
comment on column poseidon.dpc_dfe_nota_total.vlr_pis is
  'Valor do PIS. Tag: total/ICMSTot/vPIS.';
comment on column poseidon.dpc_dfe_nota_total.vlr_cofins is
  'Valor da COFINS. Tag: total/ICMSTot/vCOFINS.';
comment on column poseidon.dpc_dfe_nota_total.vlr_outros is
  'Outras despesas acessorias. Tag: total/ICMSTot/vOutro.';
comment on column poseidon.dpc_dfe_nota_total.vlr_total_tributo is
  'Total aproximado de tributos (Lei 12.741/2012). Em 79% das notas medidas. Tag: total/ICMSTot/vTotTrib.';
comment on column poseidon.dpc_dfe_nota_total.vlr_bc_ibscbs is
  'Reforma tributaria: base de calculo de IBS e CBS. Em 94% das notas medidas. Tag: total/IBSCBSTot/vBCIBSCBS.';
comment on column poseidon.dpc_dfe_nota_total.vlr_ibs is
  'Reforma tributaria: total do IBS. Tag: total/IBSCBSTot/gIBS/vIBS.';
comment on column poseidon.dpc_dfe_nota_total.vlr_ibs_uf is
  'Reforma tributaria: parcela estadual do IBS. Tag: total/IBSCBSTot/gIBS/gIBSUF/vIBSUF.';
comment on column poseidon.dpc_dfe_nota_total.vlr_ibs_mun is
  'Reforma tributaria: parcela municipal do IBS. Tag: total/IBSCBSTot/gIBS/gIBSMun/vIBSMun.';
comment on column poseidon.dpc_dfe_nota_total.vlr_cbs is
  'Reforma tributaria: total da CBS. Tag: total/IBSCBSTot/gCBS/vCBS.';
comment on column poseidon.dpc_dfe_nota_total.vlr_nota_total is
  'Total da nota com IBS, CBS e IS. Filho direto de <total>, nao de IBSCBSTot. Em 86% das notas medidas. Tag: total/vNFTot.';
comment on column poseidon.dpc_dfe_nota_total.created_at is
  'Data de inclusao da linha.';
comment on column poseidon.dpc_dfe_nota_total.created_by is
  'Rotina que incluiu a linha (DFE NORMALIZAR).';
comment on column poseidon.dpc_dfe_nota_total.updated_at is
  'Data da ultima alteracao.';
comment on column poseidon.dpc_dfe_nota_total.updated_by is
  'Rotina que alterou a linha por ultimo.';

--  ---------- DPC_DFE_NOTA_TRANSPORTE ----------
comment on table poseidon.dpc_dfe_nota_transporte is
  'Transporte da NF-e (bloco transp): modalidade do frete, transportadora, veiculo e volumes. Os volumes sao 1:N no XML e vem agregados - soma dos pesos e quantidades, lista das especies e marcas.';
comment on column poseidon.dpc_dfe_nota_transporte.cod_dfe_nota is
  'PK e FK para DPC_DFE_NOTA: relacao 1:1 (uma linha por nota), sem trigger nem sequence.';
comment on column poseidon.dpc_dfe_nota_transporte.cod_modalidade_frete is
  '0 por conta do emitente, 1 do destinatario, 2 de terceiros, 3 proprio por conta do remetente, 4 proprio por conta do destinatario, 9 sem frete. Tag: transp/modFrete.';
comment on column poseidon.dpc_dfe_nota_transporte.num_cnpj_cpf_transp is
  'Transportadora. So digitos. Tag: transp/transporta/CNPJ ou CPF.';
comment on column poseidon.dpc_dfe_nota_transporte.dsc_razao_transp is
  'Razao social da transportadora. Tag: transp/transporta/xNome.';
comment on column poseidon.dpc_dfe_nota_transporte.num_inscr_estadual_transp is
  'Inscricao estadual da transportadora. Tag: transp/transporta/IE.';
comment on column poseidon.dpc_dfe_nota_transporte.dsc_endereco_transp is
  'Endereco da transportadora, em uma linha so (e assim no XML). Tag: transp/transporta/xEnder.';
comment on column poseidon.dpc_dfe_nota_transporte.dsc_municipio_transp is
  'Municipio da transportadora. Tag: transp/transporta/xMun.';
comment on column poseidon.dpc_dfe_nota_transporte.sig_uf_transp is
  'UF da transportadora. Tag: transp/transporta/UF.';
comment on column poseidon.dpc_dfe_nota_transporte.num_placa_veiculo is
  'Placa do veiculo. ZERO ocorrencias em 400 notas medidas; existe para o frete proprio, que o acervo ainda nao tem. Tag: transp/veicTransp/placa.';
comment on column poseidon.dpc_dfe_nota_transporte.sig_uf_veiculo is
  'UF de licenciamento do veiculo. Tag: transp/veicTransp/UF.';
comment on column poseidon.dpc_dfe_nota_transporte.num_rntc is
  'Registro Nacional de Transportador de Carga. Tag: transp/veicTransp/RNTC.';
comment on column poseidon.dpc_dfe_nota_transporte.qtd_volume is
  'SOMA dos volumes: o grupo <vol> e 1:N (ate 10 por nota no medido). Tag: soma de transp/vol/qVol.';
comment on column poseidon.dpc_dfe_nota_transporte.vlr_peso_liquido is
  'Soma do peso liquido de todos os volumes. Tag: soma de transp/vol/pesoL.';
comment on column poseidon.dpc_dfe_nota_transporte.vlr_peso_bruto is
  'Soma do peso bruto de todos os volumes. Tag: soma de transp/vol/pesoB.';
comment on column poseidon.dpc_dfe_nota_transporte.dsc_especie_volume is
  'Especies distintas, separadas por virgula. 1000 desde 02/10/2026: uma nota real com 16 especies estourou os 400 originais. Tag: transp/vol/esp.';
comment on column poseidon.dpc_dfe_nota_transporte.dsc_marca_volume is
  'Marcas distintas, separadas por virgula. Tag: transp/vol/marca.';
comment on column poseidon.dpc_dfe_nota_transporte.dsc_numeracao_volume is
  'Numeracoes distintas, separadas por virgula. Tag: transp/vol/nVol.';
comment on column poseidon.dpc_dfe_nota_transporte.created_at is
  'Data de inclusao da linha.';
comment on column poseidon.dpc_dfe_nota_transporte.created_by is
  'Rotina que incluiu a linha (DFE NORMALIZAR).';
comment on column poseidon.dpc_dfe_nota_transporte.updated_at is
  'Data da ultima alteracao.';
comment on column poseidon.dpc_dfe_nota_transporte.updated_by is
  'Rotina que alterou a linha por ultimo.';

--  ---------- DPC_DFE_NOTA_COBRANCA ----------
comment on table poseidon.dpc_dfe_nota_cobranca is
  'Cobranca e pagamento da NF-e (blocos cobr e pag): fatura e formas de pagamento. Os pagamentos sao 1:N no XML e vem agregados.';
comment on column poseidon.dpc_dfe_nota_cobranca.cod_dfe_nota is
  'PK e FK para DPC_DFE_NOTA: relacao 1:1 (uma linha por nota), sem trigger nem sequence.';
comment on column poseidon.dpc_dfe_nota_cobranca.num_fatura is
  'Numero da fatura. Em 24% das notas medidas. Tag: cobr/fat/nFat.';
comment on column poseidon.dpc_dfe_nota_cobranca.vlr_original is
  'Valor original da fatura. Tag: cobr/fat/vOrig.';
comment on column poseidon.dpc_dfe_nota_cobranca.vlr_desconto is
  'Desconto da fatura. Tag: cobr/fat/vDesc.';
comment on column poseidon.dpc_dfe_nota_cobranca.vlr_liquido is
  'Valor liquido da fatura. Tag: cobr/fat/vLiq.';
comment on column poseidon.dpc_dfe_nota_cobranca.dsc_forma_pagto is
  'Formas de pagamento distintas, separadas por virgula (01 dinheiro, 03 cartao de credito, 15 boleto, 90 sem pagamento...). O grupo e 1:N - ate 2 por nota no medido. Tag: pag/detPag/tPag.';
comment on column poseidon.dpc_dfe_nota_cobranca.dsc_indicador_pagto is
  'Indicadores distintos: 0 a vista, 1 a prazo. Tag: pag/detPag/indPag.';
comment on column poseidon.dpc_dfe_nota_cobranca.vlr_pago is
  'Soma dos pagamentos. Tag: soma de pag/detPag/vPag.';
comment on column poseidon.dpc_dfe_nota_cobranca.vlr_troco is
  'Troco. Tag: pag/vTroco.';
comment on column poseidon.dpc_dfe_nota_cobranca.created_at is
  'Data de inclusao da linha.';
comment on column poseidon.dpc_dfe_nota_cobranca.created_by is
  'Rotina que incluiu a linha (DFE NORMALIZAR).';
comment on column poseidon.dpc_dfe_nota_cobranca.updated_at is
  'Data da ultima alteracao.';
comment on column poseidon.dpc_dfe_nota_cobranca.updated_by is
  'Rotina que alterou a linha por ultimo.';

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
comment on column poseidon.dpc_dfe_cte.dsc_razao_remetente is
  'Razao social do remetente. Tag: rem/xNome. Medido em 03/10/2026: 100% de 500 CT-e.';
comment on column poseidon.dpc_dfe_cte.dsc_razao_destinat is
  'Razao social do destinatario. Tag: dest/xNome. Medido: 100% de 500 CT-e.';
comment on column poseidon.dpc_dfe_cte.dsc_razao_expedidor is
  'Razao social do expedidor. Tag: exped/xNome. Medido: 31,6% - o bloco so existe quando ha expedidor. Resolve o nome do TOMADOR quando cod_tomador = 1.';
comment on column poseidon.dpc_dfe_cte.dsc_razao_recebedor is
  'Razao social do recebedor. Tag: receb/xNome. Medido: 30,0%. Resolve o nome do TOMADOR quando cod_tomador = 2.';
comment on column poseidon.dpc_dfe_cte.num_cnpj_tomador4 is
  'CNPJ do tomador quando ele NAO e nenhum dos quatro papeis (cod_tomador = 4). Tag: ide/toma4/CNPJ. Medido: 9,45% dos 54.213 CT-e. Era o unico caso em que a tela nao sabia dizer quem tomou o servico.';
comment on column poseidon.dpc_dfe_cte.dsc_razao_tomador4 is
  'Razao social do tomador avulso. Tag: ide/toma4/xNome. Mesma ocorrencia do num_cnpj_tomador4.';
comment on column poseidon.dpc_dfe_cte.cod_cst_icms is
  'CST do ICMS do servico. Tag: imp/ICMS/<grupo>/CST. Medido: 100% dos blocos ICMS. E ele que explica base e valor vazios: 40 isento (70,2%), 00 tributado (17,2%), 90 Simples ou outra UF (11,8%), 60 ST retido (0,8%).';
comment on column poseidon.dpc_dfe_cte.vlr_bc_icms is
  'Base de calculo do ICMS. Tags: ICMS00/vBC, ICMSOutraUF/vBCOutraUF, ICMS60/vBCSTRet. NULO em 77% POR DESENHO: ICMS45 (isento) e ICMSSN (Simples) nao tem base. Ler junto com cod_cst_icms.';
comment on column poseidon.dpc_dfe_cte.vlr_icms is
  'Valor do ICMS. Tags: ICMS00/vICMS, ICMSOutraUF/vICMSOutraUF, ICMS60/vICMSSTRet. Mesma regra de nulo do vlr_bc_icms.';
comment on column poseidon.dpc_dfe_cte.pct_icms is
  'Aliquota do ICMS em percentual. Tags: ICMS00/pICMS, ICMSOutraUF/pICMSOutraUF, ICMS60/pICMSSTRet. Mesma regra de nulo do vlr_bc_icms.';
comment on column poseidon.dpc_dfe_cte.dta_autorizacao is
  'Data e hora em que a SEFAZ autorizou o CT-e. Tag: protCTe/infProt/dhRecbto. Medido: 100%. NAO e a dta_emissao, que e quando o emitente gerou o documento.';
comment on column poseidon.dpc_dfe_cte.chave_cte_complementado is
  'Chave do CT-e que ESTE complementa. Tag: infCteComp/chCTe - atencao a caixa, e infCteComp e nao infCTeComp. So existe quando cod_tipo_cte = 1: 1.253 CT-e, 2,31% do acervo.';
comment on column poseidon.dpc_dfe_cte.vlr_ibs_mun is
  'Valor do IBS de competencia do municipio. Tag: gIBSCBS/gIBS/gIBSMun/vIBSMun. Medido: 79,2% - o acervo comeca em 24/06/2026 e a reforma foi entrando aos poucos.';
comment on column poseidon.dpc_dfe_cte.vlr_ibs_uf is
  'Valor do IBS de competencia da UF. Tag: gIBSCBS/gIBS/gIBSUF/vIBSUF. Mesma ocorrencia do vlr_ibs_mun.';
comment on column poseidon.dpc_dfe_cte.vlr_cbs is
  'Valor da CBS. Tag: gIBSCBS/gCBS/vCBS. Mesma ocorrencia do vlr_ibs_mun.';

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
  'Situacao: 1 autorizada, 3 sem efeito (cancelada). Vem SO de evento de cancelamento; o cStat da nota nunca cancela.';
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
comment on column poseidon.dpc_dfe_nfse.cod_tipo_emissao is
  'cStat da NFS-e (NFSe/infNFSe/cStat). E o TIPO de emissao, nao a situacao: 100 gerada, 101 substituta (leiaute anterior a v1.01), 102 decisao judicial ou administrativa, 103 avulsa, 107 MEI.';
comment on column poseidon.dpc_dfe_nfse.dsc_tipo_emissao is
  'Descricao legivel de cod_tipo_emissao.';
comment on column poseidon.dpc_dfe_nfse.dta_emissao is
  'Data e hora de emissao da DPS (infDPS/dhEmi), no horario declarado no documento.';
comment on column poseidon.dpc_dfe_nfse.dta_cancelamento is
  'Data e hora do evento que tornou a NFS-e sem efeito: e101101, e105102, e105104 ou e305101. Nula enquanto a nota vale.';
comment on column poseidon.dpc_dfe_nfse.chave_nfse_substituta is
  'Chave da NFS-e que substituiu esta (e105102/chSubstituta). Preenchida so no cancelamento por substituicao.';
comment on column poseidon.dpc_dfe_nfse.dsc_local_emissao is
  'Municipio emissor (NFSe/infNFSe/xLocEmi), por extenso. Na pratica, o municipio do prestador.';
comment on column poseidon.dpc_dfe_nfse.dsc_local_prestacao is
  'Municipio onde o servico foi prestado (NFSe/infNFSe/xLocPrestacao).';
comment on column poseidon.dpc_dfe_nfse.dsc_logradouro_prest is
  'Endereco do prestador: emit/enderNac/xLgr.';
comment on column poseidon.dpc_dfe_nfse.nro_endereco_prest is
  'Endereco do prestador: emit/enderNac/nro.';
comment on column poseidon.dpc_dfe_nfse.dsc_complemento_prest is
  'Endereco do prestador: emit/enderNac/xCpl.';
comment on column poseidon.dpc_dfe_nfse.dsc_bairro_prest is
  'Endereco do prestador: emit/enderNac/xBairro.';
comment on column poseidon.dpc_dfe_nfse.num_cep_prest is
  'Endereco do prestador: emit/enderNac/CEP, com zeros a esquerda.';

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

--  ---------- DPC_DFE_MANIF_PEDIDO ----------
comment on table poseidon.dpc_dfe_manif_pedido is
  'Pedido de manifestacao em massa (ate 5.000 notas), enviado em segundo plano pelo dfe:manifestar --fila. O andamento e CONTADO em dpc_dfe_manifestacao, nunca guardado aqui.';
comment on column poseidon.dpc_dfe_manif_pedido.cod_dfe_manif_pedido is
  'PK. IDENTITY COLUMN (generated by default as identity). Referenciada por dpc_dfe_manifestacao.cod_dfe_manif_pedido.';
comment on column poseidon.dpc_dfe_manif_pedido.cod_tipo_evento is
  'So Ciencia (210210) e Confirmacao (210200). Desconhecimento e Operacao nao realizada ficam so no envio manual de ate 20: declaram que a operacao nao ocorreu e nao tem volta.';
comment on column poseidon.dpc_dfe_manif_pedido.usuario is
  'Login de quem fez o pedido. Vem do token, nunca de parametro.';
comment on column poseidon.dpc_dfe_manif_pedido.qtd_solicitada is
  'Quantas chaves a pessoa mandou.';
comment on column poseidon.dpc_dfe_manif_pedido.qtd_aceita is
  'Quantas viraram linha na fila (status P). qtd_solicitada = qtd_aceita + qtd_recusada.';
comment on column poseidon.dpc_dfe_manif_pedido.qtd_recusada is
  'Recusadas na entrada (fora do prazo, ja manifestada, ja na fila, sem acesso). Nao viram linha: so esta contagem sobra.';
comment on column poseidon.dpc_dfe_manif_pedido.status_pedido is
  'A = ativo, C = cancelado. "Concluido" nao e status: e nao restar linha P no pedido.';
comment on column poseidon.dpc_dfe_manif_pedido.usuario_cancelamento is
  'Quem cancelou. Cancelar apaga so as linhas P; E e F ficam.';
comment on column poseidon.dpc_dfe_manif_pedido.dta_cancelamento is
  'Quando o pedido foi cancelado (status_pedido C). Nulo enquanto o pedido esta ativo.';
comment on column poseidon.dpc_dfe_manif_pedido.created_at is
  'Quando o pedido de manifestacao em massa foi feito.';

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
comment on column poseidon.dpc_dfe_manifestacao.cod_dfe_manif_pedido is
  'Pedido em massa de onde esta linha veio. Nulo no envio manual de ate 20 e no agendador automatico.';

-- ###########################################################################
--  8. CONFERENCIA RAPIDA
--  O detalhamento esta no 04_validacao_dbeaver.sql. Isto aqui e o suficiente para saber se a instalacao terminou.
--  SEM CONTAGEM GLOBAL ESCRITA A MAO: numero global envelhece na primeira coluna nova e envelhece em silencio.
--  Por isso a consulta 1 usa INVARIANTES (relacoes que continuam verdadeiras quando o modulo cresce) e a 2
--  uma contagem POR TABELA, que muda junto com o create table da secao 2.
-- ###########################################################################
--  1) INVARIANTES deste arquivo. ESPERADO: as quatro linhas com qtd = 0.
select 'coluna sem comentario'  as invariante, count(*) as qtd
  from all_tab_columns c
 where c.owner = 'POSEIDON' and (c.table_name = 'DPC_DFE_EMPRESA' or c.table_name = 'DPC_DFE_CURSOR' or c.table_name = 'DPC_DFE_EMITENTE' or c.table_name = 'DPC_DFE_EXECUCAO' or c.table_name = 'DPC_DFE_DOCUMENTO' or c.table_name = 'DPC_DFE_NOTA' or c.table_name = 'DPC_DFE_NOTA_ITEM' or c.table_name = 'DPC_DFE_NOTA_TOTAL' or c.table_name = 'DPC_DFE_NOTA_TRANSPORTE' or c.table_name = 'DPC_DFE_NOTA_COBRANCA' or c.table_name = 'DPC_DFE_CTE' or c.table_name = 'DPC_DFE_CTE_NFE' or c.table_name = 'DPC_DFE_CTE_EVENTO' or c.table_name = 'DPC_DFE_NFSE' or c.table_name = 'DPC_DFE_EVENTO' or c.table_name = 'DPC_DFE_MANIF_PEDIDO' or c.table_name = 'DPC_DFE_MANIFESTACAO')
   and not exists (select 1 from all_col_comments m
                    where m.owner = c.owner and m.table_name = c.table_name
                      and m.column_name = c.column_name and m.comments is not null)
union all
select 'tabela ausente', count(*) from (
  select column_value as tabela from table(sys.odcivarchar2list('DPC_DFE_EMPRESA', 'DPC_DFE_CURSOR', 'DPC_DFE_EMITENTE', 'DPC_DFE_EXECUCAO', 'DPC_DFE_DOCUMENTO', 'DPC_DFE_NOTA', 'DPC_DFE_NOTA_ITEM', 'DPC_DFE_NOTA_TOTAL', 'DPC_DFE_NOTA_TRANSPORTE', 'DPC_DFE_NOTA_COBRANCA', 'DPC_DFE_CTE', 'DPC_DFE_CTE_NFE', 'DPC_DFE_CTE_EVENTO', 'DPC_DFE_NFSE', 'DPC_DFE_EVENTO', 'DPC_DFE_MANIF_PEDIDO', 'DPC_DFE_MANIFESTACAO'))
   minus select table_name from all_tables where owner = 'POSEIDON')
union all
select 'tabela sem PK', count(*)
  from all_tables t
 where t.owner = 'POSEIDON' and (t.table_name = 'DPC_DFE_EMPRESA' or t.table_name = 'DPC_DFE_CURSOR' or t.table_name = 'DPC_DFE_EMITENTE' or t.table_name = 'DPC_DFE_EXECUCAO' or t.table_name = 'DPC_DFE_DOCUMENTO' or t.table_name = 'DPC_DFE_NOTA' or t.table_name = 'DPC_DFE_NOTA_ITEM' or t.table_name = 'DPC_DFE_NOTA_TOTAL' or t.table_name = 'DPC_DFE_NOTA_TRANSPORTE' or t.table_name = 'DPC_DFE_NOTA_COBRANCA' or t.table_name = 'DPC_DFE_CTE' or t.table_name = 'DPC_DFE_CTE_NFE' or t.table_name = 'DPC_DFE_CTE_EVENTO' or t.table_name = 'DPC_DFE_NFSE' or t.table_name = 'DPC_DFE_EVENTO' or t.table_name = 'DPC_DFE_MANIF_PEDIDO' or t.table_name = 'DPC_DFE_MANIFESTACAO')
   and not exists (select 1 from all_constraints k
                    where k.owner = t.owner and k.table_name = t.table_name and k.constraint_type = 'P')
union all
select 'objeto invalido', count(*)
  from all_objects
 where owner = 'POSEIDON' and object_name like '%DFE%' and status <> 'VALID';

--  2) COLUNA POR TABELA. ESPERADO: diferenca toda em zero e nenhuma linha com achado nulo.
with esperado as (
  select 'dpc_dfe_empresa' as tabela, 14 as esperado from dual union all
  select 'dpc_dfe_cursor', 16 from dual union all
  select 'dpc_dfe_emitente', 13 from dual union all
  select 'dpc_dfe_execucao', 15 from dual union all
  select 'dpc_dfe_documento', 13 from dual union all
  select 'dpc_dfe_nota', 69 from dual union all
  select 'dpc_dfe_nota_item', 51 from dual union all
  select 'dpc_dfe_nota_total', 32 from dual union all
  select 'dpc_dfe_nota_transporte', 21 from dual union all
  select 'dpc_dfe_nota_cobranca', 13 from dual union all
  select 'dpc_dfe_cte', 50 from dual union all
  select 'dpc_dfe_cte_nfe', 5 from dual union all
  select 'dpc_dfe_cte_evento', 20 from dual union all
  select 'dpc_dfe_nfse', 45 from dual union all
  select 'dpc_dfe_evento', 14 from dual union all
  select 'dpc_dfe_manif_pedido', 10 from dual union all
  select 'dpc_dfe_manifestacao', 22 from dual
), achado as (
  select lower(table_name) as tabela, count(*) as qtd
    from all_tab_columns
   where owner = 'POSEIDON' and table_name like 'DPC_DFE%'
   group by table_name
)
select e.tabela, e.esperado, a.qtd as achado, nvl(a.qtd, 0) - e.esperado as diferenca
  from esperado e left join achado a on a.tabela = e.tabela
 order by case when nvl(a.qtd, 0) - e.esperado <> 0 then 0 else 1 end, e.tabela;

