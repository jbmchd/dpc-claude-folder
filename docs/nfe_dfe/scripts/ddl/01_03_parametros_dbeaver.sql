-- ==========================================================================
--  MODULO DFe - PARAMETROS OPERACIONAIS (ARQUIVO 01_03)
-- ==========================================================================
--
--  Carrega 5 linhas em POSEIDON.DPC_PARAMETRO. Nao cria objeto: essa tabela ja
--  existe e e compartilhada pelo ecossistema (99 linhas de outros modulos).
--
--  Rodar DEPOIS do 01_01 e do 01_02, como POSEIDON, inteiro com Alt+X.
--  Reexecutavel:
--  cada insert e guardado por WHERE NOT EXISTS, e reexecutar NAO sobrescreve
--  valor que o operador tenha ajustado a mao.
--
--  ==========================================================================
--   ORDEM: ANTES DO DEPLOY DO CODIGO
--  ==========================================================================
--    01_03 antes do deploy    correto
--    deploy antes do 01_03    no intervalo o freio opera com 5 e o motor para
--
--  Rodar antes e seguro nos dois sentidos: codigo antigo nao le esta tabela,
--  entao as linhas ficam inertes ate o deploy.
--
--  ==========================================================================
--   POR QUE ISTO E UM PASSO SEPARADO
--  ==========================================================================
--  O 01_estrutura cria as 13 tabelas DO MODULO. DPC_PARAMETRO nao e uma delas
--  - e tabela global, de outro dono - entao o instalador nunca a incluiu. Isso
--  deixou um buraco: quem seguisse "base nova nao roda alteracoes" instalava
--  sem os parametros.
--
--  E NAO E INOFENSIVO. Sem estas linhas o motor cai nos defaults internos, e
--  dois deles MUDAM COMPORTAMENTO:
--
--    dfe_max_bloqueios_dia  volta a 5, fica abaixo do ruido normal do sistema,
--                           e o motor se recusa a consultar a SEFAZ - em
--                           silencio, sem erro em log nenhum;
--    dfe_conexao_erp        volta a "conexao corrente", e em homologacao isso
--                           faz a conciliacao ler um clone congelado e concluir
--                           que NENHUMA nota entrou no ERP - tambem em
--                           silencio, porque "nada encontrado" e resposta
--                           valida.
--
--  ==========================================================================
--   A TABELA NAO TEM PK NEM CHECK
--  ==========================================================================
--  Nada no banco impede duas linhas com o mesmo NOME, nem VALOR = 'abc' onde
--  se espera numero. Por isso:
--    - cada insert abaixo e guardado por WHERE NOT EXISTS (reexecutavel, nao
--      duplica);
--    - a validacao de tipo e faixa vive no codigo (DpcParametroRepository):
--      valor invalido e RECUSADO, cai no default conservador e gera aviso no
--      dfe:monitorar e no log. Nunca passa por valor bom.
--
--  Ao final ha um SELECT de conferencia. O COMMIT e explicito, no fim.
-- ==========================================================================


