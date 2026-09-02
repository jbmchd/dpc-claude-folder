-- ==========================================================================
--  ATUALIZACAO DO MODULO DFe - ESTRUTURA (v7 a v10 num unico script)
-- ==========================================================================
--
--  Para base que JA TEM o modulo instalado, em estado anterior ao v7.
--  Substitui os quatro arquivos v7, v8, v9 e v10, unificados em 02/09/2026;
--  cada um segue no historico do git da ApiNFE, nos commits citados abaixo.
--
--  BASE NOVA NAO USA ESTE ARQUIVO. O producao/01_estrutura ja cria as 13
--  tabelas, incluindo DPC_DFE_NOTA_ITEM e DPC_DFE_CTE_EVENTO. Os dois
--  caminhos convergem para a mesma estrutura - este por ALTER, aquele por
--  CREATE - e por isso sao ALTERNATIVOS, nao sequenciais.
--
--  DEPOIS DESTE ARQUIVO FALTA UM PASSO, e ele nao esta aqui:
--
--      ../04_parametros_dbeaver.sql
--
--  Os 4 parametros em POSEIDON.DPC_PARAMETRO. Mora em producao/ porque os
--  DOIS caminhos precisam dele, e duplicar o arquivo seria recriar a
--  divergencia que inutilizou os alters v2 a v6.
--
--  COMO RODAR
--  ----------
--  Como POSEIDON, no DBeaver, o arquivo INTEIRO com Alt+X. Sem barra para
--  terminar bloco. E CRLF de proposito: em LF o divisor de statements do
--  DBeaver corta o bloco PL/SQL no fim do IF e devolve PLS-00103.
--
--  E REEXECUTAVEL: cada objeto e criado so se ainda nao existir. Rodar numa
--  base ja atualizada nao faz nada.
--
--  A ORDEM IMPORTA e esta preservada: a secao 3 usa na conferencia a coluna
--  que a secao 1 introduz. Nao reordenar.
--
--  AS SECOES "POPULAR O ACERVO" SAO COMENTARIO, NAO STATEMENT. Rodar este
--  arquivo NAO reprocessa nada. Quem quiser reinterpretar o acervo ja
--  capturado descomenta e roda a mao - e nao custa chamada a SEFAZ, porque
--  os XML estao guardados em DPC_DFE_DOCUMENTO.
--
--  O QUE ESTE ARQUIVO ACRESCENTA
--  -----------------------------
--    1. DPC_DFE_NOTA_ITEM - os itens da NF-e
--    2. DPC_DFE_NOTA.SIG_PAPEL_EMPRESA - o papel da empresa na nota
--    3. DPC_DFE_NOTA.VLR_TOTAL_PRODUTO - o vProd do ICMSTot
--    4. DPC_DFE_CTE_EVENTO - eventos de CT-e (entrega e cancelamento)
--
--  Explicacao completa, com o que conferir antes e depois:
--  workspace/.claude/docs/nfe_dfe/docs/07_ddl-instalacao.md
-- ==========================================================================


-- ###########################################################################
-- #
-- #  SECAO 1 - DPC_DFE_NOTA_ITEM - os itens da NF-e
-- #
-- #  vinha de: v7_nota_item_dbeaver.sql   (git ApiNFE: 1bdc4a7)
-- #
-- ###########################################################################

-- ============================================================================
--  v7 - ITENS DA NF-e  (poseidon.dpc_dfe_nota_item)
-- ============================================================================
--  Para ambiente que JA TEM a estrutura do modulo instalada.
--
--  Instalacao NOVA nao precisa deste arquivo: a tabela ja esta no
--  ../producao/01_estrutura_dbeaver.sql. As duas definicoes saem do MESMO
--  gerador, de proposito - foi a divergencia entre install e alters que tornou
--  os scripts antigos inservivies para producao.
--
--  Como POSEIDON, script inteiro com Alt+X. Sem "/" para terminar bloco.
--  Reexecutavel: cada objeto e criado somente se ainda nao existir.
--
--  ==========================================================================
--   POR QUE ESTA TABELA
--  ==========================================================================
--  Os itens sao extraidos do XML que JA ESTA GRAVADO em dpc_dfe_documento, na
--  normalizacao. A ingestao nao le conteudo.
--
--  Consequencia pratica: NAO e preciso consultar a SEFAZ de novo para popular
--  esta tabela. Depois de rodar este script, um unico comando preenche todo o
--  acervo ja capturado - ver a secao 6 no fim do arquivo.
--
--  ==========================================================================
--   DESENHADA SOBRE 833 ITENS REAIS
--  ==========================================================================
--  As colunas vieram do acervo de homologacao, nao do layout lido de fora.
--  Quatro coisas que o dado mostrou e a especificacao nao deixa obvias:
--
--   1. O SUBGRUPO DE IMPOSTO VARIA POR ITEM. No mesmo acervo apareceram ICMS00,
--      ICMS40, ICMS60, ICMS61 e ICMSSN102; PISAliq, PISNT e PISOutr; IPINT e
--      IPITrib. Nao ha coluna por subgrupo: ha coluna por FATO (CST, base,
--      aliquota, valor), e o parser busca a tag dentro do grupo.
--
--   2. ICMS60 nao tem vBC nem vICMS - tem vBCSTRet/vICMSSTRet. Por isso as
--      colunas de ST guardam os dois nomes que o XML usa para o mesmo fato.
--
--   3. IBS/CBS - a reforma tributaria - JA CHEGA HOJE: 826 dos 833 itens
--      capturados trazem o CST do grupo IBSCBS preenchido. Nao e campo para
--      depois.
--
--   4. cEAN vem a string "SEM GTIN" quando o produto nao tem codigo de barras.
--      E texto, nunca numero.
--
--   5. vUnCom usa ATE 10 DECIMAIS no dado real (6.4580725910). NUMBER sem
--      precisao definida, de proposito: fixar escala arredondaria e a
--      conferencia de total deixaria de fechar.
-- ============================================================================


