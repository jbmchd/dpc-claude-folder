-- ============================================================================
--  MODULO DFe - REPROCESSAR AS NF-e COMPLETAS (campos do XML, DDL 08_01)
-- ============================================================================
--  Recoloca na fila de normalizacao (status_process = 'P') os 9.397 procNF ja
--  processados, para que o parser novo preencha os campos materializados em
--  02/10/2026: totais, transporte, cobranca, enderecos e informacoes
--  adicionais.
--
--  Nao chama a SEFAZ: o normalizador le o XML ja guardado em
--  dpc_dfe_documento. Nenhuma consulta externa, nenhum consumo de cota.
--
--  ==========================================================================
--   PRE-REQUISITOS
--  ==========================================================================
--   1. ddl/08_01_nfe_satelites_dbeaver.sql aplicado (3 tabelas + 31 colunas).
--   2. ApiNFE com o parser novo no ar no servidor 16 (commit 332cfb4 ou
--      posterior).
--  Sem os dois, o reprocessamento ou falha com ORA-00904 ou regrava o estado
--  antigo.
--
--  ==========================================================================
--   SO O procNF, E POR QUE
--  ==========================================================================
--  O resumo (resNFe) nao tem nenhum destes blocos. Reprocessa-lo nao traria
--  nada e ainda esbarraria no anti-rebaixamento, que recusa resumo sobre nota
--  ja completa. Sao 9.341 documentos que nao precisam entrar na fila.
--
--  ==========================================================================
--   O QUE MAIS E REFEITO DE CARONA (e por que e seguro)
--  ==========================================================================
--  Reprocessar o procNF nao grava so os campos novos. Tambem refaz:
--
--    itens         DfeNotaItemRepository APAGA e regrava os itens da nota,
--                  dentro de uma transacao. Sao 175.603 itens hoje; ao fim
--                  tem de haver o mesmo numero (a SECAO 4 confere).
--    emitente      upsert em dpc_dfe_emitente - mesmo CNPJ, mesmos dados.
--    papel         sig_papel_empresa recalculado a partir do XML.
--    situacao      PROTEGIDA: a guarda naoRebaixaSituacao (ApiNFE ba3f9bf)
--                  impede que o protocolo de autorizacao, cujo cStat e sempre
--                  100, devolva uma nota CANCELADA para AUTORIZADA. Sao 133
--                  canceladas hoje, e ao fim tem de continuar 133.
--
--  ==========================================================================
--   CARIMBO
--  ==========================================================================
--  det_erro = 'REPROCESSO 2026-10-02 NFE XML' marca o que este script
--  colocou na fila. O normalizador limpa det_erro ao concluir, entao o carimbo
--  mostra o que AINDA esta pendente - e e por ele que o rollback age.
--
--  ==========================================================================
--   COMO RODAR
--  ==========================================================================
--  Conectado como POSEIDON. Rodar bloco a bloco (selecionar e Ctrl+Enter),
--  nao o arquivo inteiro: a SECAO 0 e para guardar a foto antes.
--
--  Depois da SECAO 1, a fila drena pelo agendador (dfe:normalizar a cada 10
--  min, 500 por vez = ~3h) ou de uma vez pelo comando, acompanhado:
--      docker exec -d apinfe-app sh -c \
--        'php /var/www/artisan dfe:normalizar --limit=10000 > /tmp/reproc_nfe.log 2>&1'
-- ============================================================================


-- ============================================================================
--  SECAO 0 - FOTO ANTES (guardar o resultado)
-- ============================================================================

select (select count(*) from poseidon.dpc_dfe_nota)                      as notas,
       (select count(*) from poseidon.dpc_dfe_nota where dsc_tipo_doc = 'procNF') as completas,
       (select count(*) from poseidon.dpc_dfe_nota where cod_situacao = 3)        as canceladas,
       (select count(*) from poseidon.dpc_dfe_nota_item)                 as itens,
       (select count(*) from poseidon.dpc_dfe_nota_total)                as totais,
       (select count(*) from poseidon.dpc_dfe_nota_transporte)           as transporte,
       (select count(*) from poseidon.dpc_dfe_nota_cobranca)             as cobranca,
       (select count(dsc_natureza_operacao) from poseidon.dpc_dfe_nota)  as com_nat_op
  from dual;

select sig_papel_empresa, count(*) as qtd
  from poseidon.dpc_dfe_nota
 group by sig_papel_empresa
 order by 2 desc;


