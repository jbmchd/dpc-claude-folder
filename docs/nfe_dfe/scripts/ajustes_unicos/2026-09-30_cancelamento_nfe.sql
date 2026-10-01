-- ============================================================================
--  MODULO DFe - NF-e CANCELADA EXIBIDA COMO AUTORIZADA
-- ============================================================================
--  Acerto retroativo das notas que tem evento de cancelamento (110111)
--  capturado e mesmo assim seguem com cod_situacao = 1 (AUTORIZADA).
--
--  >>> JA APLICADO em homolog em 30/09/2026. Resultado medido: 133
--  >>> CANCELADA, 0 AUTORIZADA, 51 linhas ajustadas. Fica versionado como
--  >>> registro do que foi feito, nao como tarefa pendente.--
--  ==========================================================================
--   POR QUE O CARIMBO NAO BATE COM O NOME DO ARQUIVO
--  ==========================================================================
--  O updated_by gravado e 'SCRIPT 05_01', nome que este arquivo tinha quando
--  rodou. O carimbo JA ESTA em linha no banco, e e por ele que o rollback
--  encontra o que desfazer - renomear o arquivo nao pode renomear o que ja
--  foi gravado. NAO "corrija" essa diferenca: fazer isso deixa o rollback
--  sem encontrar nada.
--
--  ==========================================================================
--   O QUE ACONTECEU
--  ==========================================================================
--  Medido em 30/09/2026, nas 133 notas com evento 110111 capturado:
--
--     dsc_tipo_doc = 'resNFe'  ->  82 notas CANCELADA   (certo)
--     dsc_tipo_doc = 'procNF'  ->  51 notas AUTORIZADA  (errado)
--
--  Correlacao perfeita nos 133 casos, e as 51 erradas sao todas papel DEST -
--  entrada nossa, que e justamente o caso de uso do modulo.
--
--  A causa sao dois defeitos somados, os dois corrigidos em codigo junto com
--  este script:
--
--  1) O procNFe REBAIXAVA a situacao. O XML completo e a nota autorizada MAIS
--     o protocolo DE AUTORIZACAO, cujo cStat e sempre 100 - ele nao tem como
--     saber de um cancelamento posterior. O resumo trazia cSitNFe = 3
--     (correto), o completo chegava depois e devolvia a nota para AUTORIZADA.
--     Corrigido em DfeNotaRepository (guarda naoRebaixaSituacao).
--
--  2) O evento 110111 NAO era aplicado a nota. CT-e e NFS-e ja aplicavam; a
--     NF-e era a unica dos tres documentos do modulo que nao.
--     Corrigido em DfeEventoRepository::cancelaNota().
--
--  Por isso o script sozinho nao basta: sem a correcao (1), o proximo
--  reprocessamento do procNF desfaria o que este UPDATE arruma.
--
--  ==========================================================================
--   ALCANCE
--  ==========================================================================
--  Toca UMA coluna logica (cod_situacao/dsc_situacao) e so em nota que tem o
--  evento de cancelamento gravado. Nao mexe em valor, papel, NSU, estado no
--  ERP nem em manifestacao.
--
--  O EXISTS casa por (chave_nf, cod_dfe_empresa) e nao por cod_dfe_nota, de
--  proposito: assim alcanca tambem evento que esteja orfao (cod_dfe_nota
--  nulo). Hoje sao 0 orfaos em 110111, mas o custo de cobrir e zero.
--
--  Efeito colateral CONFERIDO antes de escrever este script: nota corrigida
--  sai da fila automatica de manifestacao, porque candidatas() filtra
--  cod_situacao = 1. Medido nas 51 - passam o filtro da Confirmacao: 0;
--  empresas com auto-Confirmacao ligada: 0. A fila de Ciencia ja as excluia
--  (exige dsc_tipo_doc = 'resNFe'). Ou seja, nenhuma nota sai da fila hoje, e
--  daqui pra frente nota cancelada deixa de entrar.
--
--  ==========================================================================
--   UM CAMINHO SO
--  ==========================================================================
--  Idempotente: rodar duas vezes produz o mesmo resultado da primeira - a
--  segunda passagem afeta 0 linhas, porque o WHERE exige situacao diferente
--  de cancelada.
--
--  O updated_by = 'SCRIPT 05_01' nao e enfeite: e ele que permite ao
--  rollback deste arquivo desfazer EXATAMENTE as linhas que ele mudou, sem
--  atingir nota que ja estava cancelada por outro caminho.
--
--  ALVO: homolog (oracle_tst). As tabelas do motor so existem la.
--
--  ==========================================================================
--   COMO RODAR (DBeaver)
--  ==========================================================================
--  Conectado como POSEIDON, arquivo INTEIRO com Alt+X.
--  A SECAO 1 mostra o retrato ANTES, a SECAO 4 o retrato DEPOIS.
-- ============================================================================


-- ============================================================================
--  SECAO 1 - CONFERENCIA ANTES
-- ============================================================================
--  Esperado (medido em 30/09/2026): resNFe/CANCELADA 82, procNF/AUTORIZADA 51.
--  Se os numeros vierem diferentes, o motor tocou algo no meio - vale entender
--  antes de aplicar, nao e motivo para parar.

select n.dsc_tipo_doc,
       n.cod_situacao,
       case n.cod_situacao when 1 then 'AUTORIZADA'
                           when 2 then 'DENEGADA'
                           when 3 then 'CANCELADA'
                           else '(nulo/outro)' end as situacao,
       count(*) as qtd
  from poseidon.dpc_dfe_nota n
 where exists (select 1
                 from poseidon.dpc_dfe_evento e
                where e.chave_nf        = n.chave_nf
                  and e.cod_dfe_empresa = n.cod_dfe_empresa
                  and e.cod_tipo_evento = '110111')
 group by n.dsc_tipo_doc, n.cod_situacao
 order by 1, 2;


-- ============================================================================
--  SECAO 2 - ACERTO
-- ============================================================================

update poseidon.dpc_dfe_nota n
   set n.cod_situacao = 3,
       n.dsc_situacao = 'CANCELADA',
       n.updated_at   = sysdate,
       n.updated_by   = 'SCRIPT 05_01'
 where (n.cod_situacao is null or n.cod_situacao <> 3)
   and exists (select 1
                 from poseidon.dpc_dfe_evento e
                where e.chave_nf        = n.chave_nf
                  and e.cod_dfe_empresa = n.cod_dfe_empresa
                  and e.cod_tipo_evento = '110111');


-- ============================================================================
--  SECAO 3 - COMMIT
-- ============================================================================

commit;


-- ============================================================================
--  SECAO 4 - CONFERENCIA DEPOIS
-- ============================================================================
--  Esperado: uma unica linha, CANCELADA com o total (133 na medicao de
--  30/09/2026). Qualquer linha AUTORIZADA aqui significa que o UPDATE nao
--  alcancou algo - investigar antes de considerar fechado.

select n.cod_situacao,
       case n.cod_situacao when 1 then 'AUTORIZADA'
                           when 2 then 'DENEGADA'
                           when 3 then 'CANCELADA'
                           else '(nulo/outro)' end as situacao,
       count(*) as qtd,
       sum(case when n.updated_by = 'SCRIPT 05_01' then 1 else 0 end) as ajustadas_agora
  from poseidon.dpc_dfe_nota n
 where exists (select 1
                 from poseidon.dpc_dfe_evento e
                where e.chave_nf        = n.chave_nf
                  and e.cod_dfe_empresa = n.cod_dfe_empresa
                  and e.cod_tipo_evento = '110111')
 group by n.cod_situacao
 order by 1;