-- ###########################################################################
--  1. SEQUENCE
-- ###########################################################################
declare
  qtd number;
begin
  select count(*) into qtd from all_sequences
   where sequence_owner = 'POSEIDON' and sequence_name = 'DPCS_DFE_NOTA_ITEM';

  if qtd = 0 then
    execute immediate q'[create sequence poseidon.dpcs_dfe_nota_item minvalue 1 start with 1 increment by 1 cache 20]';
  end if;
end;


-- ###########################################################################
--  2. TABELA
-- ###########################################################################
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


-- ###########################################################################
--  3. CONSTRAINTS
-- ###########################################################################
--  A UK (cod_dfe_nota, nro_item) e o que torna o reprocessamento seguro: rodar
--  dfe:normalizar de novo sobre o mesmo documento nao duplica item.
--
--  A check de status_compoe_total existe porque o layout admite item que NAO
--  entra no total da nota (indTot = 0). Somar vlr_produto sem filtrar por '1'
--  pode nao fechar com dpc_dfe_nota.vlr_nota.
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


-- ###########################################################################
--  4. INDICE
-- ###########################################################################
--  Um so, e deliberado. O acesso dominante - "os itens desta nota" - ja e
--  servido pela UK1, cujo prefixo e cod_dfe_nota. Sobra a classificacao
--  fiscal, que e o filtro analitico da tabela.
--
--  Indice a mais aqui custa caro: uma nota do acervo tem 300 itens, e o
--  insert e feito item a item.
declare
  qtd number;
begin
  select count(*) into qtd from all_indexes
   where owner = 'POSEIDON' and index_name = 'DPCI_DFE_NOTA_ITEM_NCM';

  if qtd = 0 then
    execute immediate q'[create index poseidon.DPCI_DFE_NOTA_ITEM_NCM on poseidon.dpc_dfe_nota_item (cod_ncm) tablespace TSD_POSEIDON]';
  end if;
end;


-- ###########################################################################
--  5. TRIGGER E COMENTARIOS
-- ###########################################################################
create or replace trigger poseidon.dpct_dfe_nota_item
  before insert on poseidon.dpc_dfe_nota_item
  for each row
begin
  if :new.cod_dfe_nota_item is null then
    :new.cod_dfe_nota_item := poseidon.dpcs_dfe_nota_item.nextval;
  end if;
end dpct_dfe_nota_item;

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


-- ###########################################################################
--  6. DEPOIS DE RODAR: popular o acervo ja capturado
-- ###########################################################################
--  Nenhuma chamada a SEFAZ. Os XMLs estao guardados; e so reinterpretar.
--
--  Confira quantas notas completas existem e quantos itens devem sair:
--
--      select count(*) as notas_completas
--        from poseidon.dpc_dfe_nota where dsc_tipo_doc = 'procNF';
--
--  Volte os documentos de NF-e completa para a fila e normalize:
--
--      update poseidon.dpc_dfe_documento
--         set status_process = 'P', qtd_tentativa = 0
--       where dsc_tipo_doc = 'procNF';
--      commit;
--
--      dev.cmd dfe:normalizar --limit=5 --dry-run     -- confere primeiro
--      dev.cmd dfe:normalizar
--
--  Reprocessar procNF e seguro: a nota e atualizada pela UK (empresa, chave), o
--  emitente pela UK do CNPJ, e os itens sao SUBSTITUIDOS por nota. Nada duplica.


-- ###########################################################################
--  7. CONFERENCIA
-- ###########################################################################
--  ESPERADO: 1 tabela, 1 sequence, 1 trigger, 4 constraints, 3 indices
--  (PK + UK + o de NCM) e 51 colunas comentadas.
--  ATENCAO ao nomear alias: TRIGGER e palavra RESERVADA no Oracle e nao pode
--  ser alias de coluna - a primeira versao deste select usava "as trigger" e
--  quebrava com ORA-00923 (FROM keyword not found where expected), depois de a
--  DDL ja ter rodado com sucesso. SEQUENCE e CONSTRAINTS sao keywords mas NAO
--  reservadas, e funcionariam; o prefixo qtd_ esta em todas para nao depender
--  dessa distincao. Conferir em v$reserved_words where reserved = 'Y'.
select (select count(*) from all_tables
         where owner='POSEIDON' and table_name='DPC_DFE_NOTA_ITEM')        as qtd_tabela,
       (select count(*) from all_sequences
         where sequence_owner='POSEIDON' and sequence_name='DPCS_DFE_NOTA_ITEM') as qtd_sequence,
       (select count(*) from all_triggers
         where owner='POSEIDON' and trigger_name='DPCT_DFE_NOTA_ITEM')     as qtd_trigger,
       (select count(*) from all_constraints
         where owner='POSEIDON' and table_name='DPC_DFE_NOTA_ITEM'
           and constraint_name not like 'SYS_%')                           as qtd_constraint,
       (select count(*) from all_indexes
         where owner='POSEIDON' and table_name='DPC_DFE_NOTA_ITEM')        as qtd_indice,
       (select count(*) from all_col_comments
         where owner='POSEIDON' and table_name='DPC_DFE_NOTA_ITEM'
           and comments is not null)                                       as qtd_col_comentada
  from dual;

--  Objeto invalido: deve ser zero.
select object_name, object_type, status from all_objects
 where owner='POSEIDON' and object_name like '%DFE_NOTA_ITEM%' and status <> 'VALID';