-- ============================================================================
--  SECAO 1 - COLOCAR NA FILA (9.397 documentos)
-- ============================================================================

update poseidon.dpc_dfe_documento
   set status_process = 'P',
       det_erro       = 'REPROCESSO 2026-10-02 NFE XML'
 where dsc_tipo_doc = 'procNF'
   and status_process = 'C';

commit;


-- ============================================================================
--  SECAO 2 - ACOMPANHAMENTO (rodar quantas vezes quiser)
-- ============================================================================

select status_process, count(*) as qtd
  from poseidon.dpc_dfe_documento
 where dsc_tipo_doc = 'procNF'
 group by status_process
 order by 1;


-- ============================================================================
--  SECAO 3 - DOCUMENTO QUE FALHOU (esperado: nenhuma linha)
-- ============================================================================

select d.nro_nsu, e.nro_empresa, d.qtd_tentativa, substr(d.det_erro, 1, 200) as erro
  from poseidon.dpc_dfe_documento d
  join poseidon.dpc_dfe_empresa e on e.cod_dfe_empresa = d.cod_dfe_empresa
 where d.dsc_tipo_doc = 'procNF'
   and d.status_process = 'E'
 order by d.nro_nsu;


-- ============================================================================
--  SECAO 4 - CONFERENCIA FINAL
-- ============================================================================
--  Contra a foto da SECAO 0:
--    notas, completas, canceladas e itens      IGUAIS (nada se perde)
--    totais                                    ~9.397 (ICMSTot em 100%)
--    transporte                                ~9.397 (o bloco transp sempre
--                                              existe, nem que so com modFrete)
--    cobranca                                  ~9.397 (pag existe em 100%)
--    com_nat_op                                ~9.397 (era 0)
--  Diferenca de algumas unidades e esperada: nota cujo XML nao tem o bloco.

select (select count(*) from poseidon.dpc_dfe_nota)                      as notas,
       (select count(*) from poseidon.dpc_dfe_nota where dsc_tipo_doc = 'procNF') as completas,
       (select count(*) from poseidon.dpc_dfe_nota where cod_situacao = 3)        as canceladas,
       (select count(*) from poseidon.dpc_dfe_nota_item)                 as itens,
       (select count(*) from poseidon.dpc_dfe_nota_total)                as totais,
       (select count(*) from poseidon.dpc_dfe_nota_transporte)           as transporte,
       (select count(*) from poseidon.dpc_dfe_nota_cobranca)             as cobranca,
       (select count(dsc_natureza_operacao) from poseidon.dpc_dfe_nota)  as com_nat_op
  from dual;

select sig_papel_empresa, count(*) as qtd
  from poseidon.dpc_dfe_nota
 group by sig_papel_empresa
 order by 2 desc;

--  Preenchimento de cada bloco, para comparar com a medicao dos 400 XML:
--    transportadora 24%, fatura 24%, reforma 94%, placa 0%
select count(*)                            as com_transporte,
       count(num_cnpj_cpf_transp)          as com_transportadora,
       count(num_placa_veiculo)            as com_placa,
       round(100 * count(num_cnpj_cpf_transp) / count(*), 1) as pct_transportadora
  from poseidon.dpc_dfe_nota_transporte;

select count(*)                  as com_cobranca,
       count(num_fatura)         as com_fatura,
       round(100 * count(num_fatura) / count(*), 1) as pct_fatura
  from poseidon.dpc_dfe_nota_cobranca;

select count(*)                  as com_totais,
       count(vlr_bc_ibscbs)      as com_reforma,
       count(vlr_total_tributo)  as com_total_tributo,
       round(100 * count(vlr_bc_ibscbs) / count(*), 1) as pct_reforma
  from poseidon.dpc_dfe_nota_total;

--  Os totais da nota batem com a soma dos itens? vICMS e o teste mais severo,
--  porque todo item contribui. Esperado: pouquissimas divergencias, e todas
--  explicaveis por item com ICMS ja retido por ST (ICMS60, que nao tem vICMS).
select count(*) as notas_conferidas,
       count(case when abs(nvl(t.vlr_icms,0) - nvl(i.soma,0)) > 0.05 then 1 end) as divergentes
  from poseidon.dpc_dfe_nota_total t
  join (select cod_dfe_nota, sum(nvl(vlr_icms,0)) as soma
          from poseidon.dpc_dfe_nota_item group by cod_dfe_nota) i
    on i.cod_dfe_nota = t.cod_dfe_nota;
