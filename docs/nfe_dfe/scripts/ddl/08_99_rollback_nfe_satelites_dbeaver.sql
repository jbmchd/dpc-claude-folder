-- ============================================================================
--  MODULO DFe - ROLLBACK DO 08_01 (totais, transporte, cobranca e campos do XML)
-- ============================================================================
--  Remove as 3 tabelas satelite e as 31 colunas que o 08_01 criou.
--
--  ANTES de rodar: volte a ApiNFE para um commit anterior ao que grava estas
--  colunas, e a ApiDPC para um anterior ao que as le. Com o codigo novo no ar
--  e as colunas removidas, a normalizacao de NF-e falha com ORA-00904 e a
--  tela quebra ao montar a listagem.
--
--  DESTRUTIVO: o conteudo das tres tabelas se perde. Ele e reconstruivel a
--  partir dos XML em dpc_dfe_documento (e o que o ajuste unico de
--  reprocessamento faz), entao a perda e de tempo, nao de informacao.
--
--  Conectado como POSEIDON, arquivo INTEIRO com Alt+X. Idempotente.
-- ============================================================================


-- ============================================================================
--  SECAO 1 - O QUE SERA PERDIDO
-- ============================================================================

select 'dpc_dfe_nota_total'      as tabela, count(*) as linhas from poseidon.dpc_dfe_nota_total
union all
select 'dpc_dfe_nota_transporte', count(*) from poseidon.dpc_dfe_nota_transporte
union all
select 'dpc_dfe_nota_cobranca',   count(*) from poseidon.dpc_dfe_nota_cobranca;


-- ============================================================================
--  SECAO 2 - REMOCAO DAS TABELAS
-- ============================================================================

declare
  type t_lista is table of varchar2(200);
  nomes t_lista := t_lista(
    'dpc_dfe_nota_total',
    'dpc_dfe_nota_transporte',
    'dpc_dfe_nota_cobranca'
  );
  qtd number;
begin
  for i in 1 .. nomes.count loop
    select count(*) into qtd from all_tables
     where owner = 'POSEIDON' and table_name = upper(nomes(i));

    if qtd > 0 then
      execute immediate q'[drop table poseidon.]' || nomes(i) || ' purge';
      dbms_output.put_line('removida: ' || nomes(i));
    else
      dbms_output.put_line(nomes(i) || ' nao existe.');
    end if;
  end loop;
exception
  when others then
    dbms_output.put_line('TABELAS: FALHOU -> ' || sqlerrm);
end;


-- ============================================================================
--  SECAO 3 - REMOCAO DAS COLUNAS DE DPC_DFE_NOTA
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
  qtd number;
begin
  for i in 1 .. nomes.count loop
    select count(*) into qtd from all_tab_columns
     where owner = 'POSEIDON' and table_name = 'DPC_DFE_NOTA'
       and column_name = upper(nomes(i));

    if qtd > 0 then
      execute immediate q'[alter table poseidon.dpc_dfe_nota drop column ]' || nomes(i);
      dbms_output.put_line('removida: ' || nomes(i));
    else
      dbms_output.put_line(nomes(i) || ' nao existe.');
    end if;
  end loop;
exception
  when others then
    dbms_output.put_line('DPC_DFE_NOTA: FALHOU -> ' || sqlerrm);
end;


-- ============================================================================
--  SECAO 4 - CONFERENCIA
-- ============================================================================
--  Esperado: nenhuma linha nas duas consultas.

select table_name from all_tables
 where owner = 'POSEIDON'
   and table_name in ('DPC_DFE_NOTA_TOTAL','DPC_DFE_NOTA_TRANSPORTE','DPC_DFE_NOTA_COBRANCA');

select column_name from all_tab_columns
 where owner = 'POSEIDON' and table_name = 'DPC_DFE_NOTA'
   and column_name in ('DSC_NATUREZA_OPERACAO', 'COD_FINALIDADE', 'COD_CONSUMIDOR_FINAL', 'COD_PRESENCA', 'COD_REGIME_TRIB_EMIT', 'NUM_INSCR_EST_ST_EMIT', 'DSC_LOGRADOURO_EMIT', 'NRO_ENDERECO_EMIT', 'DSC_COMPLEMENTO_EMIT', 'DSC_BAIRRO_EMIT', 'COD_MUNICIPIO_EMIT', 'DSC_MUNICIPIO_EMIT', 'SIG_UF_EMIT', 'NUM_CEP_EMIT', 'NUM_FONE_EMIT', 'NUM_CNPJ_CPF_DEST', 'NUM_INSCR_ESTADUAL_DEST', 'COD_IND_IE_DEST', 'DSC_LOGRADOURO_DEST', 'NRO_ENDERECO_DEST', 'DSC_COMPLEMENTO_DEST', 'DSC_BAIRRO_DEST', 'COD_MUNICIPIO_DEST', 'DSC_MUNICIPIO_DEST', 'SIG_UF_DEST', 'NUM_CEP_DEST', 'NUM_FONE_DEST', 'DSC_INF_COMPLEMENTAR', 'DSC_INF_FISCO', 'DSC_NFE_REFERENCIADA', 'DSC_PEDIDO_COMPRA');
