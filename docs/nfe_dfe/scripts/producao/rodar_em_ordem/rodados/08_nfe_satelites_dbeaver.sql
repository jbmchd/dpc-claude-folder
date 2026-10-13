-- ============================================================================
--  MODULO DFe - NF-e: TOTAIS, TRANSPORTE, COBRANCA E CAMPOS DO XML (ARQUIVO 08_01)
-- ============================================================================
--  Tabelas novas:    poseidon.dpc_dfe_nota_total
--                    poseidon.dpc_dfe_nota_transporte
--                    poseidon.dpc_dfe_nota_cobranca
--  Tabela alterada:  poseidon.dpc_dfe_nota (31 colunas novas, todas nulaveis)
--
--  ==========================================================================
--   PARA QUE
--  ==========================================================================
--  O Monitor NF-e expoe hoje o que a dpc_dfe_nota ja tinha. A equipe fiscal
--  pediu a amplitude do relatorio avancado da Qive, e o que falta mora no
--  XML: totais de imposto da nota, transporte, cobranca, enderecos e as
--  informacoes complementares. Este bloco materializa esses campos para que
--  a tela possa filtrar, ordenar e exportar por eles - ler o XML a cada
--  consulta nao serve: ele e um BLOB gzip, sem indice.
--
--  ==========================================================================
--   POR QUE TRES TABELAS SATELITE, E NAO TUDO EM dpc_dfe_nota
--  ==========================================================================
--  Medido em 400 notas reais (procNF das 4 empresas) em 02/10/2026:
--
--    bloco                 presenca   decisao
--    total/ICMSTot           100%      tabela propria (sao 27 valores)
--    total/IBSCBSTot          94%      junto dos totais: mesma natureza
--    transp/vol               90%      tabela de transporte
--    transp/transporta        24%        "
--    transp/veicTransp         0%        "
--    pag/detPag              100%      tabela de cobranca
--    cobr/fat                 24%        "
--
--  Os 27 totais formam um bloco coeso e so fazem sentido juntos; separa-los
--  deixa a dpc_dfe_nota (ja com 37 colunas) com 64. Transporte e cobranca
--  sao opcionais no leiaute e nem toda nota os tem.
--
--  Ja os campos de ide, emit, dest e infAdic ficam NA PROPRIA dpc_dfe_nota:
--  sao 1:1 de verdade, aparecem em 100% das notas e descrevem a nota, nao
--  um aspecto dela.
--
--  As tres satelites usam COD_DFE_NOTA como chave primaria. Isso garante o
--  1:1 sem trigger nem sequence - diferente das irmas 1:N (dpc_dfe_nota_item,
--  dpc_dfe_cte_nfe), que precisam de chave propria porque repetem o pai.
--
--  ==========================================================================
--   POR QUE O ENDERECO DO EMITENTE FICA NA NOTA, E NAO EM dpc_dfe_emitente
--  ==========================================================================
--  A dpc_dfe_emitente e deduplicada por CNPJ (1.073 linhas para 9.474 notas),
--  entao caberia menos espaco guardar o endereco la. Nao fazemos isso de
--  proposito: aquela tabela guarda o ULTIMO valor visto, e o endereco de uma
--  nota e o que valia na EMISSAO dela. Num documento fiscal isso nao e
--  detalhe - se o fornecedor muda de endereco, as notas antigas passariam a
--  exibir o endereco novo. O custo de 9 colunas em 9.474 linhas e irrisorio
--  perto de exibir dado fiscal errado.
--
--  ==========================================================================
--   O QUE FICOU DE FORA, E POR QUE
--  ==========================================================================
--  Medido nas mesmas 400 notas - ZERO ocorrencias:
--    total/ISSQNtot  ISS de nota mista (12 campos)
--    pag/card        cartao: bandeira, autorizacao, integracao (5 campos)
--    exporta         exportacao: drawback, chave do registro (3 campos)
--    total/ISTot     Imposto Seletivo da reforma (vIS)
--  Sao 21 campos que nenhuma nota do acervo preenche. Criar coluna que nunca
--  recebe valor so aumenta a tela, a exportacao e o custo de manutencao.
--  Quando a primeira nota com ISS misto ou cartao chegar, o bloco entra.
--
--  Tambem fora, por outro motivo:
--    "Nome do motorista"  nao existe no leiaute da NF-e (e do MDF-e)
--    total/retTrib        retencoes de PIS/COFINS/CSLL/IRRF/INSS, em 63%
--                         das notas - nao estava no pedido da equipe fiscal;
--                         fica anotado para a proxima leva
--
--  ==========================================================================
--   ORDEM OBRIGATORIA
--  ==========================================================================
--  Este script ANTES do deploy da ApiNFE que grava estas colunas. Depois
--  dele, sem o bloco, toda NF-e completa falha com ORA-00904 e a
--  normalizacao de NF-e para.
--
--  ==========================================================================
--   COMO RODAR (DBeaver)
--  ==========================================================================
--  Conectado como POSEIDON, arquivo INTEIRO com Alt+X. Idempotente: tabela e
--  coluna que ja existem sao puladas. Bloco PL/SQL no molde do 04_02:
--  q'[...]' e sem a barra final - com aspas simples e '/', o DBeaver devolve
--  PLS-00103 e ORA-00900. Rollback: 08_99_rollback_nfe_satelites_dbeaver.sql.
-- ============================================================================

