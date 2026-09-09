-- ============================================================================
--  MODULO DFe - EMPRESA 30, FILIAL MS (ARQUIVO 02_01)
-- ============================================================================
--  CNPJ 66.471.517/0030-01. Raiz 66471517, a mesma da matriz.
--
--  Rodar DEPOIS de todo o bloco 01 (01_01, 01_02, 01_03 e a conferencia do
--  01_04), como
--  POSEIDON, arquivo inteiro com Alt+X. Reexecutavel: cada linha e criada so se
--  ainda nao existir.
--
--  LIGUE O DBMS_OUTPUT (aba Output do editor de SQL): a secao 3 avisa por ali
--  se nao teve de onde copiar o certificado, e esse aviso e o unico sinal.
--
--  ==========================================================================
--   POR QUE ESTA EMPRESA TEM ARQUIVO PROPRIO
--  ==========================================================================
--  Nao e caso especial de negocio: e o unico estabelecimento que precisa de
--  algo FORA das tabelas do modulo. O certificado dela mora em
--  poseidon.dpc_conta_certif_digital_emp, que e tabela do ERP.
--
--  Isso tem tres consequencias, e as tres justificam a separacao:
--
--   1. o 01_02 nao pode criar os fluxos dela, senao criaria fluxo para uma
--      empresa que ainda nao tem como capturar nada;
--   2. o 99_rollback derruba as 13 tabelas dpc_dfe_* e NAO alcanca o
--      certificado - por isso existe o 02_99_rollback_empresa_30_dbeaver.sql;
--   3. e a empresa em que a validacao em producao acontece, junto com um
--      cadastro de teste: sao os dois unicos CNPJs que a Qive nao atende
--      (confirmado em 20/08/2026). Mexer nela nao e mexer no acervo geral.
--
--  ==========================================================================
--   O MARCADOR 'CADASTRO DFE'
--  ==========================================================================
--  Tudo que este arquivo grava leva created_by = 'CADASTRO DFE', e o
--  98_rollback apaga POR ESSE MARCADOR. Os dois tem de concordar.
--
--  Ate 09/09/2026 nao concordavam: a empresa 30 nascia no 02_carga_inicial com
--  'CARGA INICIAL', e o rollback dela filtrava por 'CADASTRO DFE' - ou seja,
--  nao apagava nada e a conferencia acusava contagem diferente de zero sem
--  explicar por que. Com a empresa nascendo em UM lugar so, o filtro sempre
--  casa.
--
--  ==========================================================================
--   NASCE PAUSADA, E ISSO E DELIBERADO
--  ==========================================================================
--  Esta empresa usa o e-CNPJ da MATRIZ, compartilhado com as empresas 1, 3 e 8
--  (e com a Qive). O consumo da SEFAZ e contabilizado por CERTIFICADO e por IP,
--  nao por CNPJ - medido em campo: a empresa 8 tomou cStat 656 na PRIMEIRA
--  consulta dela, minutos depois do bloqueio da matriz.
--
--  Consequencia: um 656 aqui bloqueia o certificado do GRUPO por 1 hora.
--  Ativar exige saber a data e hora em que a Qive para de consultar este CNPJ.
--  Ver a secao 5.
-- ============================================================================


-- ###########################################################################
--  1. IDENTIDADE FISCAL
-- ###########################################################################
--  Os valores sao literais de proposito, e nao lidos do ERP: depois do 39b172d
--  esta tabela E a fonte unica de identidade do modulo.
--
--  cod_dfe_empresa nao vai no insert: a trigger DPCT_DFE_EMPRESA preenche pela
--  sequence.
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


-- ###########################################################################
--  2. OS 4 FLUXOS, TODOS PAUSADOS
-- ###########################################################################
--  Um cursor por TIPO, porque os servicos tem sequencias de NSU INDEPENDENTES
--  para o mesmo CNPJ: o NSU 100 da NF-e e o NSU 100 do CT-e sao documentos
--  diferentes.
--
--  A lista de tipos vai por UNION ALL, e nao por table(sys.odcivarchar2list(...)):
--  aquele tipo depende de grant de execucao em SYS, e um cadastro nao deve
--  parar por privilegio que ninguem lembrou de conceder.
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


-- ###########################################################################
--  3. CERTIFICADO  (tabela do ERP, nao do modulo)
-- ###########################################################################
--  NAO precisa de arquivo nem de senha: o e-CNPJ A1 da matriz serve para todas
--  as filiais de mesma raiz. Este bloco COPIA a linha da empresa 1, que e a que
--  tem o certificado renovado e valido (ate 20/10/2026).
--
--  Copiar em vez de reinserir tem duas vantagens:
--    - o base64 do PFX vai identico, sem risco de truncamento
--    - senha_certificado ja esta no formato da dpcf_convertesenhas; copiar o
--      valor pronto evita reconverter e errar
--
--  cod_certi_digital nao vai no insert: a trigger DPCT_CONTA_CERTIF_DIGITAL_EMP
--  preenche pela sequence.
--
--  ==========================================================================
--   POR QUE ESTE BLOCO E PL/SQL, E NAO UM INSERT SOLTO
--  ==========================================================================
--  Duas armadilhas silenciosas do insert original:
--
--   1. se a empresa 1 nao tiver linha ATIVA, o INSERT ... SELECT insere ZERO
--      linhas e nao da erro nenhum. A empresa 30 fica sem certificado, o motor
--      nao captura nada por ela, e ninguem soube. Aqui isso vira aviso.
--   2. se a empresa 1 tiver MAIS DE UMA linha ativa, o NOT EXISTS e avaliado
--      contra o estado do inicio do statement e as duas seriam copiadas - duas
--      linhas de certificado para a 30. O rownum = 1 fecha isso.
declare
  qtd_origem number;
  qtd_ins    number;
