-- ============================================================================
--  01 - ALL CARS ASSETS em consinco.ge_empresa
-- ============================================================================
--  SOMENTE HOMOLOGACAO (tst). Descartavel.
--
--  POR QUE ISTO EXISTE
--  O modulo DFe monta o configJson do sped-nfe a partir de consinco.ge_empresa.
--  Sem uma linha aqui, o dfe:ingerir aborta com "Empresa 900 nao encontrada em
--  consinco.ge_empresa".
--
--  Escolhemos este caminho, em vez de alterar dpc_dfe_empresa, porque o objetivo
--  e apenas TESTAR o motor num CNPJ que a Qive nao atende. Nao ha mudanca de
--  codigo nem de schema - o preco e que a linha e descartavel (ver README).
--
--  nroempresa 900: acima de qualquer empresa real (a maior hoje e 376), para
--  nunca colidir com cadastro do ERP.
--
--  De todas as 57 colunas, apenas 6 sao NOT NULL: nroempresa, fantasia,
--  razaosocial, nomereduzido, status e nrobaseexportacao. Preenchemos essas mais
--  as que o codigo realmente le. A tabela nao tem nenhuma FK, entao nao ha
--  cadeia de cadastros dependentes.
--
--  SEQCIDADE E OBRIGATORIO NA PRATICA, apesar de ser nullable na tabela.
--  O GeEmpresa::showAll faz INNER JOIN com consinco.ge_cidade em seqcidade -
--  com seqcidade nulo o join descarta a linha e o dfe:ingerir reporta
--  "Empresa 900 nao encontrada em consinco.ge_empresa" mesmo com a linha
--  existindo. Foi exatamente o que aconteceu na primeira versao deste script.
--  27081 = Caratinga/MG, a mesma cidade da matriz (empresa 1).
-- ============================================================================

-- ---------------------------------------------------------------------------
--  1. Insert (nao faz nada se ja existir)
-- ---------------------------------------------------------------------------
insert into consinco.ge_empresa
  (nroempresa, fantasia, razaosocial, nomereduzido, status, nrobaseexportacao,
   nrocgc, digcgc, estado, cidade, seqcidade, pais, inscrmunicipal,
   dtaalteracao, usualteracao)
select 900,
       'ALL CARS ASSETS LTDA',
       'ALL CARS ASSETS LTDA',
       '900-ALL CARS',
       'A',
       0,
       '456944070001',   -- 12 primeiros digitos
       2,                -- digito verificador (02)
       'MG',             -- vira <cUFAutor> no distDFeInt
       'CARATINGA',
       27081,            -- Caratinga/MG: sem isto o INNER JOIN descarta a linha
       'BRASIL',
       'ISENTO',
       sysdate,
       'TESTE DFE'
  from dual
 where not exists (select 1 from consinco.ge_empresa where nroempresa = 900);

-- ---------------------------------------------------------------------------
--  1b. Reparo: preenche seqcidade se a linha foi criada sem ela
-- ---------------------------------------------------------------------------
update consinco.ge_empresa
   set seqcidade    = 27081,
       dtaalteracao = sysdate,
       usualteracao = 'TESTE DFE'
 where nroempresa = 900
   and seqcidade is null;

commit;

-- ---------------------------------------------------------------------------
--  2. Conferencia CRITICA: o CNPJ montado
-- ---------------------------------------------------------------------------
--  O codigo le o CNPJ por poseidon.montacpfcnpj(nrocgc, digcgc). Como digcgc e
--  NUMBER(2), o valor 2 precisa voltar como "02" - se a funcao nao completar com
--  zero a esquerda, o CNPJ sai com 13 digitos e a SEFAZ recusa.
--
--  ESPERADO: cnpj_montado = 45694407000102 e tamanho = 14.
--  Se vier 13, PARE: nao consulte a SEFAZ com CNPJ malformado.
--  O join com ge_cidade e o MESMO que o GeEmpresa::showAll usa. Se este select
--  nao devolver linha, o codigo tambem nao vai encontrar a empresa.
select e.nroempresa,
       e.fantasia,
       e.estado,
       e.seqcidade,
       c.codibge,
       poseidon.montacpfcnpj(e.nrocgc, e.digcgc) as cnpj_montado,
       length(poseidon.montacpfcnpj(e.nrocgc, e.digcgc)) as tamanho,
       e.status
  from consinco.ge_empresa e
  join consinco.ge_cidade c on c.seqcidade = e.seqcidade
 where e.nroempresa = 900;