--  Depois de normalizar, a conferencia que vale: a soma dos itens fecha com o
--  total DE PRODUTOS? Divergencia aqui aponta extracao incompleta - e a unica
--  verificacao do modulo que compara dois caminhos independentes do mesmo XML
--  (o vProd do ICMSTot e a soma dos det).
--
--  ATENCAO - esta consulta comparava contra vlr_nota (vNF) ate 01/09/2026, e
--  isso estava ERRADO: vNF = vProd - vDesc + vFrete + vSeg + vOutro + vST + ...
--  Toda nota com desconto ou frete aparecia como divergente. A coluna
--  vlr_total_produto foi criada no v9 exatamente para isto; se o seu ambiente
--  ainda nao tem, rode ../alteracoes/v9_total_produto_nota_dbeaver.sql antes.
--
--  Soma somente item com status_compoe_total = 1, senao acusa divergencia que
--  nao existe - e o emitente tambem nao soma esses no vProd.
select e.nro_empresa, n.nro_nf, n.chave_nf, n.vlr_total_produto,
       (select count(*) from poseidon.dpc_dfe_nota_item i
         where i.cod_dfe_nota = n.cod_dfe_nota) as qtd_item,
       (select round(sum(i.vlr_produto), 2) from poseidon.dpc_dfe_nota_item i
         where i.cod_dfe_nota = n.cod_dfe_nota
           and nvl(i.status_compoe_total,'1') = '1') as soma_itens
  from poseidon.dpc_dfe_nota    n
  join poseidon.dpc_dfe_empresa e on e.cod_dfe_empresa = n.cod_dfe_empresa
 where n.dsc_tipo_doc = 'procNF'
 order by e.nro_empresa, n.nro_nf;
-- ============================================================================


-- ###########################################################################
-- #
-- #  SECAO 2 - DPC_DFE_NOTA.SIG_PAPEL_EMPRESA - o papel da empresa na nota
-- #
-- #  vinha de: v8_papel_empresa_nota_dbeaver.sql   (git ApiNFE: ede36cc)
-- #
-- ###########################################################################

-- ============================================================================
--  v8 - PAPEL DA EMPRESA NA NF-e  (poseidon.dpc_dfe_nota.sig_papel_empresa)
-- ============================================================================
--  Para ambiente que JA TEM a estrutura do modulo instalada.
--
--  Instalacao NOVA nao precisa deste arquivo: a coluna ja esta no
--  ../producao/01_estrutura_dbeaver.sql. As duas definicoes saem do MESMO
--  gerador, de proposito.
--
--  Como POSEIDON, script inteiro com Alt+X. Sem "/" para terminar bloco.
--  Reexecutavel: cada objeto e criado somente se ainda nao existir.
--
--  ==========================================================================
--   POR QUE ESTA COLUNA
--  ==========================================================================
--  O NFeDistribuicaoDFe entrega toda NF-e em que o CNPJ apareca - em QUALQUER
--  papel. A tela precisa recortar o mesmo acervo por papel, que sao as quatro
--  abas da Qive:
--
--    Recebidas   destinataria        dest/CNPJ
--    Emitidas    emitente            emit/CNPJ
--    Transporte  transportadora      transp/transporta/CNPJ
--    Citadas     autorizada a baixar autXML/CNPJ
--
--  Sem a coluna, o frontend so conseguia APROXIMAR "Emitidas" comparando o CNPJ
--  do emitente com o da empresa, e Transporte e Citadas eram impossiveis.
--
--  DPC_DFE_CTE e DPC_DFE_NFSE ja tinham SIG_PAPEL_EMPRESA. So a de NF-e nao
--  tinha - este script fecha a assimetria.
--
--  ==========================================================================
--   INDEF E OUTRO NAO SAO A MESMA COISA
--  ==========================================================================
--  E a decisao de projeto que mais afeta a tela.
--
--  O resNFe - o RESUMO - tem 546 bytes e doze tags: chNFe, CNPJ, xNome, IE,
--  dhEmi, tpNF, vNF, digVal, dhRecbto, nProt, cSitNFe. NAO tem <dest>, NAO tem
--  <transp>, NAO tem <autXML>. O unico CNPJ ali e o do EMITENTE.
--
--  Entao, para nota que so tem resumo, da para responder UMA coisa: se o
--  emitente somos nos, o papel e EMIT; se nao, sabemos apenas que NAO somos o
--  emitente. Isso e INDEF.
--
--    INDEF - o documento nao permite saber. TEMPORARIO: o XML completo resolve.
--    OUTRO - o XML completo foi lido e o nosso CNPJ nao esta em nenhum dos
--            quatro papeis. DEFINITIVO.
--
--  E o resumo chega PRIMEIRO, as vezes dias antes do completo, as vezes o
--  completo nunca chega. INDEF vai ser comum, nao excecao. Uma tela que trate
--  INDEF como "nao e nossa" esconderia nota que e.
--
--  ==========================================================================
--   PRECEDENCIA
--  ==========================================================================
--  dest -> emit -> transp -> autXML.
--
--  Uma nota pode ter a empresa em MAIS DE UM papel - destinataria e tambem
--  autorizada a baixar, por exemplo - e a ordem decide qual vale. DEST vence
--  porque o caso de uso do modulo e a nota RECEBIDA.
--
--  autXML e LISTA: o layout admite ate 10 autorizados.
--
--  ==========================================================================
--   NAO CONSULTA A SEFAZ
--  ==========================================================================
--  O backfill da secao 5 reinterpreta XML que JA ESTA no banco. Nao ha chamada
--  a fonte externa e o NSU nao e tocado - reposicionar NSU gera cStat 656 e
--  bloqueia o certificado por 1 hora para todas as filiais que compartilham o
--  e-CNPJ da matriz.
-- ============================================================================


