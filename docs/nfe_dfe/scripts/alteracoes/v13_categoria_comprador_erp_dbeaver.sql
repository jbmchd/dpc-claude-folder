-- ============================================================================
--  v13 - CATEGORIA E COMPRADOR MATERIALIZADOS, para a tela nao ler o ERP
-- ============================================================================
--  Rodar como POSEIDON, no DBeaver, o arquivo INTEIRO com Alt+X. Sem barra para
--  terminar bloco. Reexecutavel.
--
--  POR QUE
--  -------
--  A v12 materializou a ETAPA da nota no ERP e a tela parou de cruzar com o
--  Consinco para saber o status. Mas duas informacoes continuavam vindo de
--  OUTER APPLY em tempo de consulta, e elas mantinham o problema todo:
--
--    categoria   <- CFOP do item de maior valor + mlf.ocorrenciadev
--    comprador   <- rf_notaitem -> map_produto -> map_famdivisao -> max_comprador
--
--  Dois motivos para materializar tambem:
--
--  1. OUTER APPLY nao atravessa conexao. Com as dpc_dfe_* em homologacao e o ERP
--     em producao, aquelas duas colunas vinham VAZIAS - o mesmo defeito que o
--     status tinha, so que silencioso: nota sem categoria cai em
--     SEM_CLASSIFICACAO, que parece dado e nao parece falha.
--
--  2. O comprador e a consulta mais cara da tela: quatro joins sobre
--     rf_notaitem, a cada carga de pagina. O proprio codigo dela ja carregava
--     aviso de performance.
--
--  GRAVA OS INSUMOS, NAO A CATEGORIA
--  ---------------------------------
--  Poderiamos gravar 'DEVOLUCAO'/'COMPRAS'/'SUPRIMENTOS' direto. Nao gravamos, e
--  a razao importa: as listas de CFOP sao regra de negocio e mudam. Categoria
--  gravada envelhece em silencio e exigiria reprocessar o acervo a cada ajuste
--  de regra.
--
--  Gravando CFOP e ocorrenciadev, o CASE continua num lugar so (na tela) e
--  qualquer mudanca de regra reclassifica tudo na hora, sem tocar em dado.
--
--  QUANDO E PREENCHIDO
--  -------------------
--  Pelo dfe:conciliar, quando a nota chega em ESCRITURADA - antes disso nao ha
--  rf_notaitem para ler. E NAO e reconsultado depois: CFOP e comprador de nota
--  escriturada nao mudam mais. Nota que regredir mantem o que tinha.
-- ============================================================================


-- ###########################################################################
--  1. AS COLUNAS
-- ###########################################################################
declare
  qtd number;
begin
  select count(*) into qtd from all_tab_columns
   where owner = 'POSEIDON' and table_name = 'DPC_DFE_NOTA'
     and column_name = 'COD_CFOP_ERP';

  if qtd = 0 then
    execute immediate 'alter table poseidon.dpc_dfe_nota add (
        cod_cfop_erp        number(5),
        dsc_ocorr_dev_erp   varchar2(5),
        seq_comprador_erp   number,
        dsc_comprador_erp   varchar2(40)
    )';
  end if;
end;


-- ###########################################################################
--  2. INDICE PARA O FILTRO DE COMPRADOR
-- ###########################################################################
--  A tela filtra por comprador e monta o "Top 5 por comprador". Sem indice isso
--  vira full scan em dpc_dfe_nota, que cresce com o acervo - projecao de ~11 mil
--  notas por dia depois do corte da Qive.
--
--  Composto com a empresa porque nenhum acesso da tela e global: a permissao de
--  empresa e aplicada antes de qualquer agregacao.
declare
  qtd number;
begin
  select count(*) into qtd from all_indexes
   where owner = 'POSEIDON' and index_name = 'DPCI_DFE_NOTA_COMPRADOR';

  if qtd = 0 then
    execute immediate 'create index poseidon.dpci_dfe_nota_comprador
        on poseidon.dpc_dfe_nota (cod_dfe_empresa, seq_comprador_erp)
      tablespace TSD_POSEIDON';
  end if;
end;


-- ###########################################################################
--  3. COMENTARIOS
-- ###########################################################################
comment on column poseidon.dpc_dfe_nota.cod_cfop_erp is
  'CFOP do item de MAIOR VALOR da nota, lido de consinco.rf_notaitem quando ela chega em ESCRITURADA. Insumo da categoria - a classificacao NAO e gravada, para que mudanca nas listas de CFOP reclassifique sem reprocessar.';

comment on column poseidon.dpc_dfe_nota.dsc_ocorr_dev_erp is
  'consinco.mlf_notafiscal.OCORRENCIADEV. Nao nulo = devolucao, e vence o CFOP na classificacao. Guardado o valor, e nao um flag, para nao perder informacao.';

comment on column poseidon.dpc_dfe_nota.seq_comprador_erp is
  'Comprador responsavel pelo item de maior valor (rf_notaitem -> map_produto -> map_famdivisao nrodivisao=1 -> max_comprador). E o que a tela FILTRA.';

comment on column poseidon.dpc_dfe_nota.dsc_comprador_erp is
  'Nome do comprador, para exibicao. Denormalizado de proposito: aqui e rotulo, nao chave - o vinculo e o seq_comprador_erp.';


-- ###########################################################################
--  4. CONFERENCIA
-- ###########################################################################
--  ESPERADO: 4 colunas e 1 indice.
select count(*) as colunas_novas
  from all_tab_columns
 where owner = 'POSEIDON' and table_name = 'DPC_DFE_NOTA'
   and column_name in ('COD_CFOP_ERP','DSC_OCORR_DEV_ERP',
                       'SEQ_COMPRADOR_ERP','DSC_COMPRADOR_ERP');

select index_name, column_name, column_position
  from all_ind_columns
 where index_owner = 'POSEIDON' and index_name = 'DPCI_DFE_NOTA_COMPRADOR'
 order by column_position;


-- ###########################################################################
--  5. DEPOIS DE RODAR
-- ###########################################################################
--  As colunas nascem NULAS. Quem preenche e o dfe:conciliar, e so para nota que
--  esta em ESCRITURADA. Como nota ja escriturada nao volta para a fila da
--  conciliacao, o acervo existente precisa de UMA passagem forcada:
--
--      php artisan dfe:conciliar --todas --dry-run --debug   -- confere
--      php artisan dfe:conciliar --todas
--
--  ESPERADO depois: as escrituradas com CFOP preenchido. Comprador pode faltar
--  legitimamente - o item de maior valor pode nao ter familia com divisao 1.
select nvl(sig_estado_erp,'(nao conciliada)')                      as estado,
       count(*)                                                    as notas,
       sum(case when cod_cfop_erp      is not null then 1 else 0 end) as com_cfop,
       sum(case when seq_comprador_erp is not null then 1 else 0 end) as com_comprador,
       sum(case when dsc_ocorr_dev_erp is not null then 1 else 0 end) as com_ocorr_dev
  from poseidon.dpc_dfe_nota
 group by nvl(sig_estado_erp,'(nao conciliada)')
 order by 2 desc;
-- ============================================================================
