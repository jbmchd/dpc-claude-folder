-- ============================================================================
--  MODULO DFe - PAPEL DA NOTA QUE SO TEM RESUMO
-- ============================================================================
--  Acerto retroativo das notas que ficaram com SIG_PAPEL_EMPRESA = 'INDEF'
--  por terem apenas o resumo (resNFe), e por isso sumiram da aba "Recebidas"
--  do Monitor NF-e.
--
--  >>> JA APLICADO em homolog em 01/10/2026. Resultado medido: INDEF zerado,
--  >>> as 96 notas viraram DEST, e as 9 que a equipe fiscal listou no
--  >>> confronto com a Qive aparecem em Recebidas com badge CANCELADA.--
--  ==========================================================================
--   POR QUE O CARIMBO NAO BATE COM O NOME DO ARQUIVO
--  ==========================================================================
--  O updated_by gravado e 'SCRIPT 05_02', nome que este arquivo tinha quando
--  rodou. O carimbo JA ESTA em linha no banco, e e por ele que o rollback
--  encontra o que desfazer - renomear o arquivo nao pode renomear o que ja
--  foi gravado. NAO "corrija" essa diferenca: fazer isso deixa o rollback
--  sem encontrar nada.
--
--  ==========================================================================
--   O QUE ACONTECEU
--  ==========================================================================
--  O resNFe nao traz <dest>: o unico CNPJ dele e o do emitente. O motor
--  concluia dai que o papel era indeterminavel e gravava INDEF, esperando o
--  XML completo resolver.
--
--  Normalmente resolvia mesmo: enviamos a Ciencia, a SEFAZ libera o procNF, o
--  papel vira DEST e a nota aparece em "Recebidas".
--
--  Nota CANCELADA quebra essa cadeia. A fila de manifestacao filtra
--  cod_situacao = 1, entao nunca manifestamos uma nota cancelada, o procNF
--  nunca chega, e o papel fica INDEF PARA SEMPRE. A aba "Recebidas" filtra
--  DEST, entao essas notas somem de onde a equipe fiscal procura.
--
--  Foi assim que surgiram 9 notas de setembro "faltando" no confronto com a
--  Qive: estavam capturadas, canceladas corretamente, mas na aba errada.
--
--  ==========================================================================
--   POR QUE DEST E A RESPOSTA CERTA, E NAO UM CHUTE
--  ==========================================================================
--  NT 2014.002 v.1.40 (publicada em 03/07/2026), secao "A distribuicao
--  ocorrera para os atores...", tabela de distribuicao por ator:
--
--     Documento          Emitente  Destinatario  Transportador  Terceiros
--     Resumo de NF-e     Nao       SIM           Nao            Nao
--
--  E o texto logo acima da tabela: "Para transportador e terceiros, a NF-e
--  estara disponivel integralmente na consulta" - eles recebem o XML COMPLETO
--  direto e nunca veem um resumo.
--
--  Ou seja: receber um resumo e, POR NORMA, prova de que somos o
--  destinatario. Nao e ausencia de informacao, e informacao.
--
--  Medido na base em 30/09/2026, batendo com a norma: das 9.188 notas DEST,
--  9.163 (99,7%) tiveram um resNFe capturado antes; das 126 TRANSP, ZERO.
--  Resumos cuja nota acabou com papel diferente de DEST: zero.
--
--  ==========================================================================
--   ALCANCE E GUARDAS
--  ==========================================================================
--  Toca UMA coluna (sig_papel_empresa) e so em nota que satisfaz as tres
--  condicoes: papel INDEF ou nulo, documento resNFe, e a empresa que capturou
--  NAO e a emitente.
--
--  A terceira guarda e o que respeita o ramo EMIT do codigo: se a nota foi
--  emitida pela propria empresa que a capturou, ela nao vira DEST. Conferido
--  em 01/10/2026: das 96 notas INDEF, as 96 tem capturadora diferente da
--  emitente, entao nenhuma cai nesse caso - mas a guarda fica, porque o
--  script tem de continuar correto se rodar de novo depois.
--
--  EFEITO COLATERAL CONFERIDO: ao virar DEST, 4 notas passam a satisfazer o
--  filtro de nota da fila de Confirmacao. Sem efeito real hoje -
--  status_manif_auto_confirmacao = 'N' e dta_inicio_manif_auto_conf nulo nas
--  4 empresas (dupla trava). A fila de Ciencia nao muda: ela filtra por
--  dsc_tipo_doc e ausencia de procNF, nao por papel.
--
--  ==========================================================================
--   UM CAMINHO SO
--  ==========================================================================
--  Idempotente: a segunda passagem afeta 0 linhas, porque o WHERE exige papel
--  INDEF ou nulo.
--
--  O updated_by = 'SCRIPT 05_02' e o que permite ao rollback reverter
--  exatamente estas linhas, sem tocar em nota que virou DEST pelo caminho
--  normal (procNF).
--
--  ALVO: homolog (oracle_tst). As tabelas do motor so existem la.
--
--  ==========================================================================
--   COMO RODAR (DBeaver)
--  ==========================================================================
--  Conectado como POSEIDON, arquivo INTEIRO com Alt+X.
-- ============================================================================


-- ============================================================================
--  SECAO 1 - CONFERENCIA ANTES
-- ============================================================================
--  Esperado (medido em 01/10/2026): INDEF 96, todas resNFe - 82 canceladas e
--  14 autorizadas. Numero diferente nao impede rodar; so vale entender antes.

select nvl(n.sig_papel_empresa, '(nulo)') as papel,
       n.dsc_tipo_doc,
       count(*) as qtd
  from poseidon.dpc_dfe_nota n
 group by n.sig_papel_empresa, n.dsc_tipo_doc
 order by 3 desc;


-- ============================================================================
--  SECAO 2 - ACERTO
-- ============================================================================

update poseidon.dpc_dfe_nota n
   set n.sig_papel_empresa = 'DEST',
       n.updated_at        = sysdate,
       n.updated_by        = 'SCRIPT 05_02'
 where (n.sig_papel_empresa is null or n.sig_papel_empresa = 'INDEF')
   and n.dsc_tipo_doc = 'resNFe'
   and exists (select 1
                 from poseidon.dpc_dfe_empresa e
                where e.cod_dfe_empresa = n.cod_dfe_empresa
                  and e.num_cnpj <> substr(n.chave_nf, 7, 14));


-- ============================================================================
--  SECAO 3 - COMMIT
-- ============================================================================

commit;


-- ============================================================================
--  SECAO 4 - CONFERENCIA DEPOIS
-- ============================================================================
--  Esperado: nenhuma linha INDEF restante, e DEST somando 96 a mais.
--  Linha INDEF que sobre so pode ser nota emitida pela propria capturadora -
--  investigar, porque nao havia nenhuma na medicao.

select nvl(n.sig_papel_empresa, '(nulo)') as papel,
       n.dsc_tipo_doc,
       count(*) as qtd,
       sum(case when n.updated_by = 'SCRIPT 05_02' then 1 else 0 end) as ajustadas_agora
  from poseidon.dpc_dfe_nota n
 group by n.sig_papel_empresa, n.dsc_tipo_doc
 order by 3 desc;
