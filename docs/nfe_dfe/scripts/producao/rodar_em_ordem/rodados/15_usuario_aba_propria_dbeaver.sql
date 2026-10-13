-- ===========================================================================
--  BLOCO 14_01 - aba "Notas proprias - DPC" (dpc_dfe_usuario_aba aceita PROPRIAS)
-- ===========================================================================
--
--  Banco: Oracle (homolog)        Schema: poseidon
--  Tabela alterada: poseidon.dpc_dfe_usuario_aba (so a CHECK CK1)
--  Rollback: rollback/14_99_rollback_usuario_aba_propria_dbeaver.sql
--
--  ==========================================================================
--   POR QUE
--  ==========================================================================
--  A Gestao de NFe ganha uma aba para as NOTAS PROPRIAS DA DPC: as que o
--  emitente e outra filial do grupo (raiz do CNPJ 66.471.517 - transferencias
--  entre filiais). Pedido do time fiscal em 07/10/2026.
--
--  Aba e permissao: a tela de Sefaz > Parametros concede cada categoria a cada
--  usuario, e a aba so aparece para quem a recebeu. A tabela
--  dpc_dfe_usuario_aba tem a CHECK CK1 com a lista fechada das categorias, e
--  ela recusa PROPRIAS. Este bloco amplia a lista.
--
--  Medido em 07/10/2026: 136 notas proprias pendentes e 3.990 escrituradas.
--
--  ==========================================================================
--   O QUE NAO MUDA
--  ==========================================================================
--  Nenhuma linha existente e tocada: as quatro categorias atuais cabem na
--  condicao nova. Ninguem ganha a aba sozinho - isso e do ajuste unico
--  ajustes_unicos/2026-10-07_aba_propria_usuarios.sql, que roda DEPOIS.
--
--  ==========================================================================
--   ANTES DE RODAR: CONFIRA SE JA RODOU
--  ==========================================================================
--  Rode o SELECT do fim do arquivo. Se a condicao ja listar PROPRIAS, nao rode
--  de novo (o drop da constraint ate funcionaria, mas nao ha o que mudar).
--
--  Sem bloco PL/SQL, pela regra do modulo: o divisor do DBeaver corta bloco e
--  o Oracle devolve PLS-00103.
--
--  Rodar no DBeaver com Execute script (Alt+X).
-- ===========================================================================


alter table poseidon.dpc_dfe_usuario_aba
  drop constraint DPC_DFE_USUARIO_ABA_CK1;

alter table poseidon.dpc_dfe_usuario_aba
  add constraint DPC_DFE_USUARIO_ABA_CK1
  check (aba in ('DEVOLUCAO', 'COMPRAS', 'SUPRIMENTOS', 'SEM_CLASSIFICACAO', 'PROPRIAS'));


-- ===========================================================================
--  CONFERENCIA - esperado: a condicao com as cinco categorias
-- ===========================================================================

select constraint_name, search_condition_vc
  from all_constraints
 where owner = 'POSEIDON'
   and table_name = 'DPC_DFE_USUARIO_ABA'
   and constraint_type = 'C'
   and constraint_name = 'DPC_DFE_USUARIO_ABA_CK1';