-- ============================================================================
--  SECAO 1 - TABELA DPC_DFE_NOTA_TOTAL
-- ============================================================================

declare
  qtd number;
begin
  select count(*) into qtd from all_tables
   where owner = 'POSEIDON' and table_name = 'DPC_DFE_NOTA_TOTAL';

  if qtd = 0 then
    execute immediate q'[create table poseidon.dpc_dfe_nota_total
    (
      cod_dfe_nota NUMBER not null,
      vlr_bc_icms       NUMBER,
      vlr_icms          NUMBER,
      vlr_icms_deson    NUMBER,
      vlr_fcp_uf_dest   NUMBER,
      vlr_icms_uf_dest  NUMBER,
      vlr_icms_uf_remet NUMBER,
      vlr_fcp           NUMBER,
      vlr_bc_icms_st    NUMBER,
      vlr_icms_st       NUMBER,
      vlr_fcp_st        NUMBER,
      vlr_fcp_st_ret    NUMBER,
      vlr_frete         NUMBER,
      vlr_seguro        NUMBER,
      vlr_desconto      NUMBER,
      vlr_ii            NUMBER,
      vlr_ipi           NUMBER,
      vlr_ipi_devol     NUMBER,
      vlr_pis           NUMBER,
      vlr_cofins        NUMBER,
      vlr_outros        NUMBER,
      vlr_total_tributo NUMBER,
      vlr_bc_ibscbs     NUMBER,
      vlr_ibs           NUMBER,
      vlr_ibs_uf        NUMBER,
      vlr_ibs_mun       NUMBER,
      vlr_cbs           NUMBER,
      vlr_nota_total    NUMBER,
      created_at   DATE default sysdate not null,
      created_by   VARCHAR2(50),
      updated_at   DATE,
      updated_by   VARCHAR2(50),
      constraint DPC_DFE_NOTA_TOTAL_PK  primary key (cod_dfe_nota),
      constraint DPC_DFE_NOTA_TOTAL_FK1 foreign key (cod_dfe_nota)
                 references poseidon.dpc_dfe_nota (cod_dfe_nota)
    )
    tablespace TSD_POSEIDON]';
    dbms_output.put_line('criada: dpc_dfe_nota_total');
  else
    dbms_output.put_line('dpc_dfe_nota_total ja existe.');
  end if;
exception
  when others then
    dbms_output.put_line('DPC_DFE_NOTA_TOTAL: FALHOU -> ' || sqlerrm);
end;

comment on table poseidon.dpc_dfe_nota_total is
    'Totais da NF-e (bloco total do XML): ICMS, ST, IPI, PIS, COFINS, frete, seguro e os valores da reforma tributaria. Uma linha por nota, so para NF-e completa (procNF).';

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

-- ============================================================================
--  SECAO 2 - TABELA DPC_DFE_NOTA_TRANSPORTE
-- ============================================================================

declare
  qtd number;
begin
  select count(*) into qtd from all_tables
   where owner = 'POSEIDON' and table_name = 'DPC_DFE_NOTA_TRANSPORTE';

  if qtd = 0 then
    execute immediate q'[create table poseidon.dpc_dfe_nota_transporte
    (
      cod_dfe_nota NUMBER not null,
      cod_modalidade_frete      NUMBER(1),
      num_cnpj_cpf_transp       VARCHAR2(14),
      dsc_razao_transp          VARCHAR2(60),
      num_inscr_estadual_transp VARCHAR2(14),
      dsc_endereco_transp       VARCHAR2(60),
      dsc_municipio_transp      VARCHAR2(60),
      sig_uf_transp             VARCHAR2(2),
      num_placa_veiculo         VARCHAR2(8),
      sig_uf_veiculo            VARCHAR2(2),
      num_rntc                  VARCHAR2(20),
      qtd_volume                NUMBER,
      vlr_peso_liquido          NUMBER,
      vlr_peso_bruto            NUMBER,
      dsc_especie_volume        VARCHAR2(400),
      dsc_marca_volume          VARCHAR2(400),
      dsc_numeracao_volume      VARCHAR2(400),
      created_at   DATE default sysdate not null,
      created_by   VARCHAR2(50),
      updated_at   DATE,
      updated_by   VARCHAR2(50),
      constraint DPC_DFE_NOTA_TRANSPORTE_PK  primary key (cod_dfe_nota),
      constraint DPC_DFE_NOTA_TRANSPORTE_FK1 foreign key (cod_dfe_nota)
                 references poseidon.dpc_dfe_nota (cod_dfe_nota)
    )
    tablespace TSD_POSEIDON]';
    dbms_output.put_line('criada: dpc_dfe_nota_transporte');
  else
    dbms_output.put_line('dpc_dfe_nota_transporte ja existe.');
  end if;
