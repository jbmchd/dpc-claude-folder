-- ============================================================================
--  v12 - ESTADO DA NOTA NO ERP: de booleano para escada de 4 estados
-- ============================================================================
--  Rodar como POSEIDON, no DBeaver, o arquivo INTEIRO com Alt+X. Sem barra para
--  terminar bloco. Reexecutavel: cada coluna e criada so se ainda nao existir.
--
--  POR QUE
--  -------
--  Hoje DPC_DFE_NOTA.STATUS_RECEBIMENTO responde "entrou no ERP?" com S ou N.
--  A entrada no ERP nao e um evento, e um processo com etapas, e cada etapa
--  vive numa tabela diferente do schema consinco:
--
--     em nenhuma delas        -> ainda nao digitada
--     mlf_auxnotafiscal       -> digitada, NAO liberada
--     mlf_notafiscal          -> recebimento finalizado
--     rf_notamestre           -> escriturada (fiscal)
--
--  A ETAPA NAO ESTA NUM CAMPO, ESTA EM QUAL TABELA A NOTA APARECE. Medido em
--  02/09/2026: os campos de status das tres familias sao degenerados nas nossas
--  notas - mlf.statusnf = 'V' em todas as 444, mlf.statusnfe NULO em todas,
--  rf.codsitdoc = 0 em todas. Nao ha o que ler deles.
--
--  O CENARIO REAL, medido contra a Consinco de PRODUCAO (815 notas):
--
--     ESCRITURADA         738   90,6%
--     AGUARDANDO_XML       47    5,8%   (resumo, sem XML completo)
--     AGUARDANDO_ENTRADA   29    3,6%
--     EM_DIGITACAO          1    0,1%
--     RECEBIDA              0      -
--
--  RECEBIDA nao aparece isolada: toda nota em mlf_notafiscal ja esta em
--  rf_notamestre. A janela entre receber e escriturar e curta demais para um
--  snapshot pegar. O estado fica assim mesmo - custa nada e captura o
--  transiente -, mas nao esperar volume nele.
--
--  Atraso de lancamento (emissao -> escrituracao), 738 notas:
--  mediana 1 dia, media 1,8, maximo 74.
-- ============================================================================


-- ###########################################################################
--  1. AS COLUNAS
-- ###########################################################################
--  NUM_ESTADO_ERP guarda o ORDINAL, e nao so o nome, porque a comparacao que
--  interessa e de ordem: regressao e "o atual e menor que o maximo ja
--  atingido". Comparar VARCHAR2 nao responde isso.
declare
  qtd number;
begin
  select count(*) into qtd from all_tab_columns
   where owner = 'POSEIDON' and table_name = 'DPC_DFE_NOTA'
     and column_name = 'SIG_ESTADO_ERP';

  if qtd = 0 then
    execute immediate 'alter table poseidon.dpc_dfe_nota add (
        sig_estado_erp      varchar2(20),
        num_estado_erp      number(1),
        num_estado_erp_max  number(1),
        dta_estado_erp      timestamp(6),
        seq_notamestre_erp  number,
        dta_lancamento_erp  date
    )';
  end if;
end;


-- ###########################################################################
--  2. CHECK - a escada, e a coerencia entre nome e ordinal
-- ###########################################################################
--  Sem isto, um update manual pode gravar SIG = 'ESCRITURADA' com NUM = 0 e o
--  dashboard passa a mentir sem que nada acuse. A tabela DPC_PARAMETRO nao tem
--  CHECK e por isso a validacao dela precisou ir para o codigo; aqui a tabela e
--  nossa, entao a garantia fica no banco.
--
--  CK4 e CK5, e nao CK3: o CK3 ja existe nesta tabela, e o do sig_papel_empresa.
--  Conferido antes de escrever - nome de constraint colide em silencio.
declare
  qtd number;
begin
  select count(*) into qtd from all_constraints
   where owner = 'POSEIDON' and constraint_name = 'DPC_DFE_NOTA_CK4';

  if qtd = 0 then
    execute immediate q'[
      alter table poseidon.dpc_dfe_nota add constraint dpc_dfe_nota_ck4 check (
        (sig_estado_erp is null and num_estado_erp is null)
        or (sig_estado_erp = 'AGUARDANDO_ENTRADA' and num_estado_erp = 0)
        or (sig_estado_erp = 'EM_DIGITACAO'       and num_estado_erp = 1)
        or (sig_estado_erp = 'RECEBIDA'           and num_estado_erp = 2)
        or (sig_estado_erp = 'ESCRITURADA'        and num_estado_erp = 3)
      )]';
  end if;
end;

--  O maximo nunca pode ser menor que o atual seria ERRADO exigir: o atual MENOR
--  que o maximo e exatamente a regressao que queremos detectar. O que nao pode
--  e o maximo ficar abaixo de algo que ja aconteceu - isso o codigo garante,
--  gravando sempre greatest(atual, maximo).
declare
  qtd number;