-- ###########################################################################
--  1. A COLUNA
-- ###########################################################################
--  Nullable, como nas irmas. Quem preenche e o dfe:normalizar, e ele sempre
--  preenche - INDEF no pior caso. Nulo aqui significa "nota normalizada antes
--  desta versao e ainda nao reprocessada".
declare
  qtd number;
begin
  select count(*) into qtd from all_tab_columns
   where owner = 'POSEIDON' and table_name = 'DPC_DFE_NOTA'
     and column_name = 'SIG_PAPEL_EMPRESA';

  if qtd = 0 then
    execute immediate 'alter table poseidon.dpc_dfe_nota add sig_papel_empresa VARCHAR2(6)';
  end if;
end;


-- ###########################################################################
--  2. CHECK
-- ###########################################################################
declare
  qtd number;
begin
  select count(*) into qtd from all_constraints
   where owner = 'POSEIDON' and constraint_name = 'DPC_DFE_NOTA_CK3';

  if qtd = 0 then
    execute immediate q'[alter table poseidon.dpc_dfe_nota
      add constraint DPC_DFE_NOTA_CK3 check (sig_papel_empresa in
        ('DEST','EMIT','TRANSP','AUTXML','OUTRO','INDEF'))]';
  end if;
end;


-- ###########################################################################
--  3. INDICE
-- ###########################################################################
--  (cod_dfe_empresa, sig_papel_empresa, dta_emissao) - exatamente o filtro das
--  quatro abas: um estabelecimento, um papel, um periodo.
--
--  A ordem das colunas importa: empresa primeiro porque a tela SEMPRE filtra por
--  estabelecimento; papel depois porque e o recorte da aba; data por ultimo
--  porque e range, e coluna de range em indice composto vai no fim.
declare
  qtd number;
begin
  select count(*) into qtd from all_indexes
   where owner = 'POSEIDON' and index_name = 'DPCI_DFE_NOTA_PAPEL';

  if qtd = 0 then
    execute immediate q'[create index poseidon.DPCI_DFE_NOTA_PAPEL
      on poseidon.dpc_dfe_nota (cod_dfe_empresa, sig_papel_empresa, dta_emissao)
      tablespace TSD_POSEIDON]';
  end if;
end;


-- ###########################################################################
--  4. COMENTARIO
-- ###########################################################################
comment on column poseidon.dpc_dfe_nota.sig_papel_empresa is
  'Papel da NOSSA empresa nesta NF-e: DEST destinataria, EMIT emitente, TRANSP transportadora, AUTXML citada em autXML (autorizada a baixar), OUTRO o XML completo foi lido e o CNPJ nao esta em nenhum papel conhecido, INDEF o documento nao permite saber. INDEF e OUTRO NAO sao a mesma coisa: o resNFe tem 546 bytes e so o CNPJ do emitente - sem dest, sem transp, sem autXML - entao nota que so tem resumo e INDEF, e isso e temporario (o XML completo resolve). OUTRO e definitivo. Colapsar os dois faria a tela tratar caso temporario como definitivo. Precedencia no preenchimento: dest, emit, transp, autXML - DEST vence porque o caso de uso do modulo e a nota RECEBIDA.';


-- ###########################################################################
--  5. BACKFILL - as notas ja normalizadas
-- ###########################################################################
--  ANTES: quantas notas existem e quantas ficarao com papel.
select dsc_tipo_doc,
       count(*)                                                     as notas,
       sum(case when sig_papel_empresa is null then 1 else 0 end)    as sem_papel
  from poseidon.dpc_dfe_nota
 group by dsc_tipo_doc
 order by 2 desc;

--  O papel sai do XML, que esta guardado em DPC_DFE_DOCUMENTO.BIN_DOCUMENTO.
--  Devolver os documentos de NF-e para a fila e deixar o dfe:normalizar
--  reinterpretar e o caminho do modulo - nao ha command de backfill, porque
--  reprocessar JA E a operacao normal e ja e idempotente:
--
--    a nota    e atualizada pela UK (cod_dfe_empresa, chave_nf)
--    o emitente pela UK do CNPJ
--    os itens  sao SUBSTITUIDOS por nota
--
--  Inclui resNFe de proposito: e ele que vira EMIT ou INDEF, e sem reprocessar o
--  resumo aquelas notas ficariam com papel nulo para sempre.
--
--      update poseidon.dpc_dfe_documento
--         set status_process = 'P', qtd_tentativa = 0
--       where dsc_tipo_doc in ('procNF', 'resNFe');
--      commit;
--
--      dev.cmd dfe:normalizar --limit=5 --dry-run     -- confere primeiro
--      dev.cmd dfe:normalizar
--
--  ATENCAO a ordem quando a nota tem OS DOIS documentos (resumo e completo): o
--  anti-rebaixamento de DfeNotaRepository::salva recusa o resumo sobre uma nota
--  que ja e completa, devolvendo IGNORADA - entao o papel do procNFe NAO e
--  sobrescrito por INDEF, qualquer que seja a ordem de processamento. Isso e
--  garantido pelo codigo, nao pela sorte.


-- ###########################################################################
--  6. CONFERENCIA
-- ###########################################################################
--  ESPERADO: 1 coluna, 1 check, 1 indice, 1 comentario.
--
--  Alias com prefixo qtd_ de proposito: TRIGGER e palavra RESERVADA no Oracle e
--  ja quebrou um script desta pasta com ORA-00923. Conferir em
--  v$reserved_words where reserved = 'Y'.
select (select count(*) from all_tab_columns
         where owner='POSEIDON' and table_name='DPC_DFE_NOTA'
           and column_name='SIG_PAPEL_EMPRESA')                as qtd_coluna,
       (select count(*) from all_constraints
         where owner='POSEIDON' and constraint_name='DPC_DFE_NOTA_CK3')  as qtd_check,
       (select count(*) from all_indexes
         where owner='POSEIDON' and index_name='DPCI_DFE_NOTA_PAPEL')    as qtd_indice,
       (select count(*) from all_col_comments
         where owner='POSEIDON' and table_name='DPC_DFE_NOTA'
           and column_name='SIG_PAPEL_EMPRESA' and comments is not null) as qtd_comentario
  from dual;

