-- ============================================================================
--  PRODUCAO - P1_02 - PARAMETROS dfe_* DO MODULO DFe
-- ============================================================================
--
--  Banco: Oracle PRODUCAO (dpcdb1/dpcdb2) Tabela: poseidon.dpc_parametro
--  Gerado em 07/10/2026 a partir dos 11 parametros dfe_* REAIS da homolog (valor e
--  texto copiados, nao digitados).
--
--  ==========================================================================
--   POR QUE ESTE ARQUIVO, E NAO O 01_03
--  ==========================================================================
--  O 01_03 carrega 6 parametros, mas inclui dfe_conexao_erp apontando para
--  'oracle' - a conexao de PRODUCAO, certa para a homolog. Na producao o ERP e a
--  propria base: sem esse parametro o codigo usa a conexao corrente, que e o
--  correto. Este arquivo traz tudo que a homolog tem em uso, SEM essa linha.
--
--  dfe_conexao_erp NAO entra. Nao crie na producao.
--
--  ==========================================================================
--   O QUE FAZ
--  ==========================================================================
--  So INSERE o que ainda nao existe (por nome, sem diferenciar maiuscula): pode
--  rodar depois do 04_01, que ja cria 4 deles com o mesmo valor, e pode ser
--  repetido. NAO atualiza valor existente: ajuste de vazao e feito pelo VALOR,
--  sem deploy, e este arquivo nao pode desfazer isso.
--
--  dpc_parametro e compartilhada por todo o ecossistema (111 linhas na homolog):
--  o arquivo toca SOMENTE linhas dfe_*.
--
--  Conectado como POSEIDON na PRODUCAO. Secao por secao (Ctrl+Enter).
-- ============================================================================


-- ============================================================================
--  SECAO 0 - FOTO ANTES (esperado na producao nova: nenhuma linha, ou so as do 04_01)
-- ============================================================================

select nome, valor from poseidon.dpc_parametro where lower(nome) like 'dfe%' order by nome;


-- ============================================================================
--  SECAO 1 - INSERE
-- ============================================================================

insert into poseidon.dpc_parametro (nome, valor, explicacao)
select 'dfe_manifest_fila_max_ciclo', '200',
       'Notas que a fila de manifestacao em massa envia por ciclo (a cada 10 min). Faixa 1-2000. Subir aos poucos medindo os 656.'
  from dual
 where not exists (select 1 from poseidon.dpc_parametro where lower(nome) = 'dfe_manifest_fila_max_ciclo');

insert into poseidon.dpc_parametro (nome, valor, explicacao)
select 'dfe_manifest_fila_max_pedido', '5000',
       'Maximo de chaves em um unico pedido de manifestacao em massa. Faixa 1-20000.'
  from dual
 where not exists (select 1 from poseidon.dpc_parametro where lower(nome) = 'dfe_manifest_fila_max_pedido');

insert into poseidon.dpc_parametro (nome, valor, explicacao)
select 'dfe_manifest_max_ciclo', '100',
       'Modulo DFe (ApiNFE) - maximo de eventos de manifestacao por execucao do dfe:manifestar. Orcamento do ciclo, equivalente ao dfe_max_consultas da captura. Manifestacao e ato fiscal irreversivel: o teto '
    || 'existe para que um defeito na fila de candidatas nao vire mil protocolos definitivos antes de alguem perceber. Faixa aceita: 1 a 2000.'
  from dual
 where not exists (select 1 from poseidon.dpc_parametro where lower(nome) = 'dfe_manifest_max_ciclo');

insert into poseidon.dpc_parametro (nome, valor, explicacao)
select 'dfe_manifest_max_lote', '20',
       'Modulo DFe (ApiNFE) - maximo de eventos de manifestacao por lote enviado ao NFeRecepcaoEvento. O teto 20 e da NT e a propria sped-nfe recusa acima disso (RuntimeException em sefazManifestaLote). Envia'
    || 'r em lote em vez de unitario troca 20 requisicoes por 1, o que importa porque a manifestacao usa o mesmo certificado, CNPJ e IP da captura. Faixa aceita: 1 a 20.'
  from dual
 where not exists (select 1 from poseidon.dpc_parametro where lower(nome) = 'dfe_manifest_max_lote');

