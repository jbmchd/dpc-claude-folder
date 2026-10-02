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
--  falhou, ficando sem totais, sem transporte e sem cobranca por causa de uma
--  lista.
--
--  Medido nas 2.088 primeiras linhas gravadas:
--    dsc_especie_volume     media 2, maximo 142, nenhuma acima de 300
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
--   SEGURO COM DADO DENTRO
--  ==========================================================================
--  Aumentar VARCHAR2 nao reescreve linha nem invalida indice: o Oracle so
--  troca o metadado. Nada do que ja esta gravado se perde.
--
--  >>> RODAR COM A CARGA PARADA. Um ALTER precisa de lock exclusivo e, com
--  >>> insert acontecendo, pode falhar com ORA-00054. O ddl_lock_timeout
--  >>> abaixo faz o Oracle esperar ate 60s em vez de desistir na hora.
--
--  ==========================================================================
--   COMO RODAR (DBeaver)
--  ==========================================================================
--  Conectado como POSEIDON, arquivo INTEIRO com Alt+X. Idempotente: coluna
--  que ja esta com 1000 e pulada. Rollback: nao ha, e nao faria sentido -
--  reduzir de volta falharia em qualquer linha que ja passe de 400.
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

declare
  type t_lista is table of varchar2(200);
  nomes t_lista := t_lista(
    'dsc_especie_volume',
    'dsc_marca_volume',
    'dsc_numeracao_volume'
  );
  tamanho number;
begin
  execute immediate q'[alter session set ddl_lock_timeout = 60]';

  for i in 1 .. nomes.count loop
    select data_length into tamanho from all_tab_columns
     where owner = 'POSEIDON' and table_name = 'DPC_DFE_NOTA_TRANSPORTE'
       and column_name = upper(nomes(i));

    if tamanho < 1000 then
      execute immediate q'[alter table poseidon.dpc_dfe_nota_transporte modify (]'
                        || nomes(i) || ' VARCHAR2(1000))';
      dbms_output.put_line('alargada: ' || nomes(i) || ' (' || tamanho || ' -> 1000)');
    else
      dbms_output.put_line(nomes(i) || ' ja tem ' || tamanho || '.');
    end if;
  end loop;
exception
  when others then
    dbms_output.put_line('DPC_DFE_NOTA_TRANSPORTE: FALHOU -> ' || sqlerrm);
end;

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
