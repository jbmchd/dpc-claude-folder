-- ============================================================================
--  MODULO DFe - NFS-e: TIPO DE EMISSAO, DATAS E ENDERECO (ARQUIVO 07_01)
-- ============================================================================
--  Tabela alterada: poseidon.dpc_dfe_nfse (12 colunas novas, todas nulaveis)
--
--  ==========================================================================
--   O DEFEITO QUE MOTIVOU ESTE BLOCO
--  ==========================================================================
--  O parser tratava o cStat da NFS-e como SITUACAO (100 autorizada, 101/102
--  cancelada, resto nulo). No padrao nacional o cStat e o TIPO DE EMISSAO:
--
--    Anexo I - leiaute DPS/NFS-e, campo NFSe/infNFSe/cStat
--    https://www.gov.br/nfse/pt-br/biblioteca/documentacao-tecnica/documentacao-atual
--      v1.00: 100 Gerada | 101 de Substituicao Gerada | 102 de Decisao
--             Judicial ou Administrativa | 103 Avulsa | 107 MEI
--      v1.01 (09/02/2026): o 101 sai da lista; o resto se mantem.
--
--  Nenhum desses codigos significa cancelada. Medido em homolog 02/10/2026:
--  1.063 NFS-e MEI (107) e 3 avulsas (103) com situacao NULA, e 5 notas
--  substitutas (101) - validas - marcadas como CANCELADA.
--
--  Cancelamento chega por EVENTO. Anexo II (eventos) v1.01, aba TIPO EVENTOS,
--  e Resolucao CGNFS-e 3/2023 art. 8: tornam a nota sem efeito
--    e101101 Cancelamento | e105102 Cancelamento por Substituicao |
--    e105104 Cancelamento Deferido por Analise Fiscal |
--    e305101 Cancelamento por Oficio.
--  O motor so conhecia o e101101. Os 29 e105102 do acervo passavam sem
--  efeito, e 27 notas substituidas apareciam como validas.
--
--  >>> ORDEM OBRIGATORIA: o codigo da ApiNFE que grava estas colunas so pode
--  >>> ir ao ar DEPOIS deste script. Antes dele, todo insert de NFS-e falha
--  >>> com ORA-00904 e a normalizacao de NFS-e para.
--
--  ==========================================================================
--   COMO RODAR (DBeaver)
--  ==========================================================================
--  Conectado como POSEIDON, arquivo INTEIRO com Alt+X. Idempotente: coluna
--  que ja existe e pulada. Bloco PL/SQL no molde do 04_02: q'[...]' e sem a
--  barra final - com aspas simples e '/', o DBeaver devolve PLS-00103 e
--  ORA-00900. Rollback: 07_99_rollback_nfse_tipo_emissao_dbeaver.sql.
-- ============================================================================


-- ============================================================================
--  SECAO 1 - COLUNAS
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
  tipos t_lista := t_lista(
    'NUMBER(3)',
    'VARCHAR2(40)',
    'DATE',
    'DATE',
    'VARCHAR2(50)',
    'VARCHAR2(150)',
    'VARCHAR2(150)',
    'VARCHAR2(255)',
    'VARCHAR2(60)',
    'VARCHAR2(156)',
    'VARCHAR2(60)',
    'VARCHAR2(8)'
  );
  qtd number;
begin
  for i in 1 .. nomes.count loop
    select count(*) into qtd from all_tab_columns
     where owner = 'POSEIDON' and table_name = 'DPC_DFE_NFSE'
       and column_name = upper(nomes(i));

    if qtd = 0 then
      execute immediate q'[alter table poseidon.dpc_dfe_nfse add (]'
                        || nomes(i) || ' ' || tipos(i) || ')';
      dbms_output.put_line('criada: ' || nomes(i));
    else
      dbms_output.put_line(nomes(i) || ' ja existe.');
    end if;
  end loop;
exception
  when others then
    dbms_output.put_line('DPC_DFE_NFSE: FALHOU -> ' || sqlerrm);
end;


-- ============================================================================
--  SECAO 2 - COMENTARIOS
-- ============================================================================

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

comment on column poseidon.dpc_dfe_nfse.cod_situacao is
    'Situacao: 1 autorizada, 3 sem efeito (cancelada). Vem SO de evento de cancelamento; o cStat da nota nunca cancela.';


-- ============================================================================
--  SECAO 3 - CONFERENCIA
-- ============================================================================
--  Esperado: 12 linhas.

select column_name, data_type, data_length, nullable
  from all_tab_columns
 where owner = 'POSEIDON' and table_name = 'DPC_DFE_NFSE'
   and column_name in ('COD_TIPO_EMISSAO', 'DSC_TIPO_EMISSAO', 'DTA_EMISSAO', 'DTA_CANCELAMENTO', 'CHAVE_NFSE_SUBSTITUTA', 'DSC_LOCAL_EMISSAO', 'DSC_LOCAL_PRESTACAO', 'DSC_LOGRADOURO_PREST', 'NRO_ENDERECO_PREST', 'DSC_COMPLEMENTO_PREST', 'DSC_BAIRRO_PREST', 'NUM_CEP_PREST')
 order by column_id;
