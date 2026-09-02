-- ==========================================================================
--  04 - PARAMETROS OPERACIONAIS DO MODULO DFe
-- ==========================================================================
--
--  ULTIMO PASSO DA INSTALACAO, e o unico que os DOIS caminhos compartilham:
--  base nova (depois de 01, 02, 03) e base se atualizando (depois de
--  alteracoes/atualizacao_v7_a_v10_dbeaver.sql).
--
--  Nao cria objeto: carrega 4 linhas em POSEIDON.DPC_PARAMETRO, que ja
--  existe e e compartilhada pelo ecossistema.
--
--  POR QUE ESTE PASSO EXISTE SEPARADO DO 01
--  ----------------------------------------
--  O 01_estrutura cria as 13 tabelas DO MODULO. DPC_PARAMETRO nao e uma
--  delas - e tabela global, de outro dono - entao o instalador nunca a
--  incluiu. Isso deixou um buraco na documentacao: quem seguisse "base nova
--  nao roda alteracoes" instalava sem os parametros.
--
--  E NAO E INOFENSIVO. Sem estas linhas o motor cai nos defaults internos, e
--  um deles MUDA COMPORTAMENTO: o freio de consumo indevido volta a 5
--  bloqueios/dia, fica abaixo do ruido normal do sistema, e o motor se
--  recusa a consultar a SEFAZ - em silencio, sem erro em log nenhum.
--
--  ORDEM: ANTES DO DEPLOY DO CODIGO
--  --------------------------------
--    04 antes do deploy    correto
--    deploy antes do 04    no intervalo o freio opera com 5 e o motor para
--
--  Rodar antes e seguro nos dois sentidos: codigo antigo nao le esta tabela,
--  entao as linhas ficam inertes ate o deploy.
--
--  Explicacao completa:
--  workspace/.claude/docs/nfe_dfe/docs/07_ddl-instalacao.md
-- ==========================================================================


-- ============================================================================
--  v11 - PARAMETROS OPERACIONAIS DO MODULO DFe EM POSEIDON.DPC_PARAMETRO
-- ============================================================================
--
--  Nao cria objeto nenhum. E carga de 4 linhas na tabela de parametros do
--  ecossistema, que ja existe. Rodar como POSEIDON.
--
--  POR QUE ISTO PRECISA RODAR
--  --------------------------
--  Ate agora esses 4 valores vinham do .env de cada projeto. O codigo novo le
--  da tabela; sem estas linhas ele cai nos defaults internos, e um deles
--  MUDA O COMPORTAMENTO: o freio de consumo indevido volta a 5 bloqueios/dia,
--  que fica ABAIXO do ruido normal do sistema (medido de 28 a 31/08/2026:
--  exatamente 5 por dia, todos os dias, sem defeito nenhum). O motor passaria
--  a se travar sozinho todo dia.
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
-- dfe_max_bloqueios_dia = 10   (faixa 1 a 20)
-- o freio; sem esta linha o codigo usa 5 e o motor se trava todo dia
-- ---------------------------------------------------------------------------
insert into poseidon.dpc_parametro (nome, valor, explicacao)
select 'dfe_max_bloqueios_dia', '10',
       'Modulo DFe (ApiNFE) - freio de emergencia: acima deste numero de bloqueios '
    || 'por consumo indevido (cStat 656) em 24h, o dfe:ingerir para de consultar a '
    || 'SEFAZ. Existe porque 50 bloqueios consecutivos de 60min podem virar '
    || 'bloqueio PERMANENTE do certificado. ESTA 10 e nao 5 porque 5 ficava abaixo '
    || 'do ruido do sistema: medido de 28 a 31/08/2026, foram 5 bloqueios/dia '
    || 'todos os dias com apenas 2 fluxos de NF-e ativos (~2,5 por fluxo), sem '
    || 'defeito nenhum - e o 656 que a SEFAZ devolve a consulta de NF-e em fim de '
    || 'fila. ATENCAO: nao escala. Com 13 CNPJs (apos o corte da Qive) a taxa '
    || 'normal vai a ~32/dia e este numero corta o motor todo dia. A saida e '
    || 'contar bloqueio POR FLUXO. Lido tambem pela ApiDPC, na tela do Monitor '
    || 'DFe. Faixa aceita: 1 a 20.'
  from dual
 where not exists (select 1 from poseidon.dpc_parametro
                    where lower(nome) = 'dfe_max_bloqueios_dia');

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
       'Modulo DFe (ApiNFE) - minutos de espera aplicados a TODOS os fluxos do '
    || 'dominio quando a fonte devolve bloqueio por consumo indevido (cStat 656 na '
    || 'SEFAZ). O PISO DE 60 E EXIGENCIA DA NT 2014.002, nao preferencia: '
    || 'consultar antes de vencer a hora reinicia o cronometro do bloqueio, e 50 '
    || 'bloqueios consecutivos podem virar bloqueio PERMANENTE do certificado. '
    || 'Valor abaixo de 60 e recusado pelo codigo e substituido por 60. Faixa '
    || 'aceita: 60 a 1440.'
  from dual
 where not exists (select 1 from poseidon.dpc_parametro
                    where lower(nome) = 'dfe_min_backoff_656');

commit;


-- ============================================================================
--  CONFERENCIA - deve devolver as 4 linhas, uma vez cada
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