-- ============================================================================
--  OS 5 PARAMETROS
-- ============================================================================
--
--  Nao cria objeto nenhum. E carga de 5 linhas na tabela de parametros do
--  ecossistema, que ja existe. Rodar como POSEIDON.
--
--  POR QUE ISTO PRECISA RODAR
--  --------------------------
--  Ate agora os QUATRO PRIMEIROS vinham do .env de cada projeto (o quinto,
--  dfe_conexao_erp, nunca esteve la). O codigo novo le da tabela; sem estas
--  linhas ele cai nos defaults internos, e um deles MUDA O COMPORTAMENTO: o
--  freio de consumo indevido volta a 5 bloqueios/dia, que fica ABAIXO do ruido
--  normal do sistema (medido de 28 a 31/08/2026: exatamente 5 por dia, todos
--  os dias, sem defeito nenhum). O motor passaria a se travar sozinho todo
--  dia.
--
--  POR QUE SAIRAM DO .env
--  ----------------------
--  dfe_max_bloqueios_dia e lido por DOIS projetos - o freio na ApiNFE e a tela
--  do Monitor DFe na ApiDPC. Com o valor no .env de cada um eles divergiram
--  (10 na ApiNFE, 5 na ApiDPC) e a tela acusava freio acionado com o motor
--  operando normal. Um valor que dois projetos precisam ler nao pode viver em
--  dois arquivos.
--
--  A TABELA NAO TEM PK NEM CHECK
--  -----------------------------
--  Nada no banco impede duas linhas com o mesmo NOME, nem VALOR = 'abc' onde
--  se espera numero. Por isso:
--    - cada insert abaixo e guardado por WHERE NOT EXISTS (reexecutavel, nao
--      duplica);
--    - a validacao de tipo e faixa vive no codigo (DpcParametroRepository):
--      valor invalido e RECUSADO, cai no default conservador e gera aviso no
--      dfe:monitorar e no log. Nunca passa por valor bom.
--
--  COMO RODAR
--  ----------
--  DBeaver, como POSEIDON, script inteiro com Alt+X. Nao ha bloco PL/SQL.
--  Ao final ha um SELECT de conferencia. O COMMIT e explicito, no fim.
--
--  Aplicado em tst (homolog) em 02/09/2026.
-- ============================================================================


-- ---------------------------------------------------------------------------
-- dfe_max_bloqueios_dia = 20   (faixa 1 a 20 - no teto)
-- o freio; sem esta linha o codigo usa 5 e o motor se trava todo dia
-- ---------------------------------------------------------------------------
insert into poseidon.dpc_parametro (nome, valor, explicacao)
select 'dfe_max_bloqueios_dia', '20',
       'Modulo DFe (ApiNFE) - freio de emergencia: acima deste numero de bloqueios '
    || 'por consumo indevido (cStat 656) em 24h, o dfe:ingerir para de consultar a '
    || 'SEFAZ. NAO existe pela regra dos 50 bloqueios consecutivos: essa nao esta '
    || 'na NT 2014.002 v.1.40 - a palavra PERMANENTE nao aparece nas 18 paginas, e '
    || 'a unica fonte era pagina de provedor de 2018 sobre o servico de '
    || 'AUTORIZACAO, nao sobre o distDFe. Existe para conter DEFEITO NOSSO. O que '
    || 'a NT diz, e basta: consultar dentro do bloqueio ZERA o tempo e reinicia a '
    || 'hora. Em 28-31/08/2026 um bug de fuso fez o motor consultar de 15 em 15 '
    || 'min dentro dessa janela, todos os dias - e este freio e a unica protecao '
    || 'que NAO depende de aritmetica de tempo estar correta, porque so conta '
    || 'linhas em dpc_dfe_execucao. ESTA 20, e nao 10, desde 14/09/2026: com 4 '
    || 'CNPJs ativos e teto individual de 6, o individual permite ate 24 antes '
    || 'deste disparar - em 10 este voltaria a ser o que morde primeiro, '
    || 'anulando o freio por CNPJ. 20 e o MAXIMO que a faixa do codigo aceita; '
    || 'com mais CNPJs a faixa precisa mudar, nao so o valor. '
    || 'NAO E MAIS O FREIO PRINCIPAL: quem age '
    || 'primeiro e o dfe_max_bloqueios_cnpj, que tira de campo so o CNPJ doente. '
    || 'Este sobrou para o defeito SISTEMICO, que nenhum teto individual contem. '
    || 'ATENCAO ao calibrar: com N CNPJs ativos o teto individual permite ate N x '
    || 'aquele valor antes deste disparar - com 2 CNPJs sao 12, e este em 10 '
    || 'ainda morde primeiro. Lido tambem pela ApiDPC, na tela do Monitor DFe. '
    || 'Faixa aceita: 1 a 20.'
  from dual
 where not exists (select 1 from poseidon.dpc_parametro
                    where lower(nome) = 'dfe_max_bloqueios_dia');

