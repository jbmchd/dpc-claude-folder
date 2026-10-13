-- ============================================================================
--  MODULO DFe - NF-e: ALARGA AS LISTAS DE VOLUME (ARQUIVO 08_02)
-- ============================================================================
--  Tabela alterada: poseidon.dpc_dfe_nota_transporte
--  dsc_especie_volume, dsc_marca_volume, dsc_numeracao_volume: 400 -> 1000
--
--  ==========================================================================
--   POR QUE
--  ==========================================================================
--  As tres guardam a lista de valores DISTINTOS dos volumes da nota, e o
--  grupo <vol> e 1:N sem teto no leiaute: quem limita e a coluna.
--
--  O 400 saiu de uma amostra de 400 notas, onde o maior era bem menor. Na
--  carga de 02/10/2026 apareceu a nota real que desmentiu a amostra: 16
--  especies distintas, 409 caracteres, ORA-12899 - e o documento INTEIRO
--  falhou, ficando sem totais, sem transporte e sem cobranca por causa de
--  uma lista.
--
--  Medido no acervo inteiro depois da carga (9.396 linhas):
--    dsc_especie_volume     media 2, maximo 142
--    dsc_marca_volume       maximo 16
--    dsc_numeracao_volume   maximo 15
--
--  Ou seja: 400 ja era folgado para o caso comum e apertado para o extremo.
--  1000 cobre cerca de 35 especies - o dobro do pior caso visto - e a coluna
--  continua VARCHAR2, sem o custo de LOB.
--
--  O corte tambem passou a existir no codigo (DfeNotaBlocoRepository::corta),
--  que e onde ele tem de estar: cortar o fim de uma lista custa menos do que
--  derrubar o documento inteiro. Esta DDL e para o corte quase nunca agir.
--
--  ==========================================================================
--   POR QUE AQUI NAO TEM BLOCO PL/SQL
--  ==========================================================================
--  Os outros arquivos deste modulo embrulham a DDL num bloco so para poder
--  perguntar antes "ja existe?". Aqui isso nao e preciso: no Oracle, pedir
--  para uma coluna o tamanho que ela JA TEM e aceito sem erro (conferido em
--  02/10/2026). Entao tres ALTER soltos ja sao idempotentes.
--
--  E sao mais seguros: a primeira versao deste arquivo usava bloco e o
--  DBeaver o cortou, devolvendo PLS-00103. O bloco em si era valido - o
--  Oracle o aceitou quando enviado inteiro -, mas o divisor de statements do
--  DBeaver nao o digeriu. Sem bloco, nao ha o que cortar.
--
--  ==========================================================================
--   SEGURO COM DADO DENTRO
--  ==========================================================================
--  Aumentar VARCHAR2 nao reescreve linha nem invalida indice: o Oracle so
--  troca o metadado. Nada do que ja esta gravado se perde.
--
--  >>> RODAR COM A CARGA PARADA. Um ALTER precisa de lock exclusivo e, com
--  >>> insert acontecendo, falha com ORA-00054 (resource busy). Se isso
--  >>> acontecer, espere a carga terminar e rode de novo - nada fica pela
--  >>> metade, cada ALTER e atomico.
--
--  ==========================================================================
--   COMO RODAR (DBeaver)
--  ==========================================================================
--  Conectado como POSEIDON, arquivo INTEIRO com Alt+X. Pode rodar quantas
--  vezes quiser. Rollback: nao ha, e nao faria sentido - reduzir de volta
--  falharia em qualquer linha que ja passe de 400.
-- ============================================================================


-- ============================================================================
--  SECAO 1 - O QUE EXISTE HOJE
-- ============================================================================

select column_name, data_length
  from all_tab_columns
 where owner = 'POSEIDON' and table_name = 'DPC_DFE_NOTA_TRANSPORTE'
   and column_name in ('DSC_ESPECIE_VOLUME', 'DSC_MARCA_VOLUME', 'DSC_NUMERACAO_VOLUME')
 order by column_name;

select max(length(dsc_especie_volume))   as maior_especie,
       max(length(dsc_marca_volume))     as maior_marca,
       max(length(dsc_numeracao_volume)) as maior_numeracao
  from poseidon.dpc_dfe_nota_transporte;


-- ============================================================================
--  SECAO 2 - ALARGAR
-- ============================================================================

alter table poseidon.dpc_dfe_nota_transporte modify (dsc_especie_volume VARCHAR2(1000));

alter table poseidon.dpc_dfe_nota_transporte modify (dsc_marca_volume VARCHAR2(1000));

alter table poseidon.dpc_dfe_nota_transporte modify (dsc_numeracao_volume VARCHAR2(1000));

comment on column poseidon.dpc_dfe_nota_transporte.dsc_especie_volume is
    'Especies distintas, separadas por virgula. 1000 desde 02/10/2026: uma nota real com 16 especies estourou os 400 originais. Tag: transp/vol/esp.';

comment on column poseidon.dpc_dfe_nota_transporte.dsc_marca_volume is
    'Marcas distintas, separadas por virgula. Tag: transp/vol/marca.';

comment on column poseidon.dpc_dfe_nota_transporte.dsc_numeracao_volume is
    'Numeracoes distintas, separadas por virgula. Tag: transp/vol/nVol.';


-- ============================================================================
--  SECAO 3 - CONFERENCIA
-- ============================================================================
--  Esperado: as tres com data_length 1000.

select column_name, data_length
  from all_tab_columns
 where owner = 'POSEIDON' and table_name = 'DPC_DFE_NOTA_TRANSPORTE'
   and column_name in ('DSC_ESPECIE_VOLUME', 'DSC_MARCA_VOLUME', 'DSC_NUMERACAO_VOLUME')
 order by column_name;
