-- ============================================================================
--  MODULO DFe - CARGA INICIAL EM PRODUCAO
-- ============================================================================
--  Rodar DEPOIS do 01_estrutura_dbeaver.sql.
--  Como POSEIDON, script inteiro com Alt+X. Reexecutavel.
--
--  ==========================================================================
--   TODO FLUXO NASCE PAUSADO. ISSO NAO E CAUTELA GENERICA.
--  ==========================================================================
--  A posicao de leitura (NSU) e UMA POR CNPJ e COMPARTILHADA entre quem
--  consulta. Hoje quem consulta os CNPJs da DPC e a Qive. Dois consumidores no
--  mesmo CNPJ e causa DOCUMENTADA de consumo indevido (cStat 656), que bloqueia
--  o CNPJ por 1 hora - e o consumo e contabilizado por CERTIFICADO e por IP,
--  entao um bloqueio atinge todas as filiais que compartilham o e-CNPJ da
--  matriz.
--
--  Portanto: criar as linhas aqui NAO liga nada. Ativar um fluxo exige,
--  primeiro, saber a data e hora em que a Qive para de consultar aquele CNPJ.
--
--  Confirmado em 20/08/2026: a Qive atende TODOS os CNPJs da DPC, com duas
--  excecoes - a empresa 900 (ALL CARS, cadastro de teste) e a empresa 30
--  (filial MS). Toda validacao em producao foi feita nessas duas.
--
--  ==========================================================================
--   DE ONDE VEM ESTA IDENTIDADE
--  ==========================================================================
--  Os valores abaixo sao os de poseidon.dpc_dfe_empresa em HOMOLOGACAO, onde
--  ja alimentaram o configJson do sped em execucao real contra a SEFAZ e o ADN.
--  Sao literais de proposito, e nao um INSERT ... SELECT lendo o ERP:
--
--   - o motor foi DESACOPLADO do ERP (commit 39b172d). A identidade fiscal e
--     nossa, mora em dpc_dfe_empresa, e nao deve voltar a depender de
--     cadastro de empresa do ERP nem de function do ERP;
--   - a leitura antiga tinha duas armadilhas caras, as duas silenciosas: um
--     INNER JOIN do cadastro do ERP sumia com a linha quando um codigo de
--     cidade era nulo, e uma function do ERP devolvia NULL sem erro quando a
--     pessoa nao estava cadastrada. Nenhuma das duas e mais usada aqui.
--
--  A ALL CARS (900) NAO entra: e cadastro de teste e o certificado dela nao
--  existe em producao.
--
--  ==========================================================================
--   CADASTRO AQUI NAO E CERTIFICADO LA
--  ==========================================================================
--  Estas linhas nao dependem de o certificado existir. O levantamento de
--  06/08/2026 em producao encontrou, dos 27 CNPJs ativos, apenas 3 com
--  certificado utilizavel (empresas 1, 3 e 8); 7 expirados em 13/11/2025 e 2 com
--  senha errada gravada.
--
--  Cadastrar o fluxo mesmo assim e correto: quem reporta saude de certificado e
--  o dfe:monitorar, e ele so ve o que esta cadastrado. Fluxo ausente nao gera
--  alerta - e foi assim que um vencimento passou 9 meses sem ninguem notar.
-- ============================================================================


-- ###########################################################################
--  1. ESTABELECIMENTOS  (13 linhas)
-- ###########################################################################

declare
  qtd number;
begin
  select count(*) into qtd from poseidon.dpc_dfe_empresa where num_cnpj = '66471517000177';

  if qtd = 0 then
    insert into poseidon.dpc_dfe_empresa
      (nro_empresa, num_cnpj, dsc_razao_social, sig_uf, num_inscr_estadual,
       status_manifestar, created_at, created_by)
    values
      (1, '66471517000177', 'DPC DISTRIBUIDOR ATACADISTA S/A', 'MG', '1348384310043',
       'N', sysdate, 'CARGA INICIAL');
  end if;
end;

declare
  qtd number;