begin
  select count(*) into qtd_origem
    from poseidon.dpc_conta_certif_digital_emp
   where cod_empresa = 1
     and status = 1;

  if qtd_origem = 0 then
    dbms_output.put_line('AVISO: a empresa 1 nao tem certificado ATIVO - nada foi copiado.');
    dbms_output.put_line('       A empresa 30 fica SEM certificado; o dfe:monitorar vai');
    dbms_output.put_line('       acusar "SEM CERT" e nenhum fluxo dela tem como capturar.');
  else
    insert into poseidon.dpc_conta_certif_digital_emp
      (cod_empresa, emitir_cte, consultar_distri_dfe, nome_arquivo,
       certificado, tamanho, senha_certificado, status, created_at, created_by)
    select 30,
           0,
           1,                   -- consultar_distri_dfe: participa da captura
           c.nome_arquivo,
           c.certificado,
           c.tamanho,
           c.senha_certificado, -- valor JA convertido, copiado como esta
           1,
           sysdate,
           'CADASTRO DFE'
      from poseidon.dpc_conta_certif_digital_emp c
     where c.cod_empresa = 1
       and c.status = 1
       and rownum = 1           -- no maximo UMA linha, ainda que a 1 tenha duas
       and not exists (select 1
                         from poseidon.dpc_conta_certif_digital_emp
                        where cod_empresa = 30
                          and status = 1);

    qtd_ins := sql%rowcount;

    if qtd_ins = 0 then
      dbms_output.put_line('certificado da empresa 30 ja existia - nada a fazer.');
    else
      dbms_output.put_line('certificado copiado da empresa 1 para a 30.');
    end if;
  end if;
end;

commit;


-- ###########################################################################
--  4. CONFERENCIA
-- ###########################################################################

--  4a. Identidade. ESPERADO: 1 linha, tam_cnpj = 14, marcador CADASTRO DFE.
select nro_empresa,
       num_cnpj,
       length(num_cnpj) as tam_cnpj,
       sig_uf,
       num_inscr_estadual,
       status_manifestar,
       created_by
  from poseidon.dpc_dfe_empresa
 where num_cnpj = '66471517003001';

--  4b. Fluxos. ESPERADO: 4 linhas - NFE, CTE, MDFE, NFSE - todas P e com 0/0.
select c.cod_tipo_dfe,
       c.status_sincronismo,
       c.nro_ultimo_nsu,
       c.nro_maximo_nsu,
       c.qtd_min_entre_consulta,
       c.qtd_min_em_dia,
       c.created_by
  from poseidon.dpc_dfe_cursor  c
  join poseidon.dpc_dfe_empresa e on e.cod_dfe_empresa = c.cod_dfe_empresa
 where e.nro_empresa = 30
 order by c.cod_tipo_dfe;

--  4c. Certificado. ESPERADO: 2 linhas, com tamanho e senha_lida IDENTICOS.
--      Se vier 1 linha so, a copia nao aconteceu - releia o Output da secao 3.
select cod_certi_digital,
       cod_empresa,
       tamanho,
       dbms_lob.getlength(certificado) as tam_base64,
       consinco.dpcf_desconvertesenhas(senha_certificado) as senha_lida,
       consultar_distri_dfe,
       status,
       created_by
  from poseidon.dpc_conta_certif_digital_emp
 where cod_empresa in (1, 30)
   and status = 1
 order by cod_empresa;

--  4d. Panorama: onde a 30 entra no conjunto. Ativos primeiro.
select e.nro_empresa,
       e.num_cnpj,
       e.sig_uf,
       count(c.cod_dfe_cursor)                                             as fluxos,
       sum(case when c.status_sincronismo = 'A' then 1 else 0 end)          as ativos,
       sum(case when c.status_sincronismo = 'P' then 1 else 0 end)          as pausados
  from poseidon.dpc_dfe_empresa e
  left join poseidon.dpc_dfe_cursor c on c.cod_dfe_empresa = e.cod_dfe_empresa
 group by e.nro_empresa, e.num_cnpj, e.sig_uf
 order by 5 desc, e.nro_empresa;


-- ###########################################################################
--  5. ATIVAR  -  somente depois da decisao sobre a Qive
-- ###########################################################################
--  NAO por UPDATE direto: use o command, que aplica o cooldown de 3 min antes
--  da primeira consulta. Reposicionar e consultar na sequencia reenvia a MESMA
--  requisicao, e e assim que se toma 656.
--
--      dfe:ingerir --empresa=30 --tipo=NFE --reposicionar-cursor=0 --confirmar
--
--  E confira antes, sem consumir cota nenhuma:
--
--      dfe:ingerir --dry-run --empresa=30
--
--  Para desfazer SO esta empresa, inclusive o certificado:
--
--      02_99_rollback_empresa_30_dbeaver.sql
-- ============================================================================
