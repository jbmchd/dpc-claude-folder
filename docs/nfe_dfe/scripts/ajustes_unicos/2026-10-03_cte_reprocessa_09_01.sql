-- ============================================================================
--  MODULO DFe - REPROCESSAR OS CT-e (colunas do bloco 09_01)
-- ============================================================================
--  Recoloca na fila de normalizacao (status_process = 'P') os 54.213 procCTe
--  ja processados, para que o parser novo preencha as 15 colunas criadas em
--  03/10/2026: nomes dos papeis, tomador avulso, ICMS, data de autorizacao,
--  CT-e complementado e os tres valores da reforma tributaria.
--
--  Nao chama a SEFAZ: o normalizador le o XML ja guardado em
--  dpc_dfe_documento. Nenhuma consulta externa, nenhum consumo de cota.
--
--  ==========================================================================
--   PRE-REQUISITOS
--  ==========================================================================
--   1. ddl/09_01_cte_conferencia_mensal_dbeaver.sql aplicado (15 colunas).
--      Conferido em 03/10/2026: aplicado.
--   2. ApiNFE no ar no servidor 16 com DOIS commits: o parser das 15 colunas
--      (c9a5435) E o anti-rebaixamento de situacao do CT-e. Os dois estao na
--      alpha desde 03/10/2026.
--      SEM O SEGUNDO, A RECARGA DESFAZ OS 518 CANCELAMENTOS.
--  Sem os dois, o reprocessamento ou falha com ORA-00904 ou regrava o estado
--  antigo.
--
--  ==========================================================================
--   O QUE MAIS E REFEITO DE CARONA (e por que e seguro)
--  ==========================================================================
--  Reprocessar o procCTe nao grava so as 15 colunas novas. Tambem refaz:
--
--    NF-e transportadas  salvaNfeTransportadas() e IDEMPOTENTE: insere o que
--                        falta e nao apaga o que existe. Sao 61.530 linhas
--                        hoje; ao fim tem de haver 61.530 (a SECAO 4 confere).
--    papel da empresa    sig_papel_empresa recalculado a partir do XML, com a
--                        mesma precedencia de antes (TOMA vence).
--    situacao            PROTEGIDA, mas so a partir de 03/10/2026 (ApiNFE
--                        commit do fix de anti-rebaixamento do CT-e). ANTES
--                        DELE ESTA RECARGA DESFARIA OS 518 CANCELAMENTOS.
--
--                        Por que: o cancelamento do CT-e nao esta no proprio
--                        CT-e - vem do evento 110111. O protocolo embutido no
--                        procCTe e o de AUTORIZACAO, com cStat 100 SEMPRE,
--                        inclusive em frete cancelado depois. salva()
--                        reescrevia cod_situacao a partir dele.
--
--                        Medido em transacao com rollback num CT-e cancelado
--                        real: antes 3, depois 1. Com a guarda: antes 3,
--                        depois 3.
--
--                        Sao 518 cancelados hoje e ao fim tem de continuar
--                        518. ESTE E O NUMERO A VIGIAR.
--
--  Eventos (dpc_dfe_cte_evento) NAO sao tocados: vem de documento proprio,
--  que nao entra nesta fila. Sao 37.695 linhas e devem continuar 37.695.
--
--  ==========================================================================
--   CARIMBO
--  ==========================================================================
--  det_erro = 'REPROCESSO 2026-10-03 CTE 09_01' marca o que este script
--  colocou na fila. O normalizador limpa det_erro ao concluir, entao o
--  carimbo mostra o que AINDA esta pendente - e e por ele que o rollback age.
--
--  ==========================================================================
--   COMO RODAR
--  ==========================================================================
--  Conectado como POSEIDON. Rodar bloco a bloco (selecionar e Ctrl+Enter),
--  nao o arquivo inteiro: a SECAO 0 e para guardar a foto antes.
--
--  Depois da SECAO 1, a fila drena pelo agendador (dfe:normalizar a cada 10
--  min, com withoutOverlapping(20), 500 por vez) ou de uma vez pelo comando:
--      docker exec -d apinfe-app sh -c \
--        'php /var/www/artisan dfe:normalizar --limit=60000 > /tmp/reproc_cte.log 2>&1'
--
--  Sao 5,8x o volume da recarga da NF-e, entao pelo agendador leva o dia.
-- ============================================================================


-- ============================================================================
--  SECAO 0 - FOTO ANTES (guardar o resultado)
-- ============================================================================
--  Medido em 03/10/2026, antes de rodar:
--    cte 54.213 | cancelados 518 | nfe_transportadas 61.530 | eventos 37.695
--    e as 15 colunas todas em 0.