begin
  select count(*) into qtd from all_constraints
   where owner = 'POSEIDON' and constraint_name = 'DPC_DFE_NOTA_CK5';

  if qtd = 0 then
    execute immediate 'alter table poseidon.dpc_dfe_nota add constraint dpc_dfe_nota_ck5 check (
        num_estado_erp_max is null or num_estado_erp_max between 0 and 3)';
  end if;
end;


-- ###########################################################################
--  3. COMENTARIOS
-- ###########################################################################
comment on column poseidon.dpc_dfe_nota.sig_estado_erp is
  'Etapa da nota no ERP: AGUARDANDO_ENTRADA | EM_DIGITACAO | RECEBIDA | ESCRITURADA. NULO = ainda nao conciliada nenhuma vez. Preenchido pelo dfe:conciliar.';

comment on column poseidon.dpc_dfe_nota.num_estado_erp is
  'Ordinal da etapa: 0 aguardando, 1 digitada, 2 recebida, 3 escriturada. Existe para comparar ORDEM - regressao e num_estado_erp < num_estado_erp_max.';

comment on column poseidon.dpc_dfe_nota.num_estado_erp_max is
  'Maior ordinal que esta nota ja atingiu. Nunca diminui. Quando fica ACIMA do atual, a nota REGREDIU no ERP - foi desfeita uma etapa.';

comment on column poseidon.dpc_dfe_nota.dta_estado_erp is
  'Quando o estado atual foi observado pela ultima vez. Nao e quando mudou: e quando foi conferido.';

comment on column poseidon.dpc_dfe_nota.seq_notamestre_erp is
  'consinco.rf_notamestre.SEQNOTA correspondente. REFERENCIA para localizar a escrituracao, nao chave unica.';

comment on column poseidon.dpc_dfe_nota.dta_lancamento_erp is
  'Data de lancamento fiscal (rf_notamestre.DTALANCAMENTO). dta_lancamento_erp - dta_emissao e o atraso de escrituracao: mediana medida de 1 dia, maximo de 74.';


-- ###########################################################################
--  4. CONFERENCIA DA ESTRUTURA
-- ###########################################################################
--  ESPERADO: 6 colunas e 2 constraints.
select count(*) as colunas_novas
  from all_tab_columns
 where owner = 'POSEIDON' and table_name = 'DPC_DFE_NOTA'
   and column_name in ('SIG_ESTADO_ERP','NUM_ESTADO_ERP','NUM_ESTADO_ERP_MAX',
                       'DTA_ESTADO_ERP','SEQ_NOTAMESTRE_ERP','DTA_LANCAMENTO_ERP');

select constraint_name, search_condition_vc
  from all_constraints
 where owner = 'POSEIDON' and constraint_name in ('DPC_DFE_NOTA_CK4','DPC_DFE_NOTA_CK5');


-- ###########################################################################
--  5. DEPOIS DE RODAR
-- ###########################################################################
--  As colunas nascem NULAS de proposito. NULO significa "ainda nao conciliada",
--  e e diferente de AGUARDANDO_ENTRADA, que significa "conferido, e o ERP nao
--  tem". Nao preencher no alter: dizer AGUARDANDO_ENTRADA sem ter conferido
--  seria afirmar algo que nao foi medido.
--
--  Quem preenche e o comando, e a primeira execucao cobre o acervo inteiro:
--
--      php artisan dfe:conciliar --dry-run --debug     -- confere primeiro
--      php artisan dfe:conciliar
--
--  Conferencia depois de rodar - ESPERADO nenhuma linha NULA e a distribuicao
--  proxima da medida em 02/09/2026 (90% escriturada, 4% aguardando):
select nvl(sig_estado_erp,'(nao conciliada)') as estado,
       count(*)                               as qtd,
       round(100 * count(*) / sum(count(*)) over (), 1) as pct,
       sum(case when num_estado_erp < num_estado_erp_max then 1 else 0 end) as regrediram
  from poseidon.dpc_dfe_nota
 group by nvl(sig_estado_erp,'(nao conciliada)')
 order by 2 desc;

--  As que regrediram, se houver. Uma nota aqui significa que uma etapa foi
--  DESFEITA no ERP - nota digitada que foi excluida antes de liberar, ou
--  escrituracao cancelada. Nao e erro nosso: e informacao.
select n.chave_nf, e.nro_empresa, n.nro_nf,
       n.sig_estado_erp as agora, n.num_estado_erp_max as ja_chegou_em,
       to_char(n.dta_estado_erp,'dd/mm/yyyy hh24:mi') as conferido_em
  from poseidon.dpc_dfe_nota n
  join poseidon.dpc_dfe_empresa e on e.cod_dfe_empresa = n.cod_dfe_empresa
 where n.num_estado_erp < n.num_estado_erp_max
 order by n.dta_estado_erp desc;
-- ============================================================================
