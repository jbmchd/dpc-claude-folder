-- ============================================================================
--  04 - pessoa juridica da ALL CARS em consinco.ge_pessoa
-- ============================================================================
--  SOMENTE HOMOLOGACAO (tst). Descartavel.
--
--  POR QUE ISTO EXISTE
--  poseidon.montacpfcnpj NAO formata CNPJ - ela consulta consinco.ge_pessoa
--  para descobrir se o documento e de pessoa Fisica ou Juridica:
--
--     select FISICAJURIDICA into tipo from CONSINCO.ge_pessoa
--      where nrocgccpf = numero and digcgccpf = digito and rownum = 1;
--     if tipo like 'J' then completo := lpad(numero, 12, '0');
--     else                  completo := lpad(numero,  9, '0'); end if;
--     completo := completo || lpad(digito, 2, '0');
--
--  Sem pessoa cadastrada a function levanta NO_DATA_FOUND. Como ela nao trata a
--  excecao, e o Oracle converte NO_DATA_FOUND em NULL quando a function e
--  chamada de dentro de um SELECT, o resultado e cpfcnpj nulo - e o sped-nfe
--  reprova na validacao do config.json:
--     [cnpj] Does not match the regex pattern ^[A-Z0-9]{11,14}
--
--  Conferido antes de escrever este script: nao existe pessoa com esse CNPJ em
--  nenhum formato (busca por nrocgccpf, nrocgccpf_bkp e nomerazao).
--
--  ============================================================================
--   ATENCAO - ESTE E O UNICO ITEM QUE NAO REVERTE 100%
--  ============================================================================
--  ge_pessoa tem ~10 triggers de insert/update, entre elas TAIU_GE_PESSOALOG,
--  TAIU_GE_PESSOACADASTROLOG (log), TAUD_AFV_GE_PESSOA (replicacao para forca de
--  vendas), TAU_GE_PESSOA_EFDLOG_REG0175 (log fiscal) e
--  TAD_RF_REINF_R2040_PESSOA (REINF).
--
--  O delete do rollback NAO desfaz o que essas triggers gravaram em tabelas de
--  log e replicacao - e o proprio delete dispara mais triggers. Aceitavel em
--  homologacao, mas fica registrado.
--
--  NROCGCCPF precisa ser gravado EXATAMENTE como esta em ge_empresa.nrocgc
--  ('456944070001'), porque a function compara as duas strings sem normalizar.
--  Um zero a esquerda a mais e a busca falha mesmo com a pessoa existindo.
--
--  seqpessoa: nao ha sequence aparente para esta coluna (nenhum S_GE_PESSOA),
--  entao usamos max+1. Se alguma trigger BEFORE preencher por conta propria,
--  o valor dela prevalece e nao ha problema.
-- ============================================================================

-- ---------------------------------------------------------------------------
--  1. Insert (nao faz nada se ja existir)
-- ---------------------------------------------------------------------------
--  Deliberadamente enxuto: apenas as 5 colunas NOT NULL (seqpessoa, versao,
--  status, nomerazao, nrobaseexportacao), as 3 que a function le
--  (fisicajuridica, nrocgccpf, digcgccpf) e a trilha de inclusao. Endereco e os
--  outros ~110 campos nao sao necessarios.
--
--  Se alguma trigger exigir campo adicional, o erro do Oracle vai nomear a
--  coluna - acrescente e rode de novo.
insert into consinco.ge_pessoa
  (seqpessoa, versao, status, nomerazao, nrobaseexportacao,
   fisicajuridica, nrocgccpf, digcgccpf,
   fantasia, dtaativacao, dtainclusao, usuinclusao)
select (select max(seqpessoa) + 1 from consinco.ge_pessoa),
       1,
       'A',
       'ALL CARS ASSETS LTDA',
       0,
       'J',               -- <<< o campo que a montacpfcnpj le
       '456944070001',    -- IGUAL a ge_empresa.nrocgc, sem zero a esquerda
       2,                 -- digito verificador (02)
       'ALL CARS ASSETS LTDA',
       sysdate,
       sysdate,
       'TESTE DFE'
  from dual
 where not exists (select 1
                     from consinco.ge_pessoa
                    where nrocgccpf = '456944070001'
                      and digcgccpf = 2);

commit;

-- ---------------------------------------------------------------------------
--  2. Conferencia: a pessoa gravada
-- ---------------------------------------------------------------------------
select seqpessoa, nomerazao, nrocgccpf, digcgccpf, fisicajuridica, status
  from consinco.ge_pessoa
 where nrocgccpf = '456944070001'
   and digcgccpf = 2;

-- ---------------------------------------------------------------------------
--  3. Conferencia DECISIVA: o CNPJ que a rotina vai enviar a SEFAZ
-- ---------------------------------------------------------------------------
--  ESPERADO: cnpj_montado = 45694407000102 e tam = 14.
--
--  A empresa 1 esta na consulta como controle: ela sempre funcionou, entao se a
--  linha dela vier certa e a 900 nao, o problema segue sendo dado nosso.
select e.nroempresa,
       e.fantasia,
       poseidon.montacpfcnpj(e.nrocgc, e.digcgc) as cnpj_montado,
       length(poseidon.montacpfcnpj(e.nrocgc, e.digcgc)) as tam
  from consinco.ge_empresa e
  join consinco.ge_cidade c on c.seqcidade = e.seqcidade
 where e.nroempresa in (1, 900)
 order by e.nroempresa;