select (select count(*) from poseidon.dpc_dfe_cte)                        as ctes,
       (select count(*) from poseidon.dpc_dfe_cte where cod_situacao = 3) as cancelados,
       (select count(*) from poseidon.dpc_dfe_cte_nfe)                    as nfe_transportadas,
       (select count(*) from poseidon.dpc_dfe_cte_evento)                 as eventos,
       (select count(dsc_razao_remetente) from poseidon.dpc_dfe_cte)      as com_remetente,
       (select count(cod_cst_icms) from poseidon.dpc_dfe_cte)             as com_cst,
       (select count(num_cnpj_tomador4) from poseidon.dpc_dfe_cte)        as com_toma4
  from dual;

select sig_papel_empresa, count(*) as qtd
  from poseidon.dpc_dfe_cte
 group by sig_papel_empresa
 order by 2 desc;


-- ============================================================================
--  SECAO 1 - COLOCAR NA FILA (54.213 documentos)
-- ============================================================================

update poseidon.dpc_dfe_documento
   set status_process = 'P',
       det_erro       = 'REPROCESSO 2026-10-03 CTE 09_01'
 where dsc_tipo_doc = 'procCTe'
   and status_process = 'C';

commit;


-- ============================================================================
--  SECAO 2 - ACOMPANHAMENTO (rodar quantas vezes quiser)
-- ============================================================================

select status_process, count(*) as qtd
  from poseidon.dpc_dfe_documento
 where dsc_tipo_doc = 'procCTe'
 group by status_process
 order by 1;


-- ============================================================================
--  SECAO 3 - DOCUMENTO QUE FALHOU (esperado: nenhuma linha)
-- ============================================================================

select d.nro_nsu, e.nro_empresa, d.qtd_tentativa, substr(d.det_erro, 1, 200) as erro
  from poseidon.dpc_dfe_documento d
  join poseidon.dpc_dfe_empresa e on e.cod_dfe_empresa = d.cod_dfe_empresa
 where d.dsc_tipo_doc = 'procCTe'
   and d.status_process = 'E'
 order by d.nro_nsu;


-- ============================================================================
--  SECAO 4 - CONFERENCIA FINAL
-- ============================================================================
--  O QUE NAO PODE MUDAR:
--    ctes               54.213
--    cancelados            518   <- se cair, parar e investigar
--    nfe_transportadas  61.530
--    eventos            37.695
--
--  O QUE TEM DE APARECER (esperado pela medicao de 250 CT-e reais):
--    com_remetente     ~100%  dos 54.213
--    com_destinatario  ~100%
--    com_cst           ~100%
--    com_autorizacao   ~100%
--    com_expedidor      ~27%
--    com_recebedor      ~26%
--    com_valor_icms     ~23%   (so CST 00, 90-OutraUF e 60; CST 40 e isento)
--    com_toma4         ~9,5%   (os 5.124 de cod_tomador = 4)
--    com_reforma        ~78%
--    com_complementado  ~2,3%  (os 1.253 de cod_tipo_cte = 1)

select (select count(*) from poseidon.dpc_dfe_cte)                        as ctes,
       (select count(*) from poseidon.dpc_dfe_cte where cod_situacao = 3) as cancelados,
       (select count(*) from poseidon.dpc_dfe_cte_nfe)                    as nfe_transportadas,
       (select count(*) from poseidon.dpc_dfe_cte_evento)                 as eventos
  from dual;

select count(*)                           as total,
       count(dsc_razao_remetente)         as com_remetente,
       count(dsc_razao_destinat)          as com_destinatario,
       count(dsc_razao_expedidor)         as com_expedidor,
       count(dsc_razao_recebedor)         as com_recebedor,
       count(num_cnpj_tomador4)           as com_toma4,
       count(cod_cst_icms)                as com_cst,
       count(vlr_icms)                    as com_valor_icms,
       count(dta_autorizacao)             as com_autorizacao,
       count(chave_cte_complementado)     as com_complementado,
       count(vlr_cbs)                     as com_reforma
  from poseidon.dpc_dfe_cte;

--  Coerencia do ICMS: CST isento (40, 41, 51) NAO pode ter valor.
--  Esperado: nenhuma linha.
select cod_cst_icms, count(*) as qtd
  from poseidon.dpc_dfe_cte
 where cod_cst_icms in ('40','41','51')
   and vlr_icms is not null
 group by cod_cst_icms;

--  Coerencia do complementado: a chave nunca e a do proprio CT-e, e so
--  existe em CT-e tipo 1. Esperado: nenhuma linha.
select chave_cte, cod_tipo_cte, chave_cte_complementado
  from poseidon.dpc_dfe_cte
 where chave_cte_complementado is not null
   and (chave_cte_complementado = chave_cte or cod_tipo_cte <> '1')
 fetch first 20 rows only;

--  Coerencia do tomador: toma4 so em cod_tomador = 4, e sempre nele.
--  Esperado: nenhuma linha.
select cod_tomador, count(*) as qtd
  from poseidon.dpc_dfe_cte
 where (cod_tomador = '4' and num_cnpj_tomador4 is null)
    or (cod_tomador <> '4' and num_cnpj_tomador4 is not null)
 group by cod_tomador;