begin
  select count(*) into qtd from poseidon.dpc_dfe_empresa where num_cnpj = '66471517000258';

  if qtd = 0 then
    insert into poseidon.dpc_dfe_empresa
      (nro_empresa, num_cnpj, dsc_razao_social, sig_uf, num_inscr_estadual,
       status_manifestar, created_at, created_by)
    values
      (2, '66471517000258', 'DPC DISTRIBUIDOR ATACADISTA S/A', 'RJ', '75674554',
       'N', sysdate, 'CARGA INICIAL');
  end if;
end;

declare
  qtd number;
begin
  select count(*) into qtd from poseidon.dpc_dfe_empresa where num_cnpj = '66471517000339';

  if qtd = 0 then
    insert into poseidon.dpc_dfe_empresa
      (nro_empresa, num_cnpj, dsc_razao_social, sig_uf, num_inscr_estadual,
       status_manifestar, created_at, created_by)
    values
      (3, '66471517000339', 'DPC DISTRIBUIDOR ATACADISTA S/A', 'MG', '1348384310124',
       'N', sysdate, 'CARGA INICIAL');
  end if;
end;

declare
  qtd number;
begin
  select count(*) into qtd from poseidon.dpc_dfe_empresa where num_cnpj = '66471517000924';

  if qtd = 0 then
    insert into poseidon.dpc_dfe_empresa
      (nro_empresa, num_cnpj, dsc_razao_social, sig_uf, num_inscr_estadual,
       status_manifestar, created_at, created_by)
    values
      (4, '66471517000924', 'DPC DISTRIBUIDOR ATACADISTA S/A', 'BA', '88341600',
       'N', sysdate, 'CARGA INICIAL');
  end if;
end;

declare
  qtd number;
begin
  select count(*) into qtd from poseidon.dpc_dfe_empresa where num_cnpj = '66471517001149';

  if qtd = 0 then
    insert into poseidon.dpc_dfe_empresa
      (nro_empresa, num_cnpj, dsc_razao_social, sig_uf, num_inscr_estadual,
       status_manifestar, created_at, created_by)
    values
      (5, '66471517001149', 'DPC DISTRIBUIDOR ATACADISTA S/A', 'SE', '271324961',
       'N', sysdate, 'CARGA INICIAL');
  end if;
end;

declare
  qtd number;
begin
  select count(*) into qtd from poseidon.dpc_dfe_empresa where num_cnpj = '66471517000843';

  if qtd = 0 then
    insert into poseidon.dpc_dfe_empresa
      (nro_empresa, num_cnpj, dsc_razao_social, sig_uf, num_inscr_estadual,
       status_manifestar, created_at, created_by)
    values
      (8, '66471517000843', 'DPC DISTRIBUIDOR ATACADISTA S/A', 'ES', '082467293',
       'N', sysdate, 'CARGA INICIAL');
  end if;
end;

declare
  qtd number;
begin
  select count(*) into qtd from poseidon.dpc_dfe_empresa where num_cnpj = '66471517001491';

  if qtd = 0 then
    insert into poseidon.dpc_dfe_empresa
      (nro_empresa, num_cnpj, dsc_razao_social, sig_uf, num_inscr_estadual,
       status_manifestar, created_at, created_by)
    values
      (14, '66471517001491', 'DPC DISTRIBUIDOR ATACADISTA S/A', 'SP', '190544799111',
       'N', sysdate, 'CARGA INICIAL');
  end if;
end;

declare
  qtd number;
begin
  select count(*) into qtd from poseidon.dpc_dfe_empresa where num_cnpj = '66471517002544';

  if qtd = 0 then
    insert into poseidon.dpc_dfe_empresa
      (nro_empresa, num_cnpj, dsc_razao_social, sig_uf, num_inscr_estadual,
       status_manifestar, created_at, created_by)
    values
      (15, '66471517002544', 'DPC DISTRIBUIDOR ATACADISTA S/A', 'AL', '241094550',
       'N', sysdate, 'CARGA INICIAL');
  end if;
end;

declare
  qtd number;
