-- ============================================================================
--  PRODUCAO - 1/2: CHECK do pedido de manifestacao em massa aceita os 4 eventos
--  (pedidos da controladoria de 03/11/2026; ApiNFE PR #18)
-- ============================================================================
--  SO A ALTERACAO. Comandos avulsos: rode um a um (Ctrl+Enter) ou o script todo (Alt+X).
--  Conectado como POSEIDON. Roda ANTES do deploy da ApiNFE.
--
--  O que muda: poseidon.dpc_dfe_manif_pedido.cod_tipo_evento passa de
--      ('210210','210200')                      Ciencia, Confirmacao
--  para
--      ('210210','210200','210220','210240')    + Desconhecimento, Operacao nao realizada
--  Sem isto, o pedido em massa de Desconhecimento ou Operacao nao realizada falha no INSERT do cabecalho.
--
--  Seguro com dados: todas as linhas existentes sao 210210 ou 210200, entao a nova regra as aceita.
--  Se uma execucao falhar entre o DROP e o ADD, rode o ADD de novo (o DROP so existe uma vez).
-- ============================================================================

-- 0) ANTES (somente leitura): deve mostrar cod_tipo_evento in ('210210', '210200')
select constraint_name, search_condition_vc
  from all_constraints
 where owner = 'POSEIDON' and constraint_name = 'DPC_DFE_MANIF_PEDIDO_CK1';

-- 1) A ALTERACAO
alter table poseidon.dpc_dfe_manif_pedido drop constraint DPC_DFE_MANIF_PEDIDO_CK1;

alter table poseidon.dpc_dfe_manif_pedido add constraint DPC_DFE_MANIF_PEDIDO_CK1 check (cod_tipo_evento in ('210210', '210200', '210220', '210240'));

comment on column poseidon.dpc_dfe_manif_pedido.cod_tipo_evento is
  'Os quatro eventos: 210210-Ciencia | 210200-Confirmacao | 210220-Desconhecimento | 210240-Operacao nao realizada. Ate 05/11/2026 eram so os dois primeiros; a controladoria autorizou os quatro em massa. Desconhecimento e Operacao nao realizada nao tem volta: a tela pede confirmacao reforcada, e a justificativa da Operacao nao realizada fica em dpc_dfe_manifestacao.dsc_justificativa, uma para o pedido todo.';

-- 2) DEPOIS (somente leitura): deve mostrar os quatro eventos
select constraint_name, search_condition_vc, status, validated
  from all_constraints
 where owner = 'POSEIDON' and constraint_name = 'DPC_DFE_MANIF_PEDIDO_CK1';

-- ============================================================================
--  DESFAZER (so se nao houver pedido com 210220/210240; senao o ADD recusa):
--    select count(*) from poseidon.dpc_dfe_manif_pedido where cod_tipo_evento in ('210220', '210240');   -- deve ser 0
--    alter table poseidon.dpc_dfe_manif_pedido drop constraint DPC_DFE_MANIF_PEDIDO_CK1;
--    alter table poseidon.dpc_dfe_manif_pedido add constraint DPC_DFE_MANIF_PEDIDO_CK1 check (cod_tipo_evento in ('210210', '210200'));
-- ============================================================================