--  DEPOIS do backfill: a distribuicao por papel, que e o que a tela vai mostrar.
select n.sig_papel_empresa                     as papel,
       n.dsc_tipo_doc,
       count(*)                                as notas
  from poseidon.dpc_dfe_nota n
 group by n.sig_papel_empresa, n.dsc_tipo_doc
 order by 3 desc;

--  Nota sem papel depois do backfill deve ser ZERO. Se sobrar, o documento
--  daquela nota nao voltou para a fila ou falhou - olhar status_process.
select e.nro_empresa, n.chave_nf, n.dsc_tipo_doc, d.status_process, d.det_erro
  from poseidon.dpc_dfe_nota      n
  join poseidon.dpc_dfe_empresa   e on e.cod_dfe_empresa = n.cod_dfe_empresa
  left join poseidon.dpc_dfe_documento d
         on d.chave_nf        = n.chave_nf
        and d.cod_dfe_empresa = n.cod_dfe_empresa
 where n.sig_papel_empresa is null
 order by e.nro_empresa, n.chave_nf;
-- ============================================================================


-- ###########################################################################
-- #
-- #  SECAO 3 - DPC_DFE_NOTA.VLR_TOTAL_PRODUTO - o vProd do ICMSTot
-- #
-- #  vinha de: v9_total_produto_nota_dbeaver.sql   (git ApiNFE: 1bdc4a7)
-- #
-- ###########################################################################

-- ============================================================================
--  v9 - TOTAL DE PRODUTOS DA NF-e  (poseidon.dpc_dfe_nota.vlr_total_produto)
-- ============================================================================
--  Para ambiente que JA TEM a estrutura do modulo instalada.
--
--  Instalacao NOVA nao precisa deste arquivo: a coluna ja esta no
--  ../producao/01_estrutura_dbeaver.sql. As duas definicoes saem do MESMO
--  gerador, de proposito.
--
--  Como POSEIDON, script inteiro com Alt+X. Sem "/" para terminar bloco.
--  Reexecutavel: cada objeto e criado somente se ainda nao existir.
--
--  ==========================================================================
--   POR QUE ESTA COLUNA - a conferencia estava comparando grandezas diferentes
--  ==========================================================================
--  A aba Conferencia do Monitor DFe existe para achar EXTRACAO INCOMPLETA:
--  nota cujos itens nao foram todos interpretados. Ela comparava
--
--      dpc_dfe_nota.vlr_nota   contra   sum(dpc_dfe_nota_item.vlr_produto)
--
--  e isso esta errado por definicao do layout da NF-e. Sao duas grandezas
--  diferentes dentro do proprio <ICMSTot>:
--
--      vProd = soma dos <prod><vProd> dos itens
--      vNF   = vProd - vDesc + vFrete + vSeg + vOutro + vST + vIPI + ...
--
--  Ou seja, TODA nota com desconto ou frete aparecia como divergente. Medido em
--  01/09/2026 no ambiente de teste: nove notas acusadas, e tres delas divergiam
--  em exatamente 5,00% - desconto comercial, nao defeito de extracao.
--
--  Pior que o falso positivo: com a lista poluida, uma extracao REALMENTE
--  incompleta passaria despercebida no meio. Um alerta que sempre acusa nao
--  alerta nada.
--
--  Com vlr_total_produto guardando o vProd do ICMSTot, a conferencia passa a
--  comparar duas leituras independentes DA MESMA grandeza:
--
--      vlr_total_produto  (declarado pelo emitente no totalizador)
--   contra
--      sum(vlr_produto)   (que o nosso parser somou item a item)
--
--  Divergencia ai e defeito de verdade.
--
--  ==========================================================================
--   POR QUE A COLUNA ACEITA NULL
--  ==========================================================================
--  O resNFe - o RESUMO - nao tem <ICMSTot>. Ele traz vNF e mais nada de
--  totalizador. Entao nota que so tem resumo fica com vlr_total_produto nulo, e
--  isso e correto: nao ha o que conferir enquanto o XML completo nao chegar.
--
--  A conferencia deve, portanto, filtrar por dsc_tipo_doc = 'procNF' E por
--  vlr_total_produto is not null. Nulo nao e zero.
-- ============================================================================


-- ----------------------------------------------------------------------------
--  1. A COLUNA
-- ----------------------------------------------------------------------------
declare
  qtd number;
begin
  select count(*) into qtd from all_tab_columns
   where owner = 'POSEIDON' and table_name = 'DPC_DFE_NOTA'
     and column_name = 'VLR_TOTAL_PRODUTO';

  if qtd = 0 then
    execute immediate 'alter table poseidon.dpc_dfe_nota add vlr_total_produto NUMBER';
  end if;
end;

comment on column poseidon.dpc_dfe_nota.vlr_total_produto is
  'vProd do ICMSTot - soma dos produtos declarada pelo emitente. NAO e o total da nota (vlr_nota / vNF), que ainda desconta vDesc e soma frete, seguro, outros, ST e IPI. Serve para conferir contra sum(dpc_dfe_nota_item.vlr_produto): sao duas leituras independentes da MESMA grandeza. Nulo em nota que so tem resumo, porque o resNFe nao traz ICMSTot.';


