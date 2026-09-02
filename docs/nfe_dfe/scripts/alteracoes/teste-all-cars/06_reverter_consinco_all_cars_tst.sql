-- ============================================================================
--  06 - REVERTER SO O QUE FOI CRIADO NA CONSINCO PARA A ALL CARS
-- ============================================================================
--  SOMENTE HOMOLOGACAO (tst).
--
--  NAO CONFUNDIR COM O 99_rollback_tst.sql.
--
--    99_rollback  -> apaga TUDO: certificado, dpc_dfe_empresa e todo o acervo
--                    capturado (as 8 NF-e e as 15 NFS-e que hoje sao a massa de
--                    validacao do motor). Use quando o teste terminar de vez.
--
--    ESTE (06)    -> apaga SO as duas linhas da CONSINCO. O certificado fica, o
--                    cadastro em poseidon.dpc_dfe_empresa fica, os documentos
--                    ficam, e a ALL CARS continua operando normalmente.
--
--  ----------------------------------------------------------------------------
--   POR QUE ESSAS DUAS LINHAS FICARAM DESNECESSARIAS
--  ----------------------------------------------------------------------------
--  Elas nunca foram dado de negocio: existiam para contornar duas dependencias
--  que o motor tinha da consinco.
--
--    consinco.ge_empresa  -> DfeIngerir montava o configJson do sped lendo
--                            GeEmpresa::showAll, que faz INNER JOIN com
--                            ge_cidade. Sem a linha (e sem SEQCIDADE), o erro era
--                            "empresa 900 nao encontrada".
--
--    consinco.ge_pessoa   -> a coluna CNPJ vinha de consinco.montacpfcnpj, que
--                            NAO e formatador: consulta ge_pessoa. Sem a pessoa,
--                            NO_DATA_FOUND dentro de function chamada de SQL
--                            devolve NULL em silencio, e o sped rejeitava o CNPJ.
--
--  O commit 39b172d desacoplou o motor da consinco: a identidade fiscal (razao
--  social, UF, inscricao estadual, CNPJ) passou a vir de
--  poseidon.dpc_dfe_empresa. Sumiu a dependencia, sumiram os dois contornos.
--
--  ----------------------------------------------------------------------------
--   A REVERSAO DE ge_pessoa E LIMPA - MEDIDO, NAO INFERIDO
--  ----------------------------------------------------------------------------
--  Versao anterior deste comentario afirmava que a reversao "nao e 100% limpa",
--  porque ~10 triggers de log e replicacao teriam gravado em outras tabelas no
--  insert. Aquilo foi INFERIDO pelo nome das triggers. Medido em 20/08/2026, em
--  tst, para a pessoa de teste (seqpessoa 312896), o quadro e outro:
--
--  1. Das 11 triggers de ge_pessoa, a maioria NAO disparou no nosso insert:
--     CTT_DESCENTIDADE, FIT_DESCCONTAENT, TBD_ABA_DESCPARAMETROENTIDADE e
--     TAU_GE_PESSOA_EFDLOG_REG0175 sao **UPDATE-only**. A ultima era a mais
--     preocupante (log fiscal EFD/SPED) e simplesmente nunca rodou.
--
--  2. Duas triggers que a versao anterior citava - TAIU_GE_PESSOACADASTROLOG e
--     TAD_RF_REINF_R2040_PESSOA - **nao existem** nesta tabela. Foram listadas
--     por suposicao.
--
--  3. O residuo real do insert e UMA linha, em consinco.ge_pessoacadastro
--     (gravada por TAIUD_GE_PESSOA). GE_PESSOAVERSAO ficou com zero linha para
--     esta pessoa, e GEX_DADOSTEMPORARIOS esta vazia na tabela toda.
--
--  4. Essa unica linha SOME junto: a FK SYS_C00172785
--     (GE_PESSOACADASTRO.SEQPESSOA -> GE_PESSOA.SEQPESSOA) e **ON DELETE
--     CASCADE**. Nao precisa de delete manual.
--
--  5. A trigger de delete (TBD_GE_PESSOA, BEFORE DELETE) nao suja: ela LIMPA seis
--     tabelas de log por SEQPESSOA (GE_LOGCONSPESSOA, GE_LOGATIVIDADENF,
--     GE_LOGATIVIDADETIT, GE_LOGATIVIDADEOR, GE_LOGATIVIDADETRANSF,
--     GE_LOGATIVIDADEOUTROS). O unico registro que ela ACRESCENTA e em
--     GE_LOGEXCLUIPESSOA, e sob condicao `IF :OLD.FISICAJURIDICA = 'F'`. A ALL
--     CARS e 'J', entao nem isso e gravado.
--
--  Conclusao: a reversao e limpa. Nao ha pressa criada por acumulo de log - a
--  razao para reverter e simplesmente que as duas linhas nao servem mais.
--
--  UM RISCO QUE PERMANECE, e nao foi possivel descartar por completo: 148 FKs
--  apontam para GE_PESSOA com delete_rule NO ACTION (contra 20 em CASCADE).
--  Qualquer uma delas com linha para a pessoa 312896 bloquearia o delete. Varrer
--  as 148 excedeu o tempo de consulta, e a pessoa nunca foi usada em movimento -
--  foi criada em 10/08/2026 so para a function montacpfcnpj achar o CNPJ. Se
--  ainda assim vier **ORA-02292**, a propria mensagem nomeia a constraint: e por
--  ela que se descobre o que sobrou, e o rollback e simplesmente nao commitar.
--
--  ----------------------------------------------------------------------------
--   O QUE ESTE SCRIPT **NAO** QUEBRA - verificado no codigo, nao presumido
--  ----------------------------------------------------------------------------
--  O motor le o PFX por CertificadoDigitalRepository::buscaConteudoCertificado,
--  e essa consulta NAO faz join com ge_empresa: ela toca apenas
--  dpc_conta_certif_digital_emp mais a function consinco.dpcf_desconvertesenhas.
--  E o unico caminho de certificado do modulo (DfeIngerir, linha do certRepo) e
--  o dfe:monitorar usa o mesmo metodo.
--
--  Existe um segundo caminho - DpcContaCertifDigitalEmp::showAll - que faz INNER
--  JOIN com ge_empresa. Depois deste script, a ALL CARS deixa de aparecer nas
--  telas que usam esse metodo. Nenhuma delas e do modulo DFe, e a empresa 900 e
--  cadastro de teste, entao a perda e aceitavel. Registrado para nao virar
--  surpresa.
-- ============================================================================

