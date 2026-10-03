-- ============================================================================
--  MODULO DFe - CHAVE INTEIRA DA NFS-e EM dpc_dfe_documento
-- ============================================================================
--  Devolve os 50 caracteres a chave das NFS-e, que estava gravada pela metade
--  (44) em dpc_dfe_documento.chave_nf.
--
--  ==========================================================================
--   O DEFEITO
--  ==========================================================================
--  DfeDocumentoRepository::insere() cortava chave_nf em 44. A chave da NFS-e
--  tem 50: a coluna ja era VARCHAR2(50) e o DfeAdnRepository ja entregava a
--  chave inteira, mas este corte ficou para tras. Corrigido no codigo pelo
--  commit da ApiNFE de 03/10/2026 (merge e74673d na alpha), que foi para o
--  ar ANTES deste script - toda NFS-e nova ja chega com 50.
--
--  Medido em 03/10/2026, antes de rodar:
--    adnNFSe em dpc_dfe_documento      10.428
--    chave_nf = substr(chave_nfse,1,44) 10.428  (100% - e o prefixo, sempre)
--    nula / ja inteira / outro valor    0 / 0 / 0
--    par (empresa, nsu) repetido em dpc_dfe_nfse: 0  (o MERGE e deterministico)
--
--  ==========================================================================
--   COMO
--  ==========================================================================
--  A chave inteira ja esta em dpc_dfe_nfse.chave_nfse. O MERGE a copia,
--  ligando pelo par (cod_dfe_empresa, nro_nsu). NAO reprocessa XML.
--
--  O WHERE do UPDATE e a trava: so troca quando o valor atual e EXATAMENTE o
--  prefixo de 44 da chave real. Uma linha com qualquer outra coisa - nula, ja
--  inteira, divergente - nao e tocada.
--
--  Sem indice em (cod_dfe_empresa, nro_nsu) nas duas tabelas, mas o Oracle
--  resolve por hash join: o mesmo join, contado, levou 0,2 s.
--
--  ==========================================================================
--   O QUE NAO MUDA
--  ==========================================================================
--  As telas ligam documento e NFS-e por (empresa, NSU), nao pela chave - o
--  gancho fonteDoXml() da ApiDPC. Elas continuam iguais. O que muda e o
--  Monitor, que exibe chave_nf na lista de documentos com erro: passa a
--  mostrar uma chave que serve para procurar.
--
--  Conectado como POSEIDON. Rodar secao por secao (Ctrl+Enter).
-- ============================================================================


-- ============================================================================
--  SECAO 0 - FOTO ANTES (esperado: 10.428 com 44, 0 com 50)
-- ============================================================================

select length(chave_nf) as tamanho, count(*) as qtd
  from poseidon.dpc_dfe_documento
 where dsc_tipo_doc = 'adnNFSe'
 group by length(chave_nf)
 order by 1;


-- ============================================================================
--  SECAO 1 - CORRIGIR
-- ============================================================================

merge /*+ USE_HASH(d s) */ into poseidon.dpc_dfe_documento d
using (select cod_dfe_empresa, nro_nsu, chave_nfse
         from poseidon.dpc_dfe_nfse) s
   on (    d.cod_dfe_empresa = s.cod_dfe_empresa
       and d.nro_nsu         = s.nro_nsu
       and d.dsc_tipo_doc    = 'adnNFSe')
 when matched then update
      set d.chave_nf = s.chave_nfse
    where d.chave_nf = substr(s.chave_nfse, 1, 44);

commit;


-- ============================================================================
--  SECAO 2 - CONFERENCIA
-- ============================================================================
--  Esperado: todas com 50, nenhuma com 44.

select length(chave_nf) as tamanho, count(*) as qtd
  from poseidon.dpc_dfe_documento
 where dsc_tipo_doc = 'adnNFSe'
 group by length(chave_nf)
 order by 1;

--  Esperado: a chave do documento e a da NFS-e agora sao IGUAIS em todas.
--  O hint e obrigatorio: sem indice em (empresa, nsu), o Oracle escolhe
--  nested loop e a consulta passa de 2 minutos. Com hash join, 0,2 s.
select /*+ USE_HASH(d s) */ count(*) as total,
       sum(case when d.chave_nf = s.chave_nfse then 1 else 0 end) as iguais
  from poseidon.dpc_dfe_documento d
  join poseidon.dpc_dfe_nfse s
    on s.cod_dfe_empresa = d.cod_dfe_empresa and s.nro_nsu = d.nro_nsu
 where d.dsc_tipo_doc = 'adnNFSe';