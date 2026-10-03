-- ===========================================================================
--  BLOCO 09_01 - CT-e: as colunas do Modelo Conferencia Mensal da Qive
-- ===========================================================================
--
--  Banco: Oracle (homolog)        Schema: poseidon
--  Tabela alterada: poseidon.dpc_dfe_cte (15 colunas novas, todas nulaveis)
--  Rollback: 09_99_rollback_cte_conferencia_dbeaver.sql
--
--  ==========================================================================
--   ANTES DE RODAR: CONFIRA SE JA RODOU
--  ==========================================================================
--  Rode primeiro o SELECT do fim do arquivo.
--    0 linhas  -> pode rodar o script inteiro
--    15 linhas -> ja esta aplicado, nao rode de novo
--
--  Este script NAO e idempotente, de proposito - ver a secao seguinte.
--  Rodar duas vezes devolve ORA-01430 (column being added already exists),
--  que e inofensivo: o Oracle recusa o statement inteiro e nada muda.
--
--  ==========================================================================
--   POR QUE NAO TEM BLOCO PL/SQL
--  ==========================================================================
--  A primeira versao deste arquivo tinha um bloco declare..end que conferia
--  cada coluna antes de criar, e era idempotente. O DBeaver CORTOU o bloco
--  antes do `end loop;` e devolveu PLS-00103 (end-of-file). Foi a segunda vez
--  no modulo: o 08_02 passou pelo mesmo e tambem terminou sem bloco.
--
--  O bloco em si era valido - foi enviado inteiro ao Oracle pelo oci8, com a
--  condicao invertida para nao criar nada, e compilou e rodou. O problema e o
--  divisor de statements do DBeaver, que nao da para depurar daqui.
--
--  Um unico ALTER com as 15 colunas nao tem onde ser cortado. E o motivo de o
--  08_02 ter funcionado com tres ALTER soltos.
--
--  Regra para o modulo: ADD de coluna vai em UM alter, sem bloco. Quando a
--  idempotencia importar, o SELECT de conferencia responde antes.
--
--  ==========================================================================
--   DE ONDE VEIO ESTA LISTA
--  ==========================================================================
--  Nao do leiaute e nao de palpite: do modelo de colunas que a PROPRIA equipe
--  fiscal salvou na Qive, chamado Modelo Conferencia Mensal CTE. Lido no site
--  em 03/10/2026, ele marca 27 das 96 colunas que o relatorio avancado
--  oferece. Dessas 27, a nossa tela ja cobria 16.
--
--  As 11 que faltavam:
--    nome do remetente, do destinatario e do tomador
--    base, valor e aliquota do ICMS
--    data e hora de autorizacao
--    CT-e complementar
--    IBS do municipio, IBS da UF e CBS
--
--  Lista completa e o cruzamento coluna a coluna em
--  .claude-work-items/cards/3280-dpc-nf-e-sefaz/qive-relatorio-avancado-colunas.md
--
--  ==========================================================================
--   POR QUE SAO 15 COLUNAS E NAO 11
--  ==========================================================================
--  Quatro existem para que as 11 funcionem de verdade:
--
--  dsc_razao_expedidor / dsc_razao_recebedor
--    O nome do TOMADOR nao e um campo do XML: e o nome de um dos outros
--    papeis, apontado por ide/toma3/toma. Sem estes dois, a coluna Tomador
--    ficaria vazia quando o tomador fosse o expedidor (4,11%) ou o recebedor
--    (0,02%) - 4,13% de buraco numa coluna que a equipe confere todo mes.
--
--  num_cnpj_tomador4 / dsc_razao_tomador4
--    Fecham o caso que faltava: cod_tomador = 4 (Outros), 5.124 CT-e, 9,45%
--    do acervo. Era item em aberto desde a Fase E - a coluna CNPJ Tomador
--    sai em branco neles hoje. O bloco ide/toma4 traz CNPJ, IE, xNome, xFant
--    e endereco completo; materializamos o CNPJ e o nome.
--
--  cod_cst_icms
--    Sem ele, base e valor do ICMS vazios em 77% das linhas parecem defeito
--    nosso. Com ele, le-se o motivo: CST 40 = isento. Esta em 100% dos blocos
--    ICMS medidos.
--
--  ==========================================================================
--   MEDICOES (500 CT-e reais, amostra espalhada do acervo, 03/10/2026)
--  ==========================================================================
--    rem/xNome                 100,0%
--    dest/xNome                100,0%
--    protCTe/infProt/dhRecbto  100,0%
--    CST do ICMS               100,0%  dos blocos ICMS
--    infCarga/vCarga            96,2%  (nao entra nesta leva)
--    gIBSCBS (reforma)          79,2%
--    exped/xNome                31,6%
--    receb/xNome                30,0%
--    valores de ICMS            22,8%  (ICMS00 + ICMSOutraUF + ICMS60)
--    toma4/xNome                13,6%
--
--  Pela tabela inteira (54.213 CT-e):
--    cod_tomador = 4             9,45%  -> 5.124
--    cod_tipo_cte = 1            2,31%  -> 1.253 complementares
--
--  ==========================================================================
--   SEGURO COM DADO DENTRO
--  ==========================================================================
--  So ADD de coluna nulavel: o Oracle grava a coluna no dicionario e nao
--  reescreve linha nem invalida indice. Nenhuma coluna existente e tocada.
--
--  Rodar no DBeaver com Execute script (Alt+X).
-- ===========================================================================


alter table poseidon.dpc_dfe_cte add (
  dsc_razao_remetente     VARCHAR2(120),
  dsc_razao_destinat      VARCHAR2(120),
  dsc_razao_expedidor     VARCHAR2(120),
  dsc_razao_recebedor     VARCHAR2(120),
  num_cnpj_tomador4       VARCHAR2(14),
  dsc_razao_tomador4      VARCHAR2(120),
  cod_cst_icms            VARCHAR2(2),
  vlr_bc_icms             NUMBER,
  vlr_icms                NUMBER,
  pct_icms                NUMBER,
  dta_autorizacao         DATE,
  chave_cte_complementado VARCHAR2(44),
  vlr_ibs_mun             NUMBER,
  vlr_ibs_uf              NUMBER,
  vlr_cbs                 NUMBER
);


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


-- ===========================================================================
--  CONFERENCIA
-- ===========================================================================
--  Esperado: 15 linhas. Se der 0, o ALTER nao passou.

select column_name, data_type, data_length, nullable
  from all_tab_columns
 where owner = 'POSEIDON'
   and table_name = 'DPC_DFE_CTE'
   and column_name in (
         'DSC_RAZAO_REMETENTE', 'DSC_RAZAO_DESTINAT', 'DSC_RAZAO_EXPEDIDOR',
         'DSC_RAZAO_RECEBEDOR', 'NUM_CNPJ_TOMADOR4', 'DSC_RAZAO_TOMADOR4',
         'COD_CST_ICMS', 'VLR_BC_ICMS', 'VLR_ICMS',
         'PCT_ICMS', 'DTA_AUTORIZACAO', 'CHAVE_CTE_COMPLEMENTADO',
         'VLR_IBS_MUN', 'VLR_IBS_UF', 'VLR_CBS'
   )
 order by column_name;