-- ----------------------------------------------------------------------------
--  2. CONFERENCIA - quantas notas ja tem o valor
-- ----------------------------------------------------------------------------
--  Logo apos o alter, TODAS ficam sem: a coluna e populada pelo parser, na
--  normalizacao. Ver a secao 3.
select count(*)                                                          as qtd_nota_completa,
       sum(case when vlr_total_produto is not null then 1 else 0 end)     as qtd_com_total,
       sum(case when vlr_total_produto is null     then 1 else 0 end)     as qtd_sem_total
  from poseidon.dpc_dfe_nota
 where dsc_tipo_doc = 'procNF';


-- ----------------------------------------------------------------------------
--  3. POPULAR O ACERVO JA CAPTURADO
-- ----------------------------------------------------------------------------
--  NAO custa nenhuma chamada a SEFAZ: os XML estao guardados em
--  dpc_dfe_documento e o parser so reinterpreta o que ja esta no banco.
--
--    update poseidon.dpc_dfe_documento
--       set status_process = 'P', qtd_tentativa = 0
--     where dsc_tipo_doc = 'procNF';
--    commit;
--
--  e entao, no container da ApiNFE:
--
--    php artisan dfe:normalizar --limit=5 --dry-run    -- confere primeiro
--    php artisan dfe:normalizar
--
--  Reprocessar procNF e seguro: a nota e atualizada pela UK (empresa, chave), o
--  emitente pela UK do CNPJ e os itens sao SUBSTITUIDOS por nota. Nada duplica.


-- ----------------------------------------------------------------------------
--  4. A CONFERENCIA CORRETA - depois de popular
-- ----------------------------------------------------------------------------
--  Compara o total declarado com a soma que o parser extraiu. Itens marcados
--  como "nao compoe o total" (indTot = 0) ficam de fora dos DOIS lados: o
--  emitente tambem nao os soma no vProd.
--
--  Resultado esperado: NENHUMA linha. Cada linha aqui e uma nota cujos itens
--  nao foram todos interpretados - defeito de verdade, nao desconto.
select e.nro_empresa,
       n.nro_nf,
       n.chave_nf,
       n.vlr_total_produto                                    as total_declarado,
       (select round(sum(i.vlr_produto), 2)
          from poseidon.dpc_dfe_nota_item i
         where i.cod_dfe_nota = n.cod_dfe_nota
           and nvl(i.status_compoe_total, '1') = '1')          as soma_dos_itens,
       (select count(*)
          from poseidon.dpc_dfe_nota_item i
         where i.cod_dfe_nota = n.cod_dfe_nota)                as qtd_item,
       n.vlr_nota                                              as total_da_nota
  from poseidon.dpc_dfe_nota    n
  join poseidon.dpc_dfe_empresa e on e.cod_dfe_empresa = n.cod_dfe_empresa
 where n.dsc_tipo_doc = 'procNF'
   and n.vlr_total_produto is not null
   and abs(n.vlr_total_produto
         - nvl((select round(sum(i.vlr_produto), 2)
                  from poseidon.dpc_dfe_nota_item i
                 where i.cod_dfe_nota = n.cod_dfe_nota
                   and nvl(i.status_compoe_total, '1') = '1'), 0)) > 0.02
 order by e.nro_empresa, n.nro_nf;


-- ###########################################################################
-- #
-- #  SECAO 4 - DPC_DFE_CTE_EVENTO - eventos de CT-e (entrega e cancelamento)
-- #
-- #  vinha de: v10_cte_evento_dbeaver.sql   (git ApiNFE: 77771bc)
-- #
-- ###########################################################################

-- ============================================================================
--  v10 - EVENTOS DE CT-e  (poseidon.dpc_dfe_cte_evento)
-- ============================================================================
--  Para ambiente que JA TEM a estrutura do modulo instalada.
--
--  Instalacao NOVA nao precisa deste arquivo: a tabela ja esta no
--  ../producao/01_estrutura_dbeaver.sql. As duas definicoes saem do MESMO
--  gerador, de proposito.
--
--  Como POSEIDON, script inteiro com Alt+X. Sem "/" para terminar bloco.
--  Reexecutavel: cada objeto e criado somente se ainda nao existir.
--
--  ==========================================================================
--   POR QUE ESTA TABELA
--  ==========================================================================
--  O CTeDistribuicaoDFe entrega eventos junto com os CT-e, e ate agora eles
--  caiam em IGNORADO por falta de parser: 3.085 documentos guardados em
--  dpc_dfe_documento e invisiveis para consulta. Medido numa amostra
--  aleatoria de 120, em 02/09/2026:
--
--     65  310610  MDF-e Autorizado          - o CT-e entrou num manifesto
--     35  110180  Comprovante de Entrega    - a prova de entrega
--     18  110181  Cancelamento do comprovante
--      1  110111  Cancelamento do CT-e
--      1  110110  Carta de Correcao
--
--  Dois deles mudam decisao:
--
--  110111 CANCELAMENTO. Hoje o CT-e e normalizado com cod_situacao e nada
--  atualiza esse campo quando o frete e cancelado. A base guarda um CT-e que
--  parece valido e nao e - em conferencia de frete, isso e pagamento
--  indevido. E 1% do volume e 100% do risco.
--
--  110180 COMPROVANTE DE ENTREGA. Prova eletronica de que a transportadora
--  entregou, com data e hora. E a evidencia em disputa de mercadoria
--  faltante e o que fecha o ciclo de recebimento.
--
--  ==========================================================================
--   POR QUE TABELA SEPARADA, E NAO dpc_dfe_evento
--  ==========================================================================
--  A de NF-e tem chave_nf e FK para dpc_dfe_nota. Guardar chave de CT-e numa
--  coluna chamada chave_nf, com a FK para a nota sempre nula, funcionaria e
--  seria o tipo de atalho que confunde quem chega depois. A chave e a FK
--  apontam para outro documento, entao a tabela e outra.
--
--  ==========================================================================
--   EVENTO ORFAO E NORMAL
--  ==========================================================================
--  cod_dfe_cte aceita NULO: o evento chega antes do CT-e com frequencia.
--  Descartar seria perda definitiva - a SEFAZ retem por 90 dias. A chave fica
--  gravada e o religamento acontece quando o documento aparecer.
-- ============================================================================