insert into poseidon.dpc_parametro (nome, valor, explicacao)
select 'dfe_manifest_pausa_seg', '5',
       'Modulo DFe (ApiNFE) - pausa em segundos entre lotes de manifestacao. Prudencia propria, nao exigencia da NT. Antes da Fase 1 o dfe:manifestar nao tinha pausa nenhuma e mandava os eventos em rajada. Fa'
    || 'ixa aceita: 0 a 600.'
  from dual
 where not exists (select 1 from poseidon.dpc_parametro where lower(nome) = 'dfe_manifest_pausa_seg');

insert into poseidon.dpc_parametro (nome, valor, explicacao)
select 'dfe_max_bloqueios_cnpj', '6',
       'Modulo DFe (ApiNFE) - teto de bloqueios por consumo indevido (cStat 656) em 24h de UM CNPJ. Ao atingir, aquele CNPJ fica de fora dos ciclos ate os bloqueios envelhecerem; os demais seguem normalmente.'
    || ' Age ANTES do dfe_max_bloqueios_dia, que virou ultima barreira para defeito sistemico. Criado em 14/09/2026 depois de um quase-acidente: com a espera do 656 ja por CNPJ, a empresa 30 sozinha fez 8 blo'
    || 'queios em 14 execucoes numa noite, capturando ZERO documento, e levou o contador global a 9 de 10 - o decimo teria parado a captura da empresa 29, que na mesma noite fez 15 execucoes sem um unico bloq'
    || 'ueio. ESTA 6 porque a 30, ja com qtd_min_em_dia de 180 min, deve produzir cerca de 4 por dia: 6 deixa folga para o normal e pega a degradacao. ATENCAO: com N CNPJs ativos o global precisa ser maior qu'
    || 'e N x este valor, senao volta a parar tudo. Faixa aceita: 1 a 20.'
  from dual
 where not exists (select 1 from poseidon.dpc_parametro where lower(nome) = 'dfe_max_bloqueios_cnpj');

insert into poseidon.dpc_parametro (nome, valor, explicacao)
select 'dfe_max_bloqueios_dia', '20',
       'Modulo DFe (ApiNFE) - freio de emergencia: acima deste numero de bloqueios por consumo indevido (cStat 656) em 24h, o dfe:ingerir para de consultar a SEFAZ. NAO existe pela regra dos 50 bloqueios cons'
    || 'ecutivos: essa nao esta na NT 2014.002 v.1.40 - a palavra PERMANENTE nao aparece nas 18 paginas, e a unica fonte era pagina de provedor de 2018 sobre o servico de AUTORIZACAO, nao sobre o distDFe. Exi'
    || 'ste para conter DEFEITO NOSSO. O que a NT diz, e basta: consultar dentro do bloqueio ZERA o tempo e reinicia a hora. Em 28-31/08/2026 um bug de fuso fez o motor consultar de 15 em 15 min dentro dessa '
    || 'janela, todos os dias - e este freio e a unica protecao que NAO depende de aritmetica de tempo estar correta, porque so conta linhas em dpc_dfe_execucao. ESTA 20, e nao 10, desde 14/09/2026: com 4 CNP'
    || 'Js ativos e teto individual de 6, o individual permite ate 24 antes deste disparar - em 10 este voltaria a ser o que morde primeiro, anulando o freio por CNPJ. 20 e o MAXIMO que a faixa do codigo acei'
    || 'ta; com mais CNPJs a faixa precisa mudar, nao so o valor. NAO E MAIS O FREIO PRINCIPAL: quem age primeiro e o dfe_max_bloqueios_cnpj, que tira de campo so o CNPJ doente. Este sobrou para o defeito SIS'
    || 'TEMICO, que nenhum teto individual contem. ATENCAO ao calibrar: com N CNPJs ativos o teto individual permite ate N x aquele valor antes deste disparar - com 2 CNPJs sao 12, e este em 10 ainda morde pr'
    || 'imeiro. Lido tambem pela ApiDPC, na tela do Monitor DFe. Faixa aceita: 1 a 20.'
  from dual
 where not exists (select 1 from poseidon.dpc_parametro where lower(nome) = 'dfe_max_bloqueios_dia');

