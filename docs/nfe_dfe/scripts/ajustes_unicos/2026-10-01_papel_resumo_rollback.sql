-- ============================================================================
--  MODULO DFe - ROLLBACK DO AJUSTE DE PAPEL DO RESUMO (01/10/2026)
-- ============================================================================
--  Desfaz o acerto aplicado por 2026-10-01_papel_resumo.sql, devolvendo as
--  notas para SIG_PAPEL_EMPRESA = 'INDEF'.
--
--  O updated_by procurado e 'SCRIPT 05_02' - nome que o script tinha ao
--  rodar. O carimbo esta gravado em 96 linhas do banco; renomear o arquivo
--  nao renomeia o que ja foi gravado. NAO alterar essa string.
--
--  ==========================================================================
--   O QUE ALCANCA, E O QUE DELIBERADAMENTE NAO ALCANCA
--  ==========================================================================
--  So volta atras nas linhas marcadas com updated_by = 'SCRIPT 05_02'. E isso
--  que separa "nota que o script mudou" de "nota que virou DEST pelo caminho
--  normal", quando o procNF chegou e o parser leu <dest> de verdade. Reverter
--  a segunda apagaria um fato lido do XML.
--
--  VALIDADE CURTA, POR DESENHO: assim que o motor normalizar um resumo novo,
--  o codigo corrigido grava DEST com updated_by = 'DFE NORMALIZAR', fora do
--  alcance deste rollback. Esta certo - ali o papel veio do fluxo, nao do
--  acerto pontual.
--
--  Este arquivo serve para a janela entre aplicar o ajuste e concluir que ele
--  esta correto. Para desligar a funcionalidade, o que se reverte e o codigo
--  (ApiNFE, DfeNotaRepository::papelDaEmpresa).
--
--  ALVO: homolog (oracle_tst).
--
--  ==========================================================================
--   COMO RODAR (DBeaver)
--  ==========================================================================
--  Conectado como POSEIDON, arquivo INTEIRO com Alt+X.
-- ============================================================================


-- ============================================================================
--  SECAO 1 - O QUE SERA REVERTIDO
-- ============================================================================

select count(*) as linhas_a_reverter
  from poseidon.dpc_dfe_nota n
 where n.updated_by = 'SCRIPT 05_02'
   and n.sig_papel_empresa = 'DEST';


-- ============================================================================
--  SECAO 2 - REVERSAO
-- ============================================================================

update poseidon.dpc_dfe_nota n
   set n.sig_papel_empresa = 'INDEF',
       n.updated_at        = sysdate,
       n.updated_by        = 'ROLLBACK 05_98'
 where n.updated_by = 'SCRIPT 05_02'
   and n.sig_papel_empresa = 'DEST';


-- ============================================================================
--  SECAO 3 - COMMIT
-- ============================================================================

commit;


-- ============================================================================
--  SECAO 4 - CONFERENCIA
-- ============================================================================
--  Esperado: nenhuma linha com updated_by = 'SCRIPT 05_02' restante.

select nvl(n.updated_by, '(nulo)') as updated_by,
       n.sig_papel_empresa,
       count(*) as qtd
  from poseidon.dpc_dfe_nota n
 where n.updated_by in ('SCRIPT 05_02', 'ROLLBACK 05_98')
 group by n.updated_by, n.sig_papel_empresa
 order by 1, 2;
