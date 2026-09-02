-- ============================================================================
--  02 - empresa 30 no modulo DFe: identidade + os 4 fluxos de cursor
-- ============================================================================
--  SOMENTE tst. Reescrito em 02/09/2026.
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
--  O script antigo, rodado hoje, morreria com ORA-00904: invalid identifier.
--
--  O cursor por tipo e o ponto central: NF-e, CT-e, MDF-e e NFS-e tem sequencias
--  de NSU INDEPENDENTES. O NSU 100 da NF-e e o NSU 100 do CT-e sao documentos
--  diferentes.
--
--  NASCE PAUSADO, e isto e deliberado
--  ----------------------------------
--  Esta empresa usa o e-CNPJ da MATRIZ, compartilhado com as empresas 1, 3 e 8
--  (e com a Qive). O consumo da SEFAZ e contabilizado por CERTIFICADO e por IP,
--  nao por CNPJ - medido em campo: a empresa 8 tomou cStat 656 na PRIMEIRA
--  consulta dela, minutos depois do bloqueio da matriz.
--
--  Consequencia: um 656 aqui bloqueia o certificado do GRUPO por 1 hora. Nao se
--  aplicava a ALL CARS, que tem certificado proprio de outra raiz.
--
--  cod_dfe_empresa e cod_dfe_cursor nao vao nos inserts: as triggers preenchem.
-- ============================================================================


-- ---------------------------------------------------------------------------
--  1. Identidade fiscal
-- ---------------------------------------------------------------------------
--  Os valores sao literais de proposito, e nao lidos do ERP: depois do 39b172d
--  esta tabela E a fonte unica de identidade do modulo. Sao os mesmos que o
--  02_carga_inicial de producao usa para esta empresa.
insert into poseidon.dpc_dfe_empresa
  (nro_empresa, num_cnpj, dsc_razao_social, sig_uf, num_inscr_estadual,
   status_manifestar, created_at, created_by)
select 30,
       '66471517003001',
       'DPC DISTRIBUIDOR ATACADISTA S/A',
       'MS',
       '500041350',
       'N',                     -- manifestar e ato fiscal: nao ligar aqui
       sysdate,
       'CADASTRO DFE'
  from dual
 where not exists (select 1
                     from poseidon.dpc_dfe_empresa
                    where num_cnpj = '66471517003001');

commit;


-- ---------------------------------------------------------------------------
--  2. Os 4 fluxos, todos pausados
-- ---------------------------------------------------------------------------
--  A lista de tipos vai por UNION ALL, e nao por table(sys.odcivarchar2list(...)):
--  aquele tipo depende de grant de execucao em SYS, e um cadastro nao deve parar
--  por privilegio que ninguem lembrou de conceder.
--
--  qtd_min_em_dia = 60 e o minimo exigido pela NT 2014.002 depois de um cStat
--  137. Em 01/09/2026 os fluxos de SEFAZ em tst foram para 120 - se quiser o
--  mesmo aqui, ajuste depois de ativar, nao agora.
insert into poseidon.dpc_dfe_cursor
  (cod_dfe_empresa, cod_tipo_dfe, status_sincronismo,
   nro_ultimo_nsu, nro_maximo_nsu,
   qtd_min_entre_consulta, qtd_min_em_dia,
   dsc_ultimo_motivo, created_at, created_by)
select e.cod_dfe_empresa,
       t.tipo,
       'P',                     -- PAUSADO de proposito
       0,                       -- cursor novo: a SEFAZ entrega o que ainda
       0,                       -- estiver na janela de retencao de 90 dias
       3,
       60,
       'fluxo criado pausado: certificado compartilhado com a matriz, ativar exige a janela de corte da Qive',
       sysdate,
       'CADASTRO DFE'
  from poseidon.dpc_dfe_empresa e
 cross join (select 'NFE'  as tipo from dual union all
             select 'CTE'         from dual union all
             select 'MDFE'        from dual union all
             select 'NFSE'        from dual) t
 where e.nro_empresa = 30
   and not exists (select 1
                     from poseidon.dpc_dfe_cursor c
                    where c.cod_dfe_empresa = e.cod_dfe_empresa
                      and c.cod_tipo_dfe    = t.tipo);

commit;


-- ---------------------------------------------------------------------------
--  3. Conferencia
-- ---------------------------------------------------------------------------
--  3a. A identidade. ESPERADO: 1 linha, CNPJ com 14 digitos.
--
--  O tamanho importa: com 13 digitos a consulta a SEFAZ sai malformada. A
--  verificacao antiga chamava uma function do ERP para montar o CNPJ; hoje o
--  valor e nosso e literal, entao basta conferir o que esta gravado.
select cod_dfe_empresa,
       nro_empresa,
       num_cnpj,
       length(num_cnpj)  as tam_cnpj,
       dsc_razao_social,
       sig_uf,
       num_inscr_estadual,
       status_manifestar
  from poseidon.dpc_dfe_empresa
 where nro_empresa = 30;

--  3b. Os fluxos. ESPERADO: 4 linhas (NFE, CTE, MDFE, NFSE), todas com P e 0.
select c.cod_dfe_cursor,
       c.cod_tipo_dfe,
       c.status_sincronismo,
       c.nro_ultimo_nsu,
       c.nro_maximo_nsu,
       c.qtd_min_em_dia,
       c.dta_liberado_em,
       c.dsc_ultimo_motivo
  from poseidon.dpc_dfe_cursor c
  join poseidon.dpc_dfe_empresa e on e.cod_dfe_empresa = c.cod_dfe_empresa
 where e.nro_empresa = 30
 order by c.cod_tipo_dfe;

--  3c. Panorama: quem esta operavel na base inteira.
select e.nro_empresa,
       e.num_cnpj,
       c.cod_tipo_dfe,
       c.status_sincronismo,
       c.nro_ultimo_nsu,
       c.dta_liberado_em
  from poseidon.dpc_dfe_cursor c
  join poseidon.dpc_dfe_empresa e on e.cod_dfe_empresa = c.cod_dfe_empresa
 order by case when c.status_sincronismo = 'A' then 0 else 1 end,
          e.nro_empresa, c.cod_tipo_dfe;


-- ---------------------------------------------------------------------------
--  4. ATIVAR - somente apos decisao sobre a Qive
-- ---------------------------------------------------------------------------
--  NAO rode isto agora. Enquanto a Qive consultar este CNPJ, ou qualquer outro
--  que use o mesmo certificado, ativar significa duas aplicacoes competindo pela
--  mesma cota - com bloqueio de 1 hora atingindo tambem as empresas 1, 3 e 8.
--
--  Ative UM tipo por vez. Ativar os quatro de uma vez faz o mesmo certificado
--  ser usado quatro vezes em sequencia, e o motor consulta um fluxo por
--  certificado por ciclo justamente para nao disputar consigo mesmo.
--
--  update poseidon.dpc_dfe_cursor
--     set status_sincronismo = 'A',
--         dta_liberado_em    = null,
--         cod_ultimo_status  = null,
--         dsc_ultimo_motivo  = 'ativado apos corte da Qive',
--         updated_at         = sysdate,
--         updated_by         = 'CADASTRO DFE'
--   where cod_dfe_empresa = (select cod_dfe_empresa
--                              from poseidon.dpc_dfe_empresa
--                             where nro_empresa = 30)
--     and cod_tipo_dfe = 'NFE';
--  commit;
--
--  Primeira consulta, uma chamada so, para ver o maxNSU antes de drenar:
--
--      php artisan dfe:ingerir --empresa=30 --tipo=NFE --max-consultas=1 --debug
-- ============================================================================
