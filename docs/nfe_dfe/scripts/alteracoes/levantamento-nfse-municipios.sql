-- ============================================================================
--  LEVANTAMENTO: de quais municipios a DPC recebe NFS-e
-- ============================================================================
--  PARA QUE SERVE
--  Decidir se vale construir a captura de NFS-e pelo ADN (Ambiente de Dados
--  Nacional da NFS-e Nacional).
--
--  O ADN distribui DF-e por NSU - mesmo modelo do que ja fizemos para NF-e e
--  CT-e -, e o TOMADOR pode consultar as notas tomadas. Mas a cobertura depende
--  da ADESAO DO MUNICIPIO: hoje a NFS-e Nacional representa cerca de 70% do
--  volume de emissoes no pais, e municipio com sistema proprio que nao adere
--  fica fora.
--
--  Ou seja: o ADN nao substitui a captura de NFS-e por completo. Este
--  levantamento mede o tamanho do "resto" NO CASO DA DPC, que e o que decide
--  entre construir, esperar, ou manter a Qive so para NFS-e.
--
--  Rodar em PRODUCAO (prd), somente SELECT.
--
--  ATENCAO: mlf_notafiscal tem 390 colunas e volume de ERP inteiro. As consultas
--  abaixo tem filtro de data de proposito - nao remova.
-- ============================================================================


-- ###########################################################################
--  ETAPA 1 - como o Consinco marca nota de SERVICO?
-- ###########################################################################
--  Nao ha modelo nacional unico para NFS-e como o 55 da NF-e, entao primeiro
--  descobrimos qual combinacao identifica servico nesta base. Rode e olhe qual
--  criterio isola o que voce reconhece como nota de servico.

--  1a. Distribuicao por modelo/tipo onde HA numero de NFS-e
select nf.modelonf,
       nf.tipnotafiscal,
       count(*)                    as qtd,
       count(nf.numeronfse)        as com_numeronfse,
       sum(case when nvl(nf.vlrservico, 0) > 0 then 1 else 0 end) as com_vlrservico,
       min(nf.dtaemissao)          as emissao_min,
       max(nf.dtaemissao)          as emissao_max
  from consinco.mlf_notafiscal nf
 where nf.dtaemissao >= add_months(trunc(sysdate), -12)
   and (nf.numeronfse is not null or nvl(nf.vlrservico, 0) > 0)
 group by nf.modelonf, nf.tipnotafiscal
 order by qtd desc;

--  1b. As duas marcacoes coincidem? Se numeronfse e vlrservico divergirem muito,
--      escolha o criterio que cobre melhor e ajuste a ETAPA 2.
select sum(case when numeronfse is not null and nvl(vlrservico,0) > 0 then 1 else 0 end) as ambos,
       sum(case when numeronfse is not null and nvl(vlrservico,0) = 0 then 1 else 0 end) as so_numeronfse,
       sum(case when numeronfse is null     and nvl(vlrservico,0) > 0 then 1 else 0 end) as so_vlrservico
  from consinco.mlf_notafiscal
 where dtaemissao >= add_months(trunc(sysdate), -12);


-- ###########################################################################
--  ETAPA 2 - de quais municipios vem, por volume
-- ###########################################################################
--  O prestador e o SEQPESSOA da nota; o municipio dele vem de ge_pessoa.
--
--  Se a ETAPA 1 mostrar que o criterio certo e outro (um modelonf especifico,
--  por exemplo), troque o filtro marcado com <<< AJUSTAR >>>.

select p.uf,
       p.cidade,
       p.seqcidade,
       count(*)                          as qtd_notas,
       count(distinct nf.seqpessoa)      as qtd_prestadores,
       round(sum(nvl(nf.vlrservico, 0)), 2) as vlr_total,
       min(nf.dtaemissao)                as emissao_min,
       max(nf.dtaemissao)                as emissao_max
  from consinco.mlf_notafiscal nf
  join consinco.ge_pessoa      p  on p.seqpessoa = nf.seqpessoa
 where nf.dtaemissao >= add_months(trunc(sysdate), -12)
   and nf.numeronfse is not null            -- <<< AJUSTAR conforme ETAPA 1
 group by p.uf, p.cidade, p.seqcidade
 order by qtd_notas desc;


-- ###########################################################################
--  ETAPA 3 - concentracao: quantos municipios respondem por 80% do volume?
-- ###########################################################################
--  E o numero que decide. Se 15 municipios concentram 80% das notas, basta
--  conferir a adesao desses 15 ao padrao nacional para saber a cobertura real.
--  Se estiver espalhado em 300 municipios, o ADN cobre pouco e o esforco muda de
--  natureza.
with servico as (
  select p.uf, p.cidade, count(*) as qtd
    from consinco.mlf_notafiscal nf
    join consinco.ge_pessoa      p on p.seqpessoa = nf.seqpessoa
   where nf.dtaemissao >= add_months(trunc(sysdate), -12)
     and nf.numeronfse is not null           -- <<< AJUSTAR conforme ETAPA 1
   group by p.uf, p.cidade
),
ranqueado as (
  select uf, cidade, qtd,
         sum(qtd) over (order by qtd desc, uf, cidade) as acumulado,
         sum(qtd) over ()                              as total,
         row_number() over (order by qtd desc, uf, cidade) as posicao
    from servico
)
select posicao, uf, cidade, qtd,
       round(100 * qtd / total, 2)        as pct,
       round(100 * acumulado / total, 2)  as pct_acumulado
  from ranqueado
 where acumulado <= total * 0.8
    or posicao = 1
 order by posicao;

--  3b. Panorama de uma linha.
select count(*)                     as municipios_distintos,
       sum(qtd)                     as total_notas
  from (
    select p.uf, p.cidade, count(*) as qtd
      from consinco.mlf_notafiscal nf
      join consinco.ge_pessoa      p on p.seqpessoa = nf.seqpessoa
     where nf.dtaemissao >= add_months(trunc(sysdate), -12)
       and nf.numeronfse is not null         -- <<< AJUSTAR conforme ETAPA 1
     group by p.uf, p.cidade
  );


-- ###########################################################################
--  O QUE FAZER COM O RESULTADO
-- ###########################################################################
--  Com a lista da ETAPA 3 em maos, conferir a adesao de cada municipio ao padrao
--  nacional em https://www.gov.br/nfse (os municipios aderentes sao publicados).
--
--  Tres desfechos possiveis:
--
--   - cobertura alta (a maior parte do volume em municipios aderentes)
--     -> construir a captura via ADN vale a pena. E projeto PROPRIO, nao
--        extensao deste motor: o transporte e REST, nao SOAP com sped-*. O
--        modelo conceitual (cursor por NSU, duas etapas, guardar o bruto antes
--        de interpretar) se aproveita inteiro.
--
--   - cobertura baixa
--     -> o ADN resolve pouco. A Qive segue necessaria SO para NFS-e, e a
--        conversa com a gestao muda: deixa de ser "substituir a Qive" e passa a
--        ser "reduzir a Qive a NFS-e".
--
--   - cobertura media
--     -> construir o ADN e conviver, com a Qive cobrindo os municipios de fora.
--        Aqui vale medir o custo da Qive por documento antes de decidir.
-- ============================================================================
