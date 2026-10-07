-- ============================================================================
--  MODULO DFe - ROLLBACK DO 06_01 (PREFERENCIA DE COLUNAS)
-- ============================================================================
--  Remove poseidon.dpc_dfe_usuario_coluna.
--
--  ==========================================================================
--   E DESTRUTIVO, E O QUE SE PERDE NAO VOLTA
--  ==========================================================================
--  Dropar esta tabela apaga a escolha de colunas de TODOS os usuarios. Nao ha
--  de onde recriar: o localStorage de cada navegador pode ate ainda ter uma
--  copia antiga, mas so do navegador de quem configurou, e so se o cache nao
--  tiver sido limpo.
--
--  A SECAO 1 conta quantos usuarios perderiam a configuracao. Rode e olhe o
--  numero ANTES de seguir.
--
--  Depois de dropar, a tela volta sozinha para o comportamento anterior
--  (localStorage, e padrao quando nem isso existir) - o front trata a
--  ausencia da rota como "sem preferencia salva", nao como erro.
--
--  ALVO: homolog (oracle_tst).
--
--  ==========================================================================
--   COMO RODAR (DBeaver)
--  ==========================================================================
--  Conectado como POSEIDON, arquivo INTEIRO com Alt+X.
-- ============================================================================


-- ============================================================================
--  SECAO 1 - O QUE SERA PERDIDO
-- ============================================================================

select count(*)                as linhas,
       count(distinct usuario) as usuarios_afetados,
       count(distinct dsc_tela) as telas
  from poseidon.dpc_dfe_usuario_coluna;


-- ============================================================================
--  SECAO 2 - REMOCAO
-- ============================================================================

declare
  qtd number;
begin
  select count(*) into qtd from all_tables
   where owner = 'POSEIDON' and table_name = 'DPC_DFE_USUARIO_COLUNA';

  if qtd > 0 then
    execute immediate q'[drop table poseidon.dpc_dfe_usuario_coluna purge]';
    dbms_output.put_line('removida: dpc_dfe_usuario_coluna');
  else
    dbms_output.put_line('dpc_dfe_usuario_coluna nao existe.');
  end if;
exception
  when others then
    dbms_output.put_line('DPC_DFE_USUARIO_COLUNA: FALHOU -> ' || sqlerrm);
end;


-- ============================================================================
--  SECAO 3 - CONFERENCIA
-- ============================================================================
--  Esperado: nenhuma linha.

select table_name
  from all_tables
 where owner = 'POSEIDON' and table_name = 'DPC_DFE_USUARIO_COLUNA';
