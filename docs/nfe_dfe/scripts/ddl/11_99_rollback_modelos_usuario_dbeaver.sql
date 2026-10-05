-- ===========================================================================
--  ROLLBACK DO BLOCO 11_01 - remove a tabela de modelos do Relatorio Avancado
-- ===========================================================================
--
--  DESTRUTIVO: apaga TODOS os modelos de filtro e de coluna que as pessoas
--  salvaram. Nao ha de onde reconstruir - o modelo e escolha de quem o criou,
--  nao deriva de nenhum outro dado.
--
--  Nao mexe em dpc_dfe_usuario_coluna (bloco 06_01): a escolha corrente de
--  colunas de cada tela continua valendo, inclusive a dos _REL.
--
--  So faz sentido junto com a reversao do codigo (ApiDPC e DPC) da busca
--  avancada.
--
--  Rodar no DBeaver com Execute script (Alt+X).
-- ===========================================================================


drop table poseidon.dpc_dfe_usuario_modelo purge;


-- ===========================================================================
--  CONFERENCIA - esperado: nenhuma linha
-- ===========================================================================

select table_name
  from all_tables
 where owner = 'POSEIDON' and table_name = 'DPC_DFE_USUARIO_MODELO';