begin
  select count(*) into qtd from poseidon.dpc_dfe_empresa where num_cnpj = '66471517001653';

  if qtd = 0 then
    insert into poseidon.dpc_dfe_empresa
      (nro_empresa, num_cnpj, dsc_razao_social, sig_uf, num_inscr_estadual,
       status_manifestar, created_at, created_by)
    values
      (16, '66471517001653', 'DPC DISTRIBUIDOR ATACADISTA S/A', 'MG', '1348384310388',
       'N', sysdate, 'CARGA INICIAL');
  end if;
end;

declare
  qtd number;
begin
  select count(*) into qtd from poseidon.dpc_dfe_empresa where num_cnpj = '66471517001734';

  if qtd = 0 then
    insert into poseidon.dpc_dfe_empresa
      (nro_empresa, num_cnpj, dsc_razao_social, sig_uf, num_inscr_estadual,
       status_manifestar, created_at, created_by)
    values
      (17, '66471517001734', 'DPC DISTRIBUIDOR ATACADISTA S/A', 'PE', '061207764',
       'N', sysdate, 'CARGA INICIAL');
  end if;
end;

declare
  qtd number;
begin
  select count(*) into qtd from poseidon.dpc_dfe_empresa where num_cnpj = '66471517001815';

  if qtd = 0 then
    insert into poseidon.dpc_dfe_empresa
      (nro_empresa, num_cnpj, dsc_razao_social, sig_uf, num_inscr_estadual,
       status_manifestar, created_at, created_by)
    values
      (18, '66471517001815', 'DPC DISTRIBUIDOR ATACADISTA S/A', 'PB', '162670583',
       'N', sysdate, 'CARGA INICIAL');
  end if;
end;

declare
  qtd number;
begin
  select count(*) into qtd from poseidon.dpc_dfe_empresa where num_cnpj = '66471517001904';

  if qtd = 0 then
    insert into poseidon.dpc_dfe_empresa
      (nro_empresa, num_cnpj, dsc_razao_social, sig_uf, num_inscr_estadual,
       status_manifestar, created_at, created_by)
    values
      (19, '66471517001904', 'DPC DISTRIBUIDOR ATACADISTA S/A', 'RN', '204275571',
       'N', sysdate, 'CARGA INICIAL');
  end if;
end;

declare
  qtd number;
begin
  select count(*) into qtd from poseidon.dpc_dfe_empresa where num_cnpj = '66471517003001';

  if qtd = 0 then
    insert into poseidon.dpc_dfe_empresa
      (nro_empresa, num_cnpj, dsc_razao_social, sig_uf, num_inscr_estadual,
       status_manifestar, created_at, created_by)
    values
      (30, '66471517003001', 'DPC DISTRIBUIDOR ATACADISTA S/A', 'MS', '500041350',
       'N', sysdate, 'CARGA INICIAL');
  end if;
end;


-- ###########################################################################
--  2. FLUXOS  (4 por estabelecimento = 52 linhas, TODAS pausadas)
-- ###########################################################################
--  Um cursor por CNPJ e TIPO, porque os servicos tem sequencias de NSU
--  INDEPENDENTES para o mesmo CNPJ:
--
--    NFE   NFeDistribuicaoDFe   SEFAZ (SOAP)  - cobre NF-e (55) e NFC-e (65)
--    CTE   CTeDistribuicaoDFe   SEFAZ (SOAP)
--    MDFE  MDFeDistribuicaoDFe  SEFAZ (SOAP)
--    NFSE  GET /DFe/{NSU}       ADN Nacional (REST + mTLS)
--
--  NFC-e NAO ganha fluxo proprio: criar um faria duas leituras concorrentes da
--  MESMA sequencia, que e exatamente como se toma 656.
--
--  nro_ultimo_nsu comeca em 0, e isso e deliberado. NAO copiar cursor de
--  sistema antigo: os valores de dpc_conta_nsu_consultado sao de 2019 e apontam
--  para faixa que a SEFAZ ja expurgou (retencao de 90 dias). Herda-los seria
--  importar o problema. Comecando em 0, a fonte entrega o que ainda esta na
--  janela.
--
--  Para o ADN e diferente e vale saber antes: ele NAO tem janela de 90 dias.
--  Guarda historico - a primeira drenagem de um CNPJ trouxe nota de out/2024 em
--  homologacao. A carga inicial de NFSE pode trazer anos de documento, entao
--  drene com orcamento apertado e supervisao.
declare
  qtd_ins number := 0;
