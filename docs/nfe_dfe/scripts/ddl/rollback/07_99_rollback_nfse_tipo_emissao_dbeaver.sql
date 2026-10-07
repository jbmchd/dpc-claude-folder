-- ============================================================================
--  MODULO DFe - ROLLBACK DO 07_01 (NFS-e: tipo de emissao, datas, endereco)
-- ============================================================================
--  Remove as 12 colunas que o 07_01 criou em poseidon.dpc_dfe_nfse.
--
--  ANTES de rodar: volte a ApiNFE para um commit anterior ao que grava estas
--  colunas. Com o codigo novo no ar e as colunas removidas, todo insert de
--  NFS-e falha com ORA-00904.
--
--  Nao desfaz a correcao de situacao: cod_situacao e dsc_situacao sao colunas
--  antigas e ficam como o reprocessamento as deixou.
--
--  Conectado como POSEIDON, arquivo INTEIRO com Alt+X. Idempotente.
-- ============================================================================


-- ============================================================================
--  SECAO 1 - O QUE SERA PERDIDO
-- ============================================================================

select count(*)                as nfse,
       count(cod_tipo_emissao) as com_tipo_emissao,
       count(dta_cancelamento) as com_data_cancelamento,
       count(num_cep_prest)    as com_endereco
  from poseidon.dpc_dfe_nfse;


-- ============================================================================
--  SECAO 2 - REMOCAO
-- ============================================================================

declare
  type t_lista is table of varchar2(200);
  nomes t_lista := t_lista(
    'cod_tipo_emissao',
    'dsc_tipo_emissao',
    'dta_emissao',
    'dta_cancelamento',
    'chave_nfse_substituta',
    'dsc_local_emissao',
    'dsc_local_prestacao',
    'dsc_logradouro_prest',
    'nro_endereco_prest',
    'dsc_complemento_prest',
    'dsc_bairro_prest',
    'num_cep_prest'
  );
  qtd number;
begin
  for i in 1 .. nomes.count loop
    select count(*) into qtd from all_tab_columns
     where owner = 'POSEIDON' and table_name = 'DPC_DFE_NFSE'
       and column_name = upper(nomes(i));

    if qtd > 0 then
      execute immediate q'[alter table poseidon.dpc_dfe_nfse drop column ]' || nomes(i);
      dbms_output.put_line('removida: ' || nomes(i));
    else
      dbms_output.put_line(nomes(i) || ' nao existe.');
    end if;
  end loop;
exception
  when others then
    dbms_output.put_line('DPC_DFE_NFSE: FALHOU -> ' || sqlerrm);
end;


-- ============================================================================
--  SECAO 3 - CONFERENCIA
-- ============================================================================
--  Esperado: nenhuma linha.

select column_name
  from all_tab_columns
 where owner = 'POSEIDON' and table_name = 'DPC_DFE_NFSE'
   and column_name in ('COD_TIPO_EMISSAO', 'DSC_TIPO_EMISSAO', 'DTA_EMISSAO', 'DTA_CANCELAMENTO', 'CHAVE_NFSE_SUBSTITUTA', 'DSC_LOCAL_EMISSAO', 'DSC_LOCAL_PRESTACAO', 'DSC_LOGRADOURO_PREST', 'NRO_ENDERECO_PREST', 'DSC_COMPLEMENTO_PREST', 'DSC_BAIRRO_PREST', 'NUM_CEP_PREST');
