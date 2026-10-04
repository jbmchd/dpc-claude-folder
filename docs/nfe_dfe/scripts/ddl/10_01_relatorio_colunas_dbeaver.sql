-- ===========================================================================
--  BLOCO 10_01 - preferencia de coluna dos RELATORIOS AVANCADOS
-- ===========================================================================
--
--  Banco: Oracle (homolog)        Schema: poseidon
--  Tabela alterada: poseidon.dpc_dfe_usuario_coluna (so a CHECK de dsc_tela)
--  Rollback: 10_99_rollback_relatorio_colunas_dbeaver.sql
--
--  ==========================================================================
--   POR QUE
--  ==========================================================================
--  O menu ganhou Sefaz > Relatorios Avancados > NF-e / CT-e / NFS-e (pedido
--  do usuario em 03/10/2026). Cada item abre a MESMA tela de documento, mas
--  ja na visao Completo, com a escolha de colunas guardada A PARTE da tela
--  normal - para quem monta um relatorio largo nao desarrumar a tela do dia
--  a dia, e vice-versa.
--
--  A escolha mora em dpc_dfe_usuario_coluna, uma linha por (usuario,
--  dsc_tela). A CHECK de dsc_tela so aceitava 'NFE','CTE','NFSE'. Este bloco
--  acrescenta 'NFE_REL','CTE_REL','NFSE_REL'. O dominio continua FECHADO -
--  e a mesma lista que SefazColunaUsuarioRepository::TELAS_VALIDAS.
--
--  ==========================================================================
--   ANTES DE RODAR: CONFIRA SE JA RODOU
--  ==========================================================================
--  Rode primeiro o SELECT do fim do arquivo. Se a condicao ja listar os
--  _REL, o bloco ja esta aplicado - nao rode de novo (o DROP da CHECK
--  inexistente nao acontece, mas o ADD repetido daria ORA-02264).
--
--  Sem bloco PL/SQL, pela regra 15 do modulo: o DBeaver corta bloco.
--
--  ==========================================================================
--   SEGURO COM DADO DENTRO
--  ==========================================================================
--  So troca a CHECK. As linhas existentes (NFE, CTE, NFSE) continuam
--  validas na condicao nova, entao o ADD nao falha por dado. Nenhuma coluna
--  muda. Entre o DROP e o ADD a tabela fica sem CHECK por milissegundos -
--  e nada grava nela fora da tela de colunas.
--
--  Rodar no DBeaver com Execute script (Alt+X).
-- ===========================================================================


alter table poseidon.dpc_dfe_usuario_coluna
  drop constraint DPC_DFE_USUARIO_COLUNA_CK1;

alter table poseidon.dpc_dfe_usuario_coluna
  add constraint DPC_DFE_USUARIO_COLUNA_CK1
  check (dsc_tela in ('NFE', 'CTE', 'NFSE', 'NFE_REL', 'CTE_REL', 'NFSE_REL'));


-- ===========================================================================
--  CONFERENCIA - esperado: a condicao com os seis valores
-- ===========================================================================

select constraint_name, search_condition_vc
  from all_constraints
 where owner = 'POSEIDON'
   and table_name = 'DPC_DFE_USUARIO_COLUNA'
   and constraint_type = 'C'
   and constraint_name = 'DPC_DFE_USUARIO_COLUNA_CK1';