begin
  for e in (select cod_dfe_empresa, nro_empresa
              from poseidon.dpc_dfe_empresa
             order by nro_empresa) loop
    -- Lista por UNION ALL, e nao por table(sys.odcivarchar2list(...)): aquele
    -- tipo depende de grant de execucao em SYS, e uma instalacao nao deve
    -- parar por privilegio que ninguem lembrou de conceder.
    for t in (select 'NFE'  as tipo from dual union all
              select 'CTE'         from dual union all
              select 'MDFE'        from dual union all
              select 'NFSE'        from dual) loop

      insert into poseidon.dpc_dfe_cursor
        (cod_dfe_empresa, cod_tipo_dfe, status_sincronismo,
         nro_ultimo_nsu, nro_maximo_nsu,
         qtd_min_entre_consulta, qtd_min_em_dia,
         dsc_ultimo_motivo, created_at, created_by)
      select e.cod_dfe_empresa, t.tipo, 'P',
             0, 0,
             3, 60,
             'fluxo criado pausado: ativar exige a janela de corte da Qive',
             sysdate, 'CARGA INICIAL'
        from dual
       where not exists (select 1 from poseidon.dpc_dfe_cursor c
                          where c.cod_dfe_empresa = e.cod_dfe_empresa
                            and c.cod_tipo_dfe    = t.tipo);

      qtd_ins := qtd_ins + sql%rowcount;
    end loop;
  end loop;

  dbms_output.put_line('fluxos criados nesta execucao: ' || qtd_ins);
end;

commit;


-- ###########################################################################
--  3. CONFERENCIA
-- ###########################################################################
--  ESPERADO: 13 estabelecimentos, 52 fluxos, TODOS com status P.
select (select count(*) from poseidon.dpc_dfe_empresa)                            as estabelecimentos,
       (select count(*) from poseidon.dpc_dfe_cursor)                             as fluxos,
       (select count(*) from poseidon.dpc_dfe_cursor where status_sincronismo = 'P') as pausados,
       (select count(*) from poseidon.dpc_dfe_cursor where status_sincronismo <> 'P') as nao_pausados
  from dual;

--  Fluxos por tipo: 13 de cada.
select cod_tipo_dfe, status_sincronismo, count(*) as qtd
  from poseidon.dpc_dfe_cursor
 group by cod_tipo_dfe, status_sincronismo
 order by cod_tipo_dfe;

--  Quais estabelecimentos tem certificado utilizavel HOJE. Nenhuma alteracao:
--  so leitura, para dimensionar quanto do motor tem como operar.
select e.nro_empresa, e.num_cnpj, e.sig_uf,
       case when cd.cod_empresa is null then 'SEM CERTIFICADO CADASTRADO'
            when cd.status <> 1        then 'CERTIFICADO INATIVO'
            else 'cadastrado' end as situacao_certificado,
       cd.consultar_distri_dfe
  from poseidon.dpc_dfe_empresa e
  left join poseidon.dpc_conta_certif_digital_emp cd
         on cd.cod_empresa = e.nro_empresa
 order by e.nro_empresa;

--  ==========================================================================
--   COMO ATIVAR UM FLUXO, quando a janela da Qive existir
--  ==========================================================================
--  NAO por UPDATE direto: use o command, que aplica o cooldown de 3 min antes da
--  primeira consulta. Reposicionar e consultar na sequencia reenvia a MESMA
--  requisicao e e assim que se toma 656.
--
--      dfe:ingerir --empresa=30 --tipo=NFE --reposicionar-cursor=0 --confirmar
--
--  E confira antes, sem consumir cota nenhuma:
--
--      dfe:ingerir --dry-run
-- ============================================================================
