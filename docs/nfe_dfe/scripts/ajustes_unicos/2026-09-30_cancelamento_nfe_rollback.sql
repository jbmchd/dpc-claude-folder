-- ============================================================================
--  MODULO DFe - ROLLBACK DO AJUSTE DE NF-e CANCELADA (30/09/2026)
-- ============================================================================
--  Desfaz o acerto aplicado por 2026-09-30_cancelamento_nfe.sql.
--
--  O updated_by procurado e 'SCRIPT 05_01' - nome que o script tinha ao
--  rodar. O carimbo esta gravado em linha no banco; renomear o arquivo nao
--  renomeia o que ja foi gravado. NAO alterar essa string.
--
--  ==========================================================================
--   O QUE ESTE ROLLBACK ALCANCA, E O QUE ELE DELIBERADAMENTE NAO ALCANCA
--  ==========================================================================
--  So volta atras nas linhas marcadas com updated_by = 'SCRIPT 05_01'. Isso e
--  o que separa "nota que o script mudou" de "nota que ja estava cancelada
--  antes, pelo caminho normal" - as segundas NAO podem ser revertidas, seria
--  apagar um fato real do Sefaz.
--
--  CONSEQUENCIA IMPORTANTE: se o motor rodar depois do ajuste, o codigo novo
--  (DfeEventoRepository::cancelaNota) vai cancelar essas notas de novo, agora
--  com updated_by = 'DFE NORMALIZAR'. A partir dai este rollback nao as
--  alcanca mais - e esta certo assim, porque nesse ponto o cancelamento veio
--  do fluxo normal e nao do acerto pontual.
--
--  Em outras palavras: este arquivo serve para a janela entre aplicar o ajuste
--  e concluir que ele esta correto. Nao e um "desligar a funcionalidade" - para
--  isso, o que se reverte e o codigo.
--
--  ==========================================================================
--   VOLTAR PARA QUAL SITUACAO
--  ==========================================================================
--  Volta para 1/AUTORIZADA. E o valor que essas linhas tinham antes do ajuste:
--  todas as 51 medidas em 30/09/2026 estavam em cod_situacao = 1, nenhuma
--  nula, nenhuma denegada. A SECAO 1 confere isso antes de mexer.
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
 where n.updated_by = 'SCRIPT 05_01'
   and n.cod_situacao = 3;


-- ============================================================================
--  SECAO 2 - REVERSAO
-- ============================================================================

update poseidon.dpc_dfe_nota n
   set n.cod_situacao = 1,
       n.dsc_situacao = 'AUTORIZADA',
       n.updated_at   = sysdate,
       n.updated_by   = 'ROLLBACK 05_99'
 where n.updated_by = 'SCRIPT 05_01'
   and n.cod_situacao = 3;


-- ============================================================================
--  SECAO 3 - COMMIT
-- ============================================================================

commit;


-- ============================================================================
--  SECAO 4 - CONFERENCIA
-- ============================================================================
--  Esperado: nenhuma linha com updated_by = 'SCRIPT 05_01' restante.

select nvl(n.updated_by, '(nulo)') as updated_by,
       n.cod_situacao,
       count(*) as qtd
  from poseidon.dpc_dfe_nota n
 where n.updated_by in ('SCRIPT 05_01', 'ROLLBACK 05_99')
 group by n.updated_by, n.cod_situacao
 order by 1, 2;