-- ---------------------------------------------------------------------------
-- dfe_max_bloqueios_cnpj = 6   (faixa 1 a 20)
-- o freio que age PRIMEIRO; o de cima virou ultima barreira
-- ---------------------------------------------------------------------------
insert into poseidon.dpc_parametro (nome, valor, explicacao)
select 'dfe_max_bloqueios_cnpj', '6',
       'Modulo DFe (ApiNFE) - teto de bloqueios por consumo indevido (cStat 656) em '
    || '24h de UM CNPJ. Ao atingir, aquele CNPJ fica de fora dos ciclos ate os '
    || 'bloqueios envelhecerem; os demais seguem normalmente. Age ANTES do '
    || 'dfe_max_bloqueios_dia, que virou ultima barreira para defeito sistemico. '
    || 'Criado em 14/09/2026 depois de um quase-acidente: com a espera do 656 ja '
    || 'por CNPJ, a empresa 30 sozinha fez 8 bloqueios em 14 execucoes numa noite, '
    || 'capturando ZERO documento, e levou o contador global a 9 de 10 - o decimo '
    || 'teria parado a captura da empresa 29, que na mesma noite fez 15 execucoes '
    || 'sem um unico bloqueio. ESTA 6 porque a 30, ja com qtd_min_em_dia de 180 '
    || 'min, deve produzir cerca de 4 por dia: 6 deixa folga para o normal e pega '
    || 'a degradacao. ATENCAO: com N CNPJs ativos o global precisa ser maior que '
    || 'N x este valor, senao volta a parar tudo. Faixa aceita: 1 a 20.'
  from dual
 where not exists (select 1 from poseidon.dpc_parametro
                    where lower(nome) = 'dfe_max_bloqueios_cnpj');

-- ---------------------------------------------------------------------------
-- dfe_max_consultas = 200   (faixa 1 a 5000)
-- orcamento por execucao; o default do codigo ja e 200
-- ---------------------------------------------------------------------------
insert into poseidon.dpc_parametro (nome, valor, explicacao)
select 'dfe_max_consultas', '200',
       'Modulo DFe (ApiNFE) - orcamento de chamadas distNSU por execucao do '
    || 'dfe:ingerir, somando todos os fluxos. Ao esgotar, o ciclo encerra com '
    || 'resultado ORCAMENTO e o restante fica para a proxima execucao. Faixa '
    || 'aceita: 1 a 5000.'
  from dual
 where not exists (select 1 from poseidon.dpc_parametro
                    where lower(nome) = 'dfe_max_consultas');

-- ---------------------------------------------------------------------------
-- dfe_pausa_seg = 30   (faixa 0 a 600)
-- pausa entre chamadas; o default do codigo ja e 30
-- ---------------------------------------------------------------------------
insert into poseidon.dpc_parametro (nome, valor, explicacao)
select 'dfe_pausa_seg', '30',
       'Modulo DFe (ApiNFE) - segundos entre chamadas a SEFAZ durante a drenagem, '
    || 'e entre fluxos. E PRUDENCIA PROPRIA, nao limite publicado: a NT 2014.002 '
    || 'nao especifica intervalo minimo quando ha documentos. Reduzir somente apos '
    || 'medir, com poucas chamadas e supervisao. Faixa aceita: 0 a 600.'
  from dual
 where not exists (select 1 from poseidon.dpc_parametro
                    where lower(nome) = 'dfe_pausa_seg');