-- ============================================================================
--  EXECUTADO EM 20/08/2026 - RESULTADO PARCIAL, E O MOTIVO NAO E ESTE SCRIPT
-- ============================================================================
--  consinco.ge_empresa (900)  -> APAGADA com sucesso
--  consinco.ge_pessoa         -> BLOQUEADA, e nao por FK:
--
--      ORA-01502: index 'CONSINCO.XPKMFL_DOCTOFISCAL' is in unusable state
--
--  Diagnostico feito rodando o delete dentro de transacao e dando ROLLBACK, so
--  para obter a mensagem:
--
--   - os 25 indices de consinco.MFL_DOCTOFISCAL estao UNUSABLE. Nao alguns: os
--     25, que e o total da tabela. Assinatura de ALTER TABLE MOVE ou carga
--     direct-path sem rebuild de indice.
--   - tres FKs apontam de MFL_DOCTOFISCAL para GE_PESSOA (SEQPESSOA, SEQPAGADOR,
--     SEQTRANSPORTADOR), todas NO ACTION. Para apagar a pessoa, o Oracle precisa
--     VERIFICAR que nao ha documento fiscal referenciando - e a verificacao usa
--     um indice que esta inutilizavel. Nao ha como pular indice unico nessa
--     checagem, dai o ORA-01502.
--   - a pessoa de teste tem ZERO linhas em MFL_DOCTOFISCAL (contado com hint de
--     full scan). O delete e logicamente valido: esta barrado por infraestrutura.
--   - PRODUCAO esta sa: os mesmos 25 indices estao VALID e o schema CONSINCO
--     inteiro tem zero indice inutilizavel. E problema exclusivo de homologacao.
--
--  O QUE FAZER: rodar 07_rebuild_indices_mfl_doctofiscal_tst.sql (tarefa de DBA)
--  e depois reexecutar a secao 3 deste script. Nao ha pressa - a linha remanescente
--  e inofensiva, porque o motor nao le mais a consinco para identidade fiscal.
--
--  ALCANCE MAIOR QUE ESTA REVERSAO: enquanto os indices estiverem UNUSABLE,
--  QUALQUER insert/update/delete em consinco.MFL_DOCTOFISCAL falha em
--  homologacao. Vale avisar quem testa modulo fiscal por lá.
-- ============================================================================

-- ---------------------------------------------------------------------------
--  1. ANTES: o que existe hoje
-- ---------------------------------------------------------------------------
select 'ANTES' as momento,
       (select count(*) from consinco.ge_empresa
         where nroempresa = 900)                                as ge_empresa,
       (select count(*) from consinco.ge_pessoa
         where nrocgccpf = '456944070001' and digcgccpf = 2)    as ge_pessoa,
       -- estes DEVEM continuar iguais depois. Sao a garantia de que o script
       -- mexeu somente na consinco.
       (select count(*) from poseidon.dpc_conta_certif_digital_emp
         where cod_empresa = 900)                               as certificado,
       (select count(*) from poseidon.dpc_dfe_empresa
         where nro_empresa = 900)                               as dfe_empresa,
       (select count(*) from poseidon.dpc_dfe_documento d
          join poseidon.dpc_dfe_empresa e
            on e.cod_dfe_empresa = d.cod_dfe_empresa
         where e.nro_empresa = 900)                             as documentos,
       (select count(*) from poseidon.dpc_dfe_nfse n
          join poseidon.dpc_dfe_empresa e
            on e.cod_dfe_empresa = n.cod_dfe_empresa
         where e.nro_empresa = 900)                             as nfse
  from dual;

