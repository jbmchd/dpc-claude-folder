-- ============================================================================
--  MODULO DFe - REPROCESSAR NFS-e E SEUS EVENTOS (situacao, datas, endereco)
-- ============================================================================
--  Recoloca na fila de normalizacao (status_process = 'P') os documentos do
--  ADN ja processados, para que o parser corrigido em 02/10/2026 regrave as
--  NFS-e com a situacao certa e preencha as colunas do 07_01.
--
--  Nao chama o ADN nem a SEFAZ: o normalizador le o bruto ja guardado em
--  dpc_dfe_documento.
--
--  ==========================================================================
--   PRE-REQUISITOS - NESTA ORDEM
--  ==========================================================================
--   1. ddl/07_01_nfse_tipo_emissao_dbeaver.sql aplicado (12 colunas novas).
--   2. ApiNFE com o parser novo no ar no servidor 16.
--  Sem os dois, o reprocessamento ou falha (ORA-00904) ou regrava o erro
--  antigo.
--
--  ==========================================================================
--   POR QUE DUAS ETAPAS, E NESTA ORDEM
--  ==========================================================================
--  A guarda de DfeNfseRepository::salva() so protege cancelamento que veio
--  de EVENTO, e o sinal disso e dta_cancelamento preenchida. Hoje as 75
--  canceladas de verdade ainda nao tem essa data.
--
--  Se as notas rodassem primeiro, as 75 voltariam a AUTORIZADA ate o evento
--  ser reaplicado. Rodando os eventos primeiro, elas ganham a data, ficam
--  protegidas, e a etapa 2 nao as toca. E isso que permite a guarda NAO
--  proteger as 5 substitutas (cStat 101) que o parser antigo marcou como
--  canceladas sem evento nenhum: elas nao recebem data e voltam a AUTORIZADA.
--
--  ETAPA 1 -> esperar a fila zerar (SECAO 3) -> ETAPA 2.
--
--  ==========================================================================
--   CARIMBO
--  ==========================================================================
--  det_erro = 'REPROCESSO 2026-10-02 NFSE' marca o que este script colocou na
--  fila. O normalizador limpa det_erro ao concluir, entao o carimbo mostra o
--  que AINDA esta pendente - e e por ele que o rollback age.
--
--  ==========================================================================
--   FOTO MEDIDA EM HOMOLOG, 02/10/2026 (lendo o cStat de cada XML)
--  ==========================================================================
--    cStat  situacao gravada          qtd    leitura
--    100    1 AUTORIZADA             9.254   certo
--    100    3 Cancelada (evento)        35   certo - cancelamento real
--    107    3 Cancelada (evento)        40   certo - cancelamento real
--    101    3 CANCELADA (parser)         5   ERRADO - substituta, vale
--    107    nulo 'CSTAT 107'         1.063   ERRADO - MEI autorizada
--    103    nulo 'CSTAT 103'             3   ERRADO - avulsa autorizada
--    e105102 sobre nota na base         27   ERRADO - substituida, segue 1
--
--  Esperado depois: 102 canceladas (75 + 27), 10.298 autorizadas, 0 nulas.
--
--  >>> APLICADO em homolog em 02/10/2026, as duas etapas. Resultado medido:
--  >>> 102 canceladas, todas com dta_cancelamento e 27 com substituta;
--  >>> 10.298 autorizadas; 0 sem situacao; 0 documentos em erro.
--
--  Conectado como POSEIDON. Rodar cada etapa separadamente (selecionar o
--  bloco e Ctrl+Enter), nao o arquivo inteiro.
-- ============================================================================


-- ============================================================================
--  SECAO 0 - FOTO ANTES (guardar o resultado)
-- ============================================================================

select cod_situacao, dsc_situacao,
       count(*)                as qtd,
       round(sum(vlr_servico), 2) as valor
  from poseidon.dpc_dfe_nfse
 group by cod_situacao, dsc_situacao
 order by 1, 2;


-- ============================================================================
--  SECAO 1 - ETAPA 1: EVENTOS (107 documentos)
-- ============================================================================

update poseidon.dpc_dfe_documento
   set status_process = 'P',
       det_erro       = 'REPROCESSO 2026-10-02 NFSE'
 where dsc_tipo_doc = 'adnEvento'
   and status_process in ('C', 'I');

commit;


-- ============================================================================
--  SECAO 2 - ETAPA 2: NOTAS (10.400 documentos)
-- ============================================================================
--  So depois que a SECAO 3 mostrar zero pendentes de adnEvento.

update poseidon.dpc_dfe_documento
   set status_process = 'P',
       det_erro       = 'REPROCESSO 2026-10-02 NFSE'
 where dsc_tipo_doc = 'adnNFSe'
   and status_process = 'C';

commit;


-- ============================================================================
--  SECAO 3 - ACOMPANHAMENTO
-- ============================================================================

select dsc_tipo_doc, status_process, count(*) as qtd
  from poseidon.dpc_dfe_documento
 where dsc_tipo_doc in ('adnEvento', 'adnNFSe')
 group by dsc_tipo_doc, status_process
 order by 1, 2;


-- ============================================================================
--  SECAO 4 - CONFERENCIA FINAL
-- ============================================================================
--  Esperado, contra a foto da SECAO 0:
--    - nenhuma linha com cod_situacao nulo (eram 1.066: 1.063 MEI + 3 avulsas)
--    - cod_situacao 1 = 10.298
--    - cod_situacao 3 = 75 + 27 substituidas = 102, todas com dta_cancelamento
--      e 27 delas com chave_nfse_substituta
--    - dsc_situacao so 'AUTORIZADA' e 'CANCELADA' (sumem 'Cancelada' e 'CSTAT x')
--    - nenhuma cancelada sem data

select cod_situacao, dsc_situacao, count(*) as qtd,
       count(dta_cancelamento)      as com_data,
       count(chave_nfse_substituta) as substituidas,
       round(sum(vlr_servico), 2)   as valor
  from poseidon.dpc_dfe_nfse
 group by cod_situacao, dsc_situacao
 order by 1, 2;

select cod_tipo_emissao, dsc_tipo_emissao, count(*) as qtd,
       count(dta_emissao) as com_emissao, count(num_cep_prest) as com_cep
  from poseidon.dpc_dfe_nfse
 group by cod_tipo_emissao, dsc_tipo_emissao
 order by 1;