-- ---------------------------------------------------------------------------
-- dfe_min_backoff_656 = 60   (faixa 60 a 1440)
-- espera pos-bloqueio; o default do codigo ja e 60
-- ---------------------------------------------------------------------------
insert into poseidon.dpc_parametro (nome, valor, explicacao)
select 'dfe_min_backoff_656', '60',
       'Modulo DFe (ApiNFE) - minutos de espera aplicados aos fluxos do CNPJ '
    || 'bloqueado, dentro do dominio afetado, quando a fonte devolve consumo '
    || 'indevido (cStat 656 na SEFAZ). Ate 13/09/2026 a espera ia para TODOS os '
    || 'fluxos do dominio - 42, porque as 14 empresas dividem a mesma raiz de '
    || 'CNPJ - e foi estreitada quando ficou provado que a cota e do CNPJ de 14 '
    || 'digitos: em 12/09 a empresa 29 consultou DENTRO da janela de bloqueio da '
    || 'empresa 30, no mesmo certificado, e recebeu cStat 137. O PISO DE 60 E '
    || 'EXIGENCIA DA NT 2014.002, nao preferencia: consultar antes de vencer a '
    || 'hora ZERA o tempo e reinicia a contagem, e o fluxo nunca sai do laco '
    || 'sozinho. Os outros TIPOS do mesmo CNPJ pausam junto - em 01/09/2026 o '
    || 'CT-e e o NF-e da mesma empresa 30, a 30 segundos, deram 656. Valor abaixo '
    || 'de 60 e recusado pelo codigo e substituido por 60. Faixa: 60 a 1440.'
  from dual
 where not exists (select 1 from poseidon.dpc_parametro
                    where lower(nome) = 'dfe_min_backoff_656');

-- ---------------------------------------------------------------------------
-- dfe_conexao_erp = oracle   (nome de conexao, nao numero)
-- o unico parametro que NAO e ajuste de motor: diz de qual banco ler o ERP
-- ---------------------------------------------------------------------------
--  DIFERENTE DOS QUATRO ACIMA. Aqueles calibram o motor e o default do codigo
--  serve; este responde ONDE ESTA O ERP, e o default do codigo e "a conexao
--  corrente" - que em homologacao e a errada.
--
--  Em producao o valor coincide com a conexao corrente e a linha e apenas
--  explicita. Em homologacao ela e ESSENCIAL: a conciliacao precisa ler as
--  tabelas do Consinco de PRODUCAO, senao le um clone congelado, nao encontra
--  as notas lancadas e conclui que nada entrou no ERP - em silencio, porque
--  "nenhuma nota encontrada" e resposta valida.
--
--  Faltava aqui. O parametro foi criado a mao em 03/09/2026 e nenhum script o
--  registrava; quando a base de teste foi refeita, em 09/09/2026, ele sumiu
--  sem deixar rastro e nao havia de onde recria-lo. E o que este bloco corrige.
insert into poseidon.dpc_parametro (nome, valor, explicacao)
select 'dfe_conexao_erp', 'oracle',
       'Modulo DFe (ApiNFE) - nome da conexao de banco de onde o dfe:conciliar '
    || 'le as tabelas de recebimento do Consinco (mlf_auxnotafiscal, '
    || 'mlf_notafiscal, rf_notamestre) para descobrir a etapa da nota no ERP. '
    || 'Valores validos: os nomes configurados na ApiNFE - oracle (producao) e '
    || 'oracle_tst (homologacao). DEVE APONTAR PARA PRODUCAO mesmo rodando em '
    || 'homologacao: as tabelas do Consinco que valem sao as de producao, e '
    || 'homologacao e clone congelado. Sem esta linha o codigo usa a conexao '
    || 'corrente, e em homologacao isso faz TODA nota parecer nao lancada. '
    || 'Consequencia operacional: rodando em homologacao, um job de 30 minutos '
    || 'le producao - e leitura, nunca escrita.'
  from dual
 where not exists (select 1 from poseidon.dpc_parametro
                    where lower(nome) = 'dfe_conexao_erp');

commit;


-- ============================================================================
--  CONFERENCIA - deve devolver as 6 linhas, uma vez cada
-- ============================================================================
select nome, valor, length(explicacao) as tam_explicacao, count(*) over () as total
  from poseidon.dpc_parametro
 where lower(nome) like 'dfe%'
 order by nome;


-- ============================================================================
--  SE PRECISAR ATUALIZAR A EXPLICACAO DEPOIS (o script nao faz isso sozinho:
--  reexecutar nao pode sobrescrever valor que o operador ajustou a mao)
-- ============================================================================
-- update poseidon.dpc_parametro set valor = '10'
--  where lower(nome) = 'dfe_max_bloqueios_dia';
-- commit;
