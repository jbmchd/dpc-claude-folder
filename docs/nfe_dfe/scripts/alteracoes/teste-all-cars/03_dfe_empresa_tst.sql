-- ============================================================================
--  03 - ALL CARS no modulo DFe: identidade + os 4 fluxos de cursor
-- ============================================================================
--  SOMENTE HOMOLOGACAO (tst). Descartavel. Reescrito em 02/09/2026.
--
--  POR QUE ESTE SCRIPT MUDOU DE FORMA
--  ----------------------------------
--  A versao anterior gravava status_sincronismo, nro_ultimo_nsu, nro_maximo_nsu,
--  qtd_min_entre_consulta e qtd_min_em_dia dentro de DPC_DFE_EMPRESA. Aquelas
--  colunas SAIRAM daquela tabela no commit 39b172d, que separou identidade de
--  posicao de leitura:
--
--      DPC_DFE_EMPRESA  ->  quem e o CNPJ (identidade fiscal)
--      DPC_DFE_CURSOR   ->  de onde continuar, UMA LINHA POR TIPO DE DOCUMENTO
--
--  Rodada hoje, a versao antiga morreria com ORA-00904: invalid identifier.
--
--  E o mesmo commit e a razao de a identidade vir aqui: antes o motor lia razao
--  social e UF do cadastro do ERP, e por isso o 01_ge_empresa_tst era
--  obrigatorio. Hoje esta tabela e a fonte unica, e aquele script ficou
--  desnecessario.
--
--  cod_dfe_empresa e cod_dfe_cursor nao vao nos inserts: as triggers preenchem.
-- ============================================================================


-- ---------------------------------------------------------------------------
--  1. Identidade fiscal
-- ---------------------------------------------------------------------------
--  num_inscr_estadual vai NULO: nao foi levantado para esta PJ de teste, e o
--  distDFeInt nao usa IE - ele leva CNPJ e cUF. So faz falta se algum dia esta
--  empresa for EMITIR documento, o que nao e o caso.
insert into poseidon.dpc_dfe_empresa
  (nro_empresa, num_cnpj, dsc_razao_social, sig_uf, num_inscr_estadual,
   status_manifestar, created_at, created_by)
select 900,
       '45694407000102',
       'ALL CARS ASSETS LTDA',
       'MG',                    -- vira o cUFAutor do distDFeInt
       null,
       'N',                     -- manifestar e ato fiscal com protocolo
       sysdate,                 -- definitivo, e esta e PJ distinta: nao ligar
       'TESTE DFE'
  from dual
 where not exists (select 1
                     from poseidon.dpc_dfe_empresa
                    where num_cnpj = '45694407000102');

commit;


-- ---------------------------------------------------------------------------
--  2. Os 4 fluxos, todos pausados
-- ---------------------------------------------------------------------------
--  NASCEM PAUSADOS, ao contrario da versao antiga, que nascia com 'A'.
--
--  A razao mudou com o ambiente: hoje o agendador roda de 15 em 15 minutos com
--  RUN_SCHEDULE=1, entao fluxo inserido como ativo e consultado na SEFAZ no
--  proximo ciclo, sem ninguem olhando. Nascer pausado transforma a ativacao em
--  ato deliberado, com a primeira chamada supervisionada.
--
--  E ha o caso concreto: o fluxo NFE desta empresa esta pausado hoje em tst de
--  proposito - CNPJ ocioso (ultNSU 87, imovel) devolve 656 mesmo respeitando a
--  espera. Recriar como ativo desfaria essa decisao em silencio.
--
--  A lista de tipos vai por UNION ALL, e nao por table(sys.odcivarchar2list(...)):
--  aquele tipo depende de grant de execucao em SYS.
insert into poseidon.dpc_dfe_cursor
  (cod_dfe_empresa, cod_tipo_dfe, status_sincronismo,
   nro_ultimo_nsu, nro_maximo_nsu,
   qtd_min_entre_consulta, qtd_min_em_dia,
   dsc_ultimo_motivo, created_at, created_by)
select e.cod_dfe_empresa,
       t.tipo,
       'P',
       0,                       -- cursor novo: a SEFAZ entrega o que ainda
       0,                       -- estiver na janela de retencao de 90 dias
       3,
       60,                      -- minimo da NT 2014.002 depois de um cStat 137
       'fluxo criado pausado: ativar um tipo por vez, com a primeira chamada supervisionada',
       sysdate,
       'TESTE DFE'
  from poseidon.dpc_dfe_empresa e
 cross join (select 'NFE'  as tipo from dual union all
             select 'CTE'         from dual union all
             select 'MDFE'        from dual union all
             select 'NFSE'        from dual) t
 where e.nro_empresa = 900
   and not exists (select 1
                     from poseidon.dpc_dfe_cursor c
                    where c.cod_dfe_empresa = e.cod_dfe_empresa
                      and c.cod_tipo_dfe    = t.tipo);

commit;


-- ---------------------------------------------------------------------------
--  3. Conferencia
-- ---------------------------------------------------------------------------
--  3a. A identidade. ESPERADO: 1 linha, CNPJ com 14 digitos.
select cod_dfe_empresa,
       nro_empresa,
       num_cnpj,
       length(num_cnpj) as tam_cnpj,
       dsc_razao_social,
       sig_uf,
       status_manifestar
  from poseidon.dpc_dfe_empresa
 where nro_empresa = 900;

--  3b. Os fluxos. ESPERADO: 4 linhas, todas com P e cursor 0.
select c.cod_dfe_cursor,
       c.cod_tipo_dfe,
       c.status_sincronismo,
       c.nro_ultimo_nsu,
       c.nro_maximo_nsu,
       c.dta_liberado_em
  from poseidon.dpc_dfe_cursor c
  join poseidon.dpc_dfe_empresa e on e.cod_dfe_empresa = c.cod_dfe_empresa
 where e.nro_empresa = 900
 order by c.cod_tipo_dfe;

--  3c. As empresas DPC NAO devem ter mudado.
select e.nro_empresa, e.num_cnpj, c.cod_tipo_dfe,
       c.status_sincronismo, c.nro_ultimo_nsu
  from poseidon.dpc_dfe_cursor c
  join poseidon.dpc_dfe_empresa e on e.cod_dfe_empresa = c.cod_dfe_empresa
 order by e.nro_empresa, c.cod_tipo_dfe;


-- ---------------------------------------------------------------------------
--  4. ATIVAR - um tipo por vez
-- ---------------------------------------------------------------------------
--  Este CNPJ e seguro de testar: a Qive nao o atende e o certificado e proprio,
--  de outra raiz (45694407), entao um 656 aqui NAO atinge o e-CNPJ da matriz.
--
--  update poseidon.dpc_dfe_cursor
--     set status_sincronismo = 'A',
--         dta_liberado_em    = null,
--         cod_ultimo_status  = null,
--         dsc_ultimo_motivo  = 'ativado para teste',
--         updated_at         = sysdate,
--         updated_by         = 'TESTE DFE'
--   where cod_dfe_empresa = (select cod_dfe_empresa
--                              from poseidon.dpc_dfe_empresa
--                             where nro_empresa = 900)
--     and cod_tipo_dfe = 'NFSE';
--  commit;
--
--  Primeira chamada, uma so, para ver o maxNSU antes de drenar:
--
--      dev.cmd dfe:ingerir --empresa=900 --tipo=NFSE --max-consultas=1 --debug
-- ============================================================================
