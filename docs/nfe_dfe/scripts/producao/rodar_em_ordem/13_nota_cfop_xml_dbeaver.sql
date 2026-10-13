-- ===========================================================================
--  BLOCO 12_01 - CFOP do XML na nota (cod_cfop_xml)
-- ===========================================================================
--
--  Banco: Oracle (homolog)        Schema: poseidon
--  Tabela alterada: poseidon.dpc_dfe_nota (1 coluna nova, anulavel)
--  Rollback: 12_99_rollback_nota_cfop_xml_dbeaver.sql
--
--  ==========================================================================
--   POR QUE
--  ==========================================================================
--  Gestao de NFe (Sefaz > Gestao de NFe) classifica a nota em Compras,
--  Devolucao de Clientes, Suprimentos ou Sem Classificacao. A categoria sai do
--  CFOP e da ocorrencia de devolucao que o ERP grava (cod_cfop_erp,
--  dsc_ocorr_dev_erp) - e o dfe:conciliar so grava isso DEPOIS da
--  escrituracao.
--
--  Medido em 06/10/2026: 0 de 1.191 notas pendentes tem esses campos; 8.342 de
--  8.342 escrituradas tem. Toda pendente cai em "Sem Classificacao" por
--  construcao, e as abas Compras / Devolucao / Suprimentos aparecem vazias
--  justamente para quem trabalha as pendentes.
--
--  Esta coluna guarda o CFOP DECLARADO NO XML (o do item de maior valor, que e
--  o criterio que o proprio ERP usa para o CFOP da nota). Com ele a tela PREVE
--  a categoria enquanto a nota nao foi escriturada. A previsao acerta 99% das
--  notas que o ERP depois chama de Compras. O valor do ERP sempre vence apos a
--  escrituracao: esta coluna nunca substitui cod_cfop_erp.
--
--  Nao e coluna de dpc_dfe_nota_item de proposito: a tela consulta por nota, e
--  recalcular o item de maior valor a cada listagem seria subselect por linha.
--
--  ==========================================================================
--   SEM DEFAULT, ANULAVEL
--  ==========================================================================
--  Nulo significa "ainda nao calculado" ou "nota so com resumo (resNFe), que
--  nao traz item". Nao e erro. Sem DEFAULT para o Oracle nao reescrever a
--  tabela inteira.
--
--  ==========================================================================
--   DEPOIS DESTE BLOCO
--  ==========================================================================
--  1. Deploy da ApiNFE (passa a gravar a coluna em notas novas).
--  2. ajustes_unicos/2026-10-06_nota_cfop_xml.sql preenche as notas ja
--     existentes (9.582 notas com item).
--  3. So entao o deploy da ApiDPC (o CASE de categoria le a coluna).
--
--  ==========================================================================
--   ANTES DE RODAR: CONFIRA SE JA RODOU
--  ==========================================================================
--  Rode o SELECT do fim do arquivo. Se a coluna ja aparecer, nao rode de novo
--  (o alter repetido da ORA-01430, inofensivo mas desnecessario).
--
--  Sem bloco PL/SQL, pela regra do modulo: o divisor do DBeaver corta bloco e
--  o Oracle devolve PLS-00103.
--
--  Rodar no DBeaver com Execute script (Alt+X).
-- ===========================================================================


alter table poseidon.dpc_dfe_nota add (cod_cfop_xml NUMBER(4));

comment on column poseidon.dpc_dfe_nota.cod_cfop_xml is 'CFOP do XML: o do item de maior valor (empate: menor item). Nulo = nao calculado ou so resumo. NAO substitui cod_cfop_erp: serve para PREVER a categoria antes da escrituracao.';


-- ===========================================================================
--  CONFERENCIA - esperado: 1 linha, NUMBER, tamanho 4, anulavel (Y)
-- ===========================================================================

select column_name, data_type, data_precision, nullable
  from all_tab_columns
 where owner = 'POSEIDON' and table_name = 'DPC_DFE_NOTA' and column_name = 'COD_CFOP_XML';