exception
  when others then
    dbms_output.put_line('DPC_DFE_NOTA_TRANSPORTE: FALHOU -> ' || sqlerrm);
end;

comment on table poseidon.dpc_dfe_nota_transporte is
    'Transporte da NF-e (bloco transp): modalidade do frete, transportadora, veiculo e volumes. Os volumes sao 1:N no XML e vem agregados - soma dos pesos e quantidades, lista das especies e marcas.';

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
    'Especies distintas, separadas por virgula. Tag: transp/vol/esp.';

comment on column poseidon.dpc_dfe_nota_transporte.dsc_marca_volume is
    'Marcas distintas, separadas por virgula. Tag: transp/vol/marca.';

comment on column poseidon.dpc_dfe_nota_transporte.dsc_numeracao_volume is
    'Numeracoes distintas, separadas por virgula. Tag: transp/vol/nVol.';

-- ============================================================================
--  SECAO 3 - TABELA DPC_DFE_NOTA_COBRANCA
-- ============================================================================

declare
  qtd number;
begin
  select count(*) into qtd from all_tables
   where owner = 'POSEIDON' and table_name = 'DPC_DFE_NOTA_COBRANCA';

  if qtd = 0 then
    execute immediate q'[create table poseidon.dpc_dfe_nota_cobranca
    (
      cod_dfe_nota NUMBER not null,
      num_fatura          VARCHAR2(60),
      vlr_original        NUMBER,
      vlr_desconto        NUMBER,
      vlr_liquido         NUMBER,
      dsc_forma_pagto     VARCHAR2(200),
      dsc_indicador_pagto VARCHAR2(50),
      vlr_pago            NUMBER,
      vlr_troco           NUMBER,
      created_at   DATE default sysdate not null,
      created_by   VARCHAR2(50),
      updated_at   DATE,
      updated_by   VARCHAR2(50),
      constraint DPC_DFE_NOTA_COBRANCA_PK  primary key (cod_dfe_nota),
      constraint DPC_DFE_NOTA_COBRANCA_FK1 foreign key (cod_dfe_nota)
                 references poseidon.dpc_dfe_nota (cod_dfe_nota)
    )
    tablespace TSD_POSEIDON]';
    dbms_output.put_line('criada: dpc_dfe_nota_cobranca');
  else
    dbms_output.put_line('dpc_dfe_nota_cobranca ja existe.');
  end if;
exception
  when others then
    dbms_output.put_line('DPC_DFE_NOTA_COBRANCA: FALHOU -> ' || sqlerrm);
end;

comment on table poseidon.dpc_dfe_nota_cobranca is
    'Cobranca e pagamento da NF-e (blocos cobr e pag): fatura e formas de pagamento. Os pagamentos sao 1:N no XML e vem agregados.';

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

-- ============================================================================
--  SECAO 4 - COLUNAS NOVAS EM DPC_DFE_NOTA
-- ============================================================================