-- ---------------------------------------------------------------------------
--  2. Confirme que a linha e a DO TESTE antes de apagar
-- ---------------------------------------------------------------------------
--  ATENCAO A ASSIMETRIA DAS DUAS TABELAS, que ja gerou erro neste script:
--
--    consinco.ge_pessoa   tem USUINCLUSAO e DTAINCLUSAO  -> da para travar por usuario
--    consinco.ge_empresa  NAO tem nenhuma das duas       -> so USUALTERACAO/DTAALTERACAO
--
--  Por isso a trava de ge_empresa e o proprio CNPJ, nao o usuario: garante que o
--  delete so alcanca a linha da ALL CARS, ainda que alguem venha a usar o numero
--  900 para outra coisa. Se a consulta abaixo NAO devolver o CNPJ 456944070001,
--  PARE: a linha 900 nao e mais a do teste.
select nroempresa, razaosocial, fantasia, nrocgc, digcgc, seqcidade,
       usualteracao, dtaalteracao
  from consinco.ge_empresa
 where nroempresa = 900;

select seqpessoa, nrocgccpf, digcgccpf, nomerazao,
       usuinclusao, dtainclusao
  from consinco.ge_pessoa
 where nrocgccpf = '456944070001'
   and digcgccpf = 2;

-- ---------------------------------------------------------------------------
--  3. Reversao
-- ---------------------------------------------------------------------------
--  Ordem: empresa primeiro. ge_empresa referencia a pessoa pelo par
--  (nrocgc, digcgc), nao por FK declarada, mas apagar a pessoa antes deixaria a
--  empresa apontando para cadastro inexistente durante a transacao.
delete from consinco.ge_empresa
 where nroempresa = 900
   and nrocgc     = '456944070001';   -- trava: so a linha da ALL CARS

delete from consinco.ge_pessoa
 where nrocgccpf   = '456944070001'
   and digcgccpf   = 2
   and usuinclusao = 'TESTE DFE';   -- mesma trava

commit;

-- ---------------------------------------------------------------------------
--  4. DEPOIS: as duas primeiras colunas viram 0, as quatro ultimas NAO mudam
-- ---------------------------------------------------------------------------
select 'DEPOIS' as momento,
       (select count(*) from consinco.ge_empresa
         where nroempresa = 900)                                as ge_empresa,      -- 0
       (select count(*) from consinco.ge_pessoa
         where nrocgccpf = '456944070001' and digcgccpf = 2)    as ge_pessoa,       -- 0
       (select count(*) from poseidon.dpc_conta_certif_digital_emp
         where cod_empresa = 900)                               as certificado,     -- inalterado
       (select count(*) from poseidon.dpc_dfe_empresa
         where nro_empresa = 900)                               as dfe_empresa,     -- inalterado
       (select count(*) from poseidon.dpc_dfe_documento d
          join poseidon.dpc_dfe_empresa e
            on e.cod_dfe_empresa = d.cod_dfe_empresa
         where e.nro_empresa = 900)                             as documentos,      -- inalterado
       (select count(*) from poseidon.dpc_dfe_nfse n
          join poseidon.dpc_dfe_empresa e
            on e.cod_dfe_empresa = n.cod_dfe_empresa
         where e.nro_empresa = 900)                             as nfse,            -- inalterado
       -- deve ser 0: a FK SYS_C00172785 e ON DELETE CASCADE, entao a linha
       -- satelite sai junto sem delete manual.
       (select count(*) from consinco.ge_pessoacadastro
         where seqpessoa = 312896)                              as cadastro_residual
  from dual;

-- ---------------------------------------------------------------------------
--  5. Prova real: o motor continua funcionando sem a consinco
-- ---------------------------------------------------------------------------
--  Rode no terminal, na pasta da ApiNFE. NAO consome cota (nao chama a SEFAZ nem
--  o ADN) e ja le o certificado do cofre:
--
--      dev.cmd dfe:ingerir --empresa=900 --dry-run
--
--  Esperado: os fluxos da 900 listados, com "certificado ok (valido ate
--  11/03/2027 17:34:00)". Se aparecer "empresa 900 nao encontrada", alguma
--  dependencia da consinco voltou ao motor - nesse caso reexecute o
--  01_ge_empresa_tst.sql e o 04_ge_pessoa_tst.sql e abra a investigacao.
--
--  E a normalizacao, que tambem nao fala com fonte externa:
--
--      dev.cmd dfe:normalizar --empresa=900 --status=C --limit=1 --dry-run
-- ============================================================================
