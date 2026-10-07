-- ============================================================================
--  MODULO DFe - CFOP DO XML NAS NOTAS JA EXISTENTES (dpc_dfe_nota.cod_cfop_xml)
-- ============================================================================
--  Preenche cod_cfop_xml das notas que ja estavam na base quando a coluna foi
--  criada (ddl/12_01). Notas novas ja nascem preenchidas: a ApiNFE grava a
--  coluna na mesma transacao dos itens (DfeNotaItemRepository::substitui).
--
--  ==========================================================================
--   POR QUE
--  ==========================================================================
--  A Gestao de NFe preve a categoria da nota pendente (Compras / Devolucao)
--  pelo CFOP do XML, porque cod_cfop_erp so existe depois da escrituracao.
--  Sem este ajuste, so as notas capturadas daqui para frente seriam previstas.
--
--  ==========================================================================
--   A REGRA
--  ==========================================================================
--  CFOP da nota = o do item de MAIOR vlr_item. Empate: menor
--  cod_dfe_nota_item. Mesma regra do codigo da ApiNFE - se uma mudar, a outra
--  muda junto. Item sem CFOP de 4 digitos nao concorre.
--
--  Medido em 06/10/2026, antes de rodar:
--    notas em dpc_dfe_nota                       9.689
--    notas com item                              9.582   <- o que o ajuste preenche
--    itens                                     180.256   (todos com CFOP, 1102..6949)
--    notas com mais de um CFOP entre os itens      351   (a regra decide)
--    (nota, valor) com empate de valor          24.322   (o desempate decide)
--    notas procNF sem nenhum item                    0
--
--  As ~107 notas sem item sao resumo (resNFe): o resumo nao traz <det>. Ficam
--  nulas, e a tela nao preve categoria para elas - correto.
--
--  ==========================================================================
--   TRAVAS
--  ==========================================================================
--  - So toca linha com cod_cfop_xml nulo: reexecutar nao muda nada, e nao
--    sobrescreve o que a ApiNFE ja gravou.
--  - Carimbo unico em updated_by ('AJUSTE 2026-10-06 CFOP XML'), que e o que o
--    rollback usa para achar as linhas.
--  - Nao reprocessa XML nem mexe em dpc_dfe_nota_item.
--
--  Conectado como POSEIDON. Rodar secao por secao (Ctrl+Enter).
-- ============================================================================


-- ============================================================================
--  SECAO 0 - FOTO ANTES (esperado: preenchidas = 0, ou so as nascidas depois do deploy)
-- ============================================================================

select count(*) as notas,
       sum(case when cod_cfop_xml is not null then 1 else 0 end) as preenchidas,
       sum(case when exists (select 1 from poseidon.dpc_dfe_nota_item i
                              where i.cod_dfe_nota = n.cod_dfe_nota) then 1 else 0 end) as com_item
  from poseidon.dpc_dfe_nota n;


-- ============================================================================
--  SECAO 1 - PREENCHER
-- ============================================================================

merge /*+ USE_HASH(n x) */ into poseidon.dpc_dfe_nota n
using (select cod_dfe_nota, to_number(cod_cfop) as cfop
         from (select i.cod_dfe_nota, i.cod_cfop,
                      row_number() over (partition by i.cod_dfe_nota
                                         order by i.vlr_item desc nulls last,
                                                  i.cod_dfe_nota_item) as rn
                 from poseidon.dpc_dfe_nota_item i
                where regexp_like(i.cod_cfop, '^[0-9]{4}$'))
        where rn = 1) x
   on (n.cod_dfe_nota = x.cod_dfe_nota)
 when matched then update
      set n.cod_cfop_xml = x.cfop,
          n.updated_at   = sysdate,
          n.updated_by   = 'AJUSTE 2026-10-06 CFOP XML'
    where n.cod_cfop_xml is null;

commit;


-- ============================================================================
--  SECAO 2 - CONFERENCIA
-- ============================================================================
--  Esperado: preenchidas = com_item (9.582 + as que chegaram depois), e
--  sem_cfop_com_item = 0.

select count(*) as notas,
       sum(case when n.cod_cfop_xml is not null then 1 else 0 end) as preenchidas,
       sum(case when n.cod_cfop_xml is null
                 and exists (select 1 from poseidon.dpc_dfe_nota_item i
                              where i.cod_dfe_nota = n.cod_dfe_nota) then 1 else 0 end) as sem_cfop_com_item
  from poseidon.dpc_dfe_nota n;

--  Distribuicao: CFOPs de entrada de fornecedor (5xxx/6xxx) e devolucao
--  (1xxx/2xxx, quando o emitente e o proprio grupo) devem dominar.
select cod_cfop_xml, count(*) as qtd
  from poseidon.dpc_dfe_nota
 where cod_cfop_xml is not null
 group by cod_cfop_xml
 order by 2 desc
 fetch first 15 rows only;