-- ----------------------------------------------------------------------------
--  1. SEQUENCE
-- ----------------------------------------------------------------------------
declare
  qtd number;
begin
  select count(*) into qtd from all_sequences
   where sequence_owner = 'POSEIDON' and sequence_name = 'DPCS_DFE_CTE_EVENTO';

  if qtd = 0 then
    execute immediate 'create sequence poseidon.dpcs_dfe_cte_evento start with 1 increment by 1 nocache';
  end if;
end;


-- ----------------------------------------------------------------------------
--  2. TABELA
-- ----------------------------------------------------------------------------
declare
  qtd number;
begin
  select count(*) into qtd from all_tables
   where owner = 'POSEIDON' and table_name = 'DPC_DFE_CTE_EVENTO';

  if qtd = 0 then
    execute immediate q'[create table poseidon.dpc_dfe_cte_evento
    (
      cod_dfe_cte_evento NUMBER not null,
      cod_dfe_empresa    NUMBER not null,
      cod_dfe_cte        NUMBER,
      chave_cte          VARCHAR2(44) not null,
      nro_nsu            NUMBER,
      cod_tipo_evento    VARCHAR2(6),
      dsc_evento         VARCHAR2(255),
      nro_seq_evento     NUMBER default 1 not null,
      nro_protocolo      VARCHAR2(20),
      cod_status         VARCHAR2(5),
      dsc_motivo         VARCHAR2(255),
      dta_evento         TIMESTAMP(6),
      num_cnpj_autor     VARCHAR2(14),
      dta_entrega        TIMESTAMP(6),
      num_doc_recebedor  VARCHAR2(60),
      dsc_nome_recebedor VARCHAR2(60),
      dsc_hash_entrega   VARCHAR2(60),
      chave_mdfe         VARCHAR2(44),
      created_at         DATE default sysdate,
      created_by         VARCHAR2(50)
    )
    tablespace TSD_POSEIDON
    ]';
  end if;
end;


-- ----------------------------------------------------------------------------
--  3. CONSTRAINTS
-- ----------------------------------------------------------------------------
declare
  qtd number;
begin
  select count(*) into qtd from all_constraints
   where owner = 'POSEIDON' and constraint_name = 'DPC_DFE_CTE_EVENTO_PK';

  if qtd = 0 then
    execute immediate q'[alter table poseidon.dpc_dfe_cte_evento
      add constraint DPC_DFE_CTE_EVENTO_PK primary key (cod_dfe_cte_evento) using index tablespace TSD_POSEIDON]';
  end if;
end;

declare
  qtd number;
begin
  select count(*) into qtd from all_constraints
   where owner = 'POSEIDON' and constraint_name = 'DPC_DFE_CTE_EVENTO_UK1';

  if qtd = 0 then
    execute immediate q'[alter table poseidon.dpc_dfe_cte_evento
      add constraint DPC_DFE_CTE_EVENTO_UK1 unique (chave_cte, cod_tipo_evento, nro_seq_evento) using index tablespace TSD_POSEIDON]';
  end if;
end;

declare
  qtd number;
begin
  select count(*) into qtd from all_constraints
   where owner = 'POSEIDON' and constraint_name = 'DPC_DFE_CTE_EVENTO_FK1';

  if qtd = 0 then
    execute immediate q'[alter table poseidon.dpc_dfe_cte_evento
      add constraint DPC_DFE_CTE_EVENTO_FK1 foreign key (cod_dfe_empresa) references poseidon.dpc_dfe_empresa (cod_dfe_empresa)]';
  end if;
end;

declare
  qtd number;
begin
  select count(*) into qtd from all_constraints
   where owner = 'POSEIDON' and constraint_name = 'DPC_DFE_CTE_EVENTO_FK2';

  if qtd = 0 then
    execute immediate q'[alter table poseidon.dpc_dfe_cte_evento
      add constraint DPC_DFE_CTE_EVENTO_FK2 foreign key (cod_dfe_cte) references poseidon.dpc_dfe_cte (cod_dfe_cte)]';
  end if;
end;


-- ----------------------------------------------------------------------------
--  4. INDICES
-- ----------------------------------------------------------------------------
--  eventos de um CT-e, e o religamento de orfao
declare
  qtd number;
begin
  select count(*) into qtd from all_indexes
   where owner = 'POSEIDON' and index_name = 'DPC_DFE_CTE_EVENTO_IX1';

  if qtd = 0 then
    execute immediate 'create index poseidon.DPC_DFE_CTE_EVENTO_IX1 on poseidon.dpc_dfe_cte_evento (cod_dfe_cte) tablespace TSD_POSEIDON';
  end if;
end;

--  FK sem indice
declare
  qtd number;
begin
  select count(*) into qtd from all_indexes
   where owner = 'POSEIDON' and index_name = 'DPC_DFE_CTE_EVENTO_IX2';

  if qtd = 0 then
    execute immediate 'create index poseidon.DPC_DFE_CTE_EVENTO_IX2 on poseidon.dpc_dfe_cte_evento (cod_dfe_empresa) tablespace TSD_POSEIDON';
  end if;
end;

--  comprovante de entrega por periodo - a consulta que motivou a tabela. Nulo na maioria das linhas (so o evento 110180 preenche) e o Oracle NAO indexa nulo: o indice fica pequeno e serve exatamente a busca util
declare
  qtd number;