declare
  type t_lista is table of varchar2(200);
  nomes t_lista := t_lista(
    'dsc_natureza_operacao',
    'cod_finalidade',
    'cod_consumidor_final',
    'cod_presenca',
    'cod_regime_trib_emit',
    'num_inscr_est_st_emit',
    'dsc_logradouro_emit',
    'nro_endereco_emit',
    'dsc_complemento_emit',
    'dsc_bairro_emit',
    'cod_municipio_emit',
    'dsc_municipio_emit',
    'sig_uf_emit',
    'num_cep_emit',
    'num_fone_emit',
    'num_cnpj_cpf_dest',
    'num_inscr_estadual_dest',
    'cod_ind_ie_dest',
    'dsc_logradouro_dest',
    'nro_endereco_dest',
    'dsc_complemento_dest',
    'dsc_bairro_dest',
    'cod_municipio_dest',
    'dsc_municipio_dest',
    'sig_uf_dest',
    'num_cep_dest',
    'num_fone_dest',
    'dsc_inf_complementar',
    'dsc_inf_fisco',
    'dsc_nfe_referenciada',
    'dsc_pedido_compra'
  );
  tipos t_lista := t_lista(
    'VARCHAR2(60)',
    'NUMBER(1)',
    'NUMBER(1)',
    'NUMBER(1)',
    'NUMBER(1)',
    'VARCHAR2(14)',
    'VARCHAR2(60)',
    'VARCHAR2(60)',
    'VARCHAR2(60)',
    'VARCHAR2(60)',
    'VARCHAR2(7)',
    'VARCHAR2(60)',
    'VARCHAR2(2)',
    'VARCHAR2(8)',
    'VARCHAR2(14)',
    'VARCHAR2(14)',
    'VARCHAR2(14)',
    'NUMBER(1)',
    'VARCHAR2(60)',
    'VARCHAR2(60)',
    'VARCHAR2(60)',
    'VARCHAR2(60)',
    'VARCHAR2(7)',
    'VARCHAR2(60)',
    'VARCHAR2(2)',
    'VARCHAR2(8)',
    'VARCHAR2(14)',
    'CLOB',
    'VARCHAR2(2000)',
    'VARCHAR2(500)',
    'VARCHAR2(500)'
  );
  qtd number;
begin
  for i in 1 .. nomes.count loop
    select count(*) into qtd from all_tab_columns
     where owner = 'POSEIDON' and table_name = 'DPC_DFE_NOTA'
       and column_name = upper(nomes(i));

    if qtd = 0 then
      execute immediate q'[alter table poseidon.dpc_dfe_nota add (]'
                        || nomes(i) || ' ' || tipos(i) || ')';
      dbms_output.put_line('criada: ' || nomes(i));
    else
      dbms_output.put_line(nomes(i) || ' ja existe.');
    end if;
  end loop;
exception
  when others then
    dbms_output.put_line('DPC_DFE_NOTA: FALHOU -> ' || sqlerrm);
end;


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

-- ============================================================================
--  SECAO 5 - CONFERENCIA
-- ============================================================================
--  Esperado: 3 tabelas, 6 constraints (PK e FK de cada) e 31 colunas novas.

select 'tabela' as tipo, table_name as objeto, null as detalhe
  from all_tables
 where owner = 'POSEIDON'
   and table_name in ('DPC_DFE_NOTA_TOTAL','DPC_DFE_NOTA_TRANSPORTE','DPC_DFE_NOTA_COBRANCA')
union all
select 'constraint', c.constraint_name,
       listagg(cc.column_name, ',') within group (order by cc.position)
  from all_constraints c
  join all_cons_columns cc on cc.owner = c.owner and cc.constraint_name = c.constraint_name
 where c.owner = 'POSEIDON'
   and c.table_name in ('DPC_DFE_NOTA_TOTAL','DPC_DFE_NOTA_TRANSPORTE','DPC_DFE_NOTA_COBRANCA')
   and c.constraint_type in ('P','R')
 group by c.constraint_name
union all
select 'coluna nota', column_name, data_type
  from all_tab_columns
 where owner = 'POSEIDON' and table_name = 'DPC_DFE_NOTA'
   and column_name in ('DSC_NATUREZA_OPERACAO', 'COD_FINALIDADE', 'COD_CONSUMIDOR_FINAL', 'COD_PRESENCA', 'COD_REGIME_TRIB_EMIT', 'NUM_INSCR_EST_ST_EMIT', 'DSC_LOGRADOURO_EMIT', 'NRO_ENDERECO_EMIT', 'DSC_COMPLEMENTO_EMIT', 'DSC_BAIRRO_EMIT', 'COD_MUNICIPIO_EMIT', 'DSC_MUNICIPIO_EMIT', 'SIG_UF_EMIT', 'NUM_CEP_EMIT', 'NUM_FONE_EMIT', 'NUM_CNPJ_CPF_DEST', 'NUM_INSCR_ESTADUAL_DEST', 'COD_IND_IE_DEST', 'DSC_LOGRADOURO_DEST', 'NRO_ENDERECO_DEST', 'DSC_COMPLEMENTO_DEST', 'DSC_BAIRRO_DEST', 'COD_MUNICIPIO_DEST', 'DSC_MUNICIPIO_DEST', 'SIG_UF_DEST', 'NUM_CEP_DEST', 'NUM_FONE_DEST', 'DSC_INF_COMPLEMENTAR', 'DSC_INF_FISCO', 'DSC_NFE_REFERENCIADA', 'DSC_PEDIDO_COMPRA')
 order by 1, 2;