insert into poseidon.dpc_parametro (nome, valor, explicacao)
select 'dfe_max_bloqueios_manifest', '6',
       'Modulo DFe (ApiNFE) - freio da manifestacao: acima deste numero de rejeicoes 656 atribuidas ao envio de eventos em 24h, o dfe:manifestar para. Existe porque NAO ha medicao confirmando que o NFeRecepca'
    || 'oEvento tem cota separada do NFeDistribuicaoDFe - a afirmacao esta no codigo (DfeSefazRepository) sem nenhum experimento atras, ao contrario do resto do modulo. O teste de 21/09/2026 (10 Ciencias na e'
    || 'mpresa 29) nao produziu 656 algum, mas foram so 7 execucoes de captura depois, N baixo demais para concluir. Enquanto isso nao fechar, a manifestacao respeita tambem o cooldown da captura, via dpc_dfe'
    || '_cursor.dta_liberado_em. Espelha o dfe_max_bloqueios_cnpj. Faixa aceita: 1 a 20.'
  from dual
 where not exists (select 1 from poseidon.dpc_parametro where lower(nome) = 'dfe_max_bloqueios_manifest');

insert into poseidon.dpc_parametro (nome, valor, explicacao)
select 'dfe_max_consultas', '200',
       'Modulo DFe (ApiNFE) - orcamento de chamadas distNSU por execucao do dfe:ingerir, somando todos os fluxos. Ao esgotar, o ciclo encerra com resultado ORCAMENTO e o restante fica para a proxima execucao.'
    || ' Faixa aceita: 1 a 5000.'
  from dual
 where not exists (select 1 from poseidon.dpc_parametro where lower(nome) = 'dfe_max_consultas');

insert into poseidon.dpc_parametro (nome, valor, explicacao)
select 'dfe_min_backoff_656', '60',
       'Modulo DFe (ApiNFE) - minutos de espera aplicados aos fluxos do CNPJ bloqueado, dentro do dominio afetado, quando a fonte devolve consumo indevido (cStat 656 na SEFAZ). Ate 13/09/2026 a espera ia para'
    || ' TODOS os fluxos do dominio - 42, porque as 14 empresas dividem a mesma raiz de CNPJ - e foi estreitada quando ficou provado que a cota e do CNPJ de 14 digitos: em 12/09 a empresa 29 consultou DENTRO '
    || 'da janela de bloqueio da empresa 30, no mesmo certificado, e recebeu cStat 137. O PISO DE 60 E EXIGENCIA DA NT 2014.002, nao preferencia: consultar antes de vencer a hora ZERA o tempo e reinicia a con'
    || 'tagem, e o fluxo nunca sai do laco sozinho. Os outros TIPOS do mesmo CNPJ pausam junto - em 01/09/2026 o CT-e e o NF-e da mesma empresa 30, a 30 segundos, deram 656. Valor abaixo de 60 e recusado pelo'
    || ' codigo e substituido por 60. Faixa: 60 a 1440.'
  from dual
 where not exists (select 1 from poseidon.dpc_parametro where lower(nome) = 'dfe_min_backoff_656');

insert into poseidon.dpc_parametro (nome, valor, explicacao)
select 'dfe_pausa_seg', '30',
       'Modulo DFe (ApiNFE) - segundos entre chamadas a SEFAZ durante a drenagem, e entre fluxos. E PRUDENCIA PROPRIA, nao limite publicado: a NT 2014.002 nao especifica intervalo minimo quando ha documentos.'
    || ' Reduzir somente apos medir, com poucas chamadas e supervisao. Faixa aceita: 0 a 600.'
  from dual
 where not exists (select 1 from poseidon.dpc_parametro where lower(nome) = 'dfe_pausa_seg');

commit;


-- ============================================================================
--  SECAO 2 - CONFERENCIA
-- ============================================================================
--  Esperado: 11 linhas, com estes valores:
--    dfe_manifest_fila_max_ciclo        200
--    dfe_manifest_fila_max_pedido       5000
--    dfe_manifest_max_ciclo             100
--    dfe_manifest_max_lote              20
--    dfe_manifest_pausa_seg             5
--    dfe_max_bloqueios_cnpj             6
--    dfe_max_bloqueios_dia              20
--    dfe_max_bloqueios_manifest         6
--    dfe_max_consultas                  200
--    dfe_min_backoff_656                60
--    dfe_pausa_seg                      30
--  E nenhuma linha dfe_conexao_erp.

select nome, valor from poseidon.dpc_parametro where lower(nome) like 'dfe%' order by nome;