begin
  select count(*) into qtd from all_indexes
   where owner = 'POSEIDON' and index_name = 'DPCI_DFE_CTE_EVENTO_ENTR';

  if qtd = 0 then
    execute immediate 'create index poseidon.DPCI_DFE_CTE_EVENTO_ENTR on poseidon.dpc_dfe_cte_evento (dta_entrega) tablespace TSD_POSEIDON';
  end if;
end;


-- ----------------------------------------------------------------------------
--  5. TRIGGER DA PK
-- ----------------------------------------------------------------------------
--  A aplicacao NUNCA seta a PK - padrao de todo o modulo.
create or replace trigger poseidon.dpct_dfe_cte_evento
  before insert on poseidon.dpc_dfe_cte_evento
  for each row
begin
  if :new.cod_dfe_cte_evento is null then
    select poseidon.dpcs_dfe_cte_evento.nextval into :new.cod_dfe_cte_evento from dual;
  end if;
end;


-- ----------------------------------------------------------------------------
--  6. COMENTARIOS
-- ----------------------------------------------------------------------------
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


-- ----------------------------------------------------------------------------
--  7. CONFERENCIA DA ESTRUTURA
-- ----------------------------------------------------------------------------
select (select count(*) from all_tab_columns
         where owner = 'POSEIDON' and table_name = 'DPC_DFE_CTE_EVENTO')          as qtd_coluna,
       (select count(*) from all_constraints
         where owner = 'POSEIDON' and table_name = 'DPC_DFE_CTE_EVENTO')          as qtd_constraint,
       (select count(*) from all_indexes
         where owner = 'POSEIDON' and table_name = 'DPC_DFE_CTE_EVENTO')          as qtd_indice,
       (select count(*) from all_triggers
         where owner = 'POSEIDON' and table_name = 'DPC_DFE_CTE_EVENTO')          as qtd_trigger
  from dual;
--  Esperado: 20 colunas, 4 constraints, 5 indices (proprios + PK/UK), 1 trigger.


-- ----------------------------------------------------------------------------
--  8. POPULAR O ACERVO JA CAPTURADO
-- ----------------------------------------------------------------------------
--  NAO custa nenhuma chamada a SEFAZ: os XML estao guardados e o parser so
--  reinterpreta o que ja esta no banco.
--
--    update poseidon.dpc_dfe_documento
--       set status_process = 'P', qtd_tentativa = 0
--     where dsc_tipo_doc = 'procEvCTe';
--    commit;
--
--  e entao, no container da ApiNFE:
--
--    php artisan dfe:normalizar --limit=5 --dry-run    -- confere primeiro
--    php artisan dfe:normalizar
--
--  Reprocessar e seguro: a UK (chave_cte, tipo, seq) torna a gravacao
--  idempotente - rodar duas vezes nao duplica evento.


-- ----------------------------------------------------------------------------
--  9. O QUE OLHAR DEPOIS DE POPULAR
-- ----------------------------------------------------------------------------
--  Distribuicao por tipo, e quantos religaram no CT-e.
select v.cod_tipo_evento,
       min(v.dsc_evento)                                            as dsc_evento,
       count(*)                                                     as qtd,
       sum(case when v.cod_dfe_cte is not null then 1 else 0 end)    as qtd_com_cte,
       sum(case when v.cod_dfe_cte is null     then 1 else 0 end)    as qtd_orfao
  from poseidon.dpc_dfe_cte_evento v
 group by v.cod_tipo_evento
 order by 3 desc;

--  Comprovantes de entrega, que e a consulta que motivou a tabela.
select e.nro_empresa,
       c.chave_cte,
       c.nro_cte,
       to_char(v.dta_entrega, 'dd/mm/yyyy hh24:mi')                 as entregue_em,
       v.dsc_nome_recebedor,
       v.num_doc_recebedor,
       c.vlr_prestacao
  from poseidon.dpc_dfe_cte_evento v
  join poseidon.dpc_dfe_empresa e on e.cod_dfe_empresa = v.cod_dfe_empresa
  left join poseidon.dpc_dfe_cte c on c.cod_dfe_cte    = v.cod_dfe_cte
 where v.cod_tipo_evento = '110180'
   and v.dta_entrega is not null
 order by v.dta_entrega desc;
--  ATENCAO: nDoc e xNome chegam MASCARADOS em parte dos eventos (vimos
--  literalmente ".." no XML). Campo vazio aqui e o normal, nao defeito.

--  CT-e cancelados - o risco financeiro. Nenhuma linha e o esperado.
select e.nro_empresa, c.chave_cte, c.nro_cte, c.vlr_prestacao,
       c.dsc_situacao                                               as situacao_do_cte,
       to_char(v.dta_evento, 'dd/mm/yyyy hh24:mi')                  as cancelado_em
  from poseidon.dpc_dfe_cte_evento v
  join poseidon.dpc_dfe_cte     c on c.cod_dfe_cte     = v.cod_dfe_cte
  join poseidon.dpc_dfe_empresa e on e.cod_dfe_empresa = v.cod_dfe_empresa
 where v.cod_tipo_evento = '110111'
   and nvl(c.cod_situacao, 1) <> 3
 order by v.dta_evento desc;
--  Linha aqui significa CT-e com evento de cancelamento cujo cod_situacao NAO
--  foi atualizado - exatamente o pagamento indevido que a tabela evita.


-- ==========================================================================
--  FIM DAS ALTERACOES DE ESTRUTURA.
--
--  Proximo e ultimo passo: ../04_parametros_dbeaver.sql
--  Roda ANTES do deploy do codigo - sem aquelas linhas o freio de consumo
--  indevido volta ao default 5, fica abaixo do ruido normal, e o motor se
--  recusa a consultar a SEFAZ em silencio.
--
--  Conferencia da estrutura: rode a secao 6 do
--  03_validacao_dbeaver.sql nos dois ambientes e compare.
-- ==========================================================================
