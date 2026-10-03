-- ============================================================================
--  ROLLBACK - CHAVE INTEIRA DA NFS-e EM dpc_dfe_documento
-- ============================================================================
--  Volta chave_nf das NFS-e para os 44 primeiros caracteres - o estado de
--  antes do ajuste.
--
--  E deterministico: o ajuste so trocou linhas cujo valor era exatamente o
--  prefixo de 44, entao cortar de novo em 44 devolve o valor original.
--
--  ATENCAO: so faz sentido junto com a REVERSAO do codigo da ApiNFE (corta
--  em 44 no DfeDocumentoRepository). Sem ela, as NFS-e novas continuam
--  chegando com 50 e o acervo fica misturado - que e justamente o estado que
--  o ajuste existiu para evitar.
--
--  Conectado como POSEIDON.
-- ============================================================================


update poseidon.dpc_dfe_documento
   set chave_nf = substr(chave_nf, 1, 44)
 where dsc_tipo_doc = 'adnNFSe'
   and length(chave_nf) = 50;

commit;


--  Esperado: todas com 44.
select length(chave_nf) as tamanho, count(*) as qtd
  from poseidon.dpc_dfe_documento
 where dsc_tipo_doc = 'adnNFSe'
 group by length(chave_nf)
 order by 1;