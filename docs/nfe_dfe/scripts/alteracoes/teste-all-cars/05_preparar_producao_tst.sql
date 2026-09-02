-- ============================================================================
--  05 - preparar a chamada em PRODUCAO com seguranca
-- ============================================================================
--  SOMENTE HOMOLOGACAO (tst). Reescrito em 02/09/2026.
--
--  POR QUE MUDOU DE FORMA
--  ----------------------
--  Os dois updates escreviam em DPC_DFE_EMPRESA colunas que sairam dela no
--  commit 39b172d: status_sincronismo, dta_liberado_em, cod_ultimo_status e
--  dsc_ultimo_motivo vivem agora em DPC_DFE_CURSOR, uma linha por tipo de
--  documento. Rodado hoje, o script morreria com ORA-00904.
--
--  CONTEXTO
--  --------
--  O .env passa para TIPO_AMBIENTE=1 (SEFAZ de producao) porque em homologacao o
--  Ambiente Nacional nao tem documento de ninguem: devolve sempre cStat 137 e
--  maxNSU 0, o que nao mede o movimento real do CNPJ.
--
--  As duas coisas que este script faz sao reversiveis.
-- ============================================================================


-- ---------------------------------------------------------------------------
--  1. TRANCA: deixar somente a empresa 900 operavel
-- ---------------------------------------------------------------------------
--  Com TIPO_AMBIENTE=1, um "dfe:ingerir" sem --empresa consultaria os CNPJs da
--  DPC na SEFAZ de PRODUCAO - exatamente o que nao pode acontecer enquanto a
--  Qive estiver ativa: duas aplicacoes no mesmo CNPJ e consumo indevido (656).
--
--  Pausar os fluxos da DPC faz o esquecimento de uma flag deixar de ser
--  incidente. 'P' e o mesmo status da pausa operacional, e o dfe:ingerir nao
--  consulta fluxo pausado.
update poseidon.dpc_dfe_cursor
   set status_sincronismo = 'P',
       dsc_ultimo_motivo  = 'pausado durante teste ALL CARS',
       updated_at         = sysdate,
       updated_by         = 'TESTE DFE'
 where status_sincronismo <> 'P'
   and cod_dfe_empresa <> (select cod_dfe_empresa
                             from poseidon.dpc_dfe_empresa
                            where nro_empresa = 900);


-- ---------------------------------------------------------------------------
--  2. Liberar os fluxos da 900 do cooldown
-- ---------------------------------------------------------------------------
--  A chamada em homologacao devolveu cStat 137 e a rotina gravou
--  dta_liberado_em = +60min - comportamento correto, a NT manda esperar 1 hora
--  depois de um 137. Mas aquele 137 veio de homologacao, onde nao existe
--  documento algum: nao e informacao sobre o CNPJ e nao deve custar 1 hora.
--
--  O CURSOR NAO E TOCADO. nro_ultimo_nsu continua como esta, e isso e
--  deliberado: o NSU e um token que a fonte devolve e que so pode ser
--  CONTINUADO. Valor arbitrario retorna 656 e bloqueia o certificado.
update poseidon.dpc_dfe_cursor
   set dta_liberado_em   = null,
       cod_ultimo_status = null,
       dsc_ultimo_motivo = 'liberado para teste em producao',
       updated_at        = sysdate,
       updated_by        = 'TESTE DFE'
 where cod_dfe_empresa = (select cod_dfe_empresa
                            from poseidon.dpc_dfe_empresa
                           where nro_empresa = 900);

commit;


-- ---------------------------------------------------------------------------
--  3. Conferencia
-- ---------------------------------------------------------------------------
--  ESPERADO: os fluxos da 900 com dta_liberado_em nulo; TODOS os outros com P.
select e.nro_empresa,
       e.num_cnpj,
       c.cod_tipo_dfe,
       c.status_sincronismo,
       c.nro_ultimo_nsu,
       c.dta_liberado_em,
       c.dsc_ultimo_motivo
  from poseidon.dpc_dfe_cursor c
  join poseidon.dpc_dfe_empresa e on e.cod_dfe_empresa = c.cod_dfe_empresa
 order by case when e.nro_empresa = 900 then 0 else 1 end,
          e.nro_empresa, c.cod_tipo_dfe;

--  ESPERADO: nenhum fluxo ativo fora da 900.
select count(*) as ativos_fora_da_900
  from poseidon.dpc_dfe_cursor c
  join poseidon.dpc_dfe_empresa e on e.cod_dfe_empresa = c.cod_dfe_empresa
 where c.status_sincronismo = 'A'
   and e.nro_empresa <> 900;
-- ============================================================================
