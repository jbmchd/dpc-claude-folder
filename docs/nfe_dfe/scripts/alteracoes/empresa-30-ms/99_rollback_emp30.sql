-- ============================================================================
--  99 - ROLLBACK do cadastro da empresa 30
-- ============================================================================
--  SOMENTE tst. Reescrito em 02/09/2026.
--
--  O QUE ESTAVA ERRADO NA VERSAO ANTERIOR
--  --------------------------------------
--  Ela apagava de 6 tabelas e se apresentava como completa, mas nao apagava de
--  DPC_DFE_CURSOR, DPC_DFE_NOTA_ITEM, DPC_DFE_CTE, DPC_DFE_CTE_NFE,
--  DPC_DFE_CTE_EVENTO nem DPC_DFE_NFSE - tabelas que passaram a existir depois
--  que ela foi escrita (39b172d, v7, v10).
--
--  Resultado: o delete de DPC_DFE_EMPRESA falharia por FK do cursor, ou, pior,
--  deixaria linha orfa apontando para empresa inexistente.
--
--  ORDEM: filho antes de pai. Cada delete e amarrado a empresa 30, e o de
--  identidade/certificado tambem por created_by - so o que ESTE cadastro criou
--  e removido.
--
--  DPC_DFE_EMITENTE NAO entra: fornecedor e compartilhado entre empresas, e nao
--  tem cod_dfe_empresa. Apagar por aqui removeria emitente de outras empresas.
-- ============================================================================


-- ---------------------------------------------------------------------------
--  1. Filhos de NOTA
-- ---------------------------------------------------------------------------
delete from poseidon.dpc_dfe_manifestacao
 where cod_dfe_nota in (select n.cod_dfe_nota
                          from poseidon.dpc_dfe_nota n
                          join poseidon.dpc_dfe_empresa e
                            on e.cod_dfe_empresa = n.cod_dfe_empresa
                         where e.nro_empresa = 30);

delete from poseidon.dpc_dfe_nota_item
 where cod_dfe_nota in (select n.cod_dfe_nota
                          from poseidon.dpc_dfe_nota n
                          join poseidon.dpc_dfe_empresa e
                            on e.cod_dfe_empresa = n.cod_dfe_empresa
                         where e.nro_empresa = 30);


-- ---------------------------------------------------------------------------
--  2. Filhos de CT-e
-- ---------------------------------------------------------------------------
delete from poseidon.dpc_dfe_cte_evento
 where cod_dfe_empresa in (select cod_dfe_empresa from poseidon.dpc_dfe_empresa
                            where nro_empresa = 30);

delete from poseidon.dpc_dfe_cte_nfe
 where cod_dfe_cte in (select t.cod_dfe_cte
                         from poseidon.dpc_dfe_cte t
                         join poseidon.dpc_dfe_empresa e
                           on e.cod_dfe_empresa = t.cod_dfe_empresa
                        where e.nro_empresa = 30);


-- ---------------------------------------------------------------------------
--  3. Normalizado
-- ---------------------------------------------------------------------------
delete from poseidon.dpc_dfe_evento
 where cod_dfe_empresa in (select cod_dfe_empresa from poseidon.dpc_dfe_empresa
                            where nro_empresa = 30);

delete from poseidon.dpc_dfe_nota
 where cod_dfe_empresa in (select cod_dfe_empresa from poseidon.dpc_dfe_empresa
                            where nro_empresa = 30);

delete from poseidon.dpc_dfe_cte
 where cod_dfe_empresa in (select cod_dfe_empresa from poseidon.dpc_dfe_empresa
                            where nro_empresa = 30);

delete from poseidon.dpc_dfe_nfse
 where cod_dfe_empresa in (select cod_dfe_empresa from poseidon.dpc_dfe_empresa
                            where nro_empresa = 30);


-- ---------------------------------------------------------------------------
--  4. Aquisicao
-- ---------------------------------------------------------------------------
--  ATENCAO: aqui vai embora o XML bruto. A SEFAZ retem por ~90 dias e o cursor
--  existe SOMENTE em DPC_DFE_CURSOR - depois deste delete ninguem sabe de onde
--  retomar. Se a intencao for apenas PARAR a captura, nao rode este script:
--  pause os fluxos.
delete from poseidon.dpc_dfe_documento
 where cod_dfe_empresa in (select cod_dfe_empresa from poseidon.dpc_dfe_empresa
                            where nro_empresa = 30);

delete from poseidon.dpc_dfe_execucao
 where cod_dfe_empresa in (select cod_dfe_empresa from poseidon.dpc_dfe_empresa
                            where nro_empresa = 30);


-- ---------------------------------------------------------------------------
--  5. Cursor, identidade e certificado
-- ---------------------------------------------------------------------------
delete from poseidon.dpc_dfe_cursor
 where cod_dfe_empresa in (select cod_dfe_empresa from poseidon.dpc_dfe_empresa
                            where nro_empresa = 30)
   and created_by = 'CADASTRO DFE';

delete from poseidon.dpc_dfe_empresa
 where nro_empresa = 30
   and created_by = 'CADASTRO DFE';

delete from poseidon.dpc_conta_certif_digital_emp
 where cod_empresa = 30
   and created_by = 'CADASTRO DFE';

commit;


-- ---------------------------------------------------------------------------
--  6. Conferencia
-- ---------------------------------------------------------------------------
--  ESPERADO: todas as contagens em 0.
select (select count(*) from poseidon.dpc_dfe_empresa
          where nro_empresa = 30)                                    as identidade,
       (select count(*) from poseidon.dpc_dfe_cursor c
          join poseidon.dpc_dfe_empresa e on e.cod_dfe_empresa = c.cod_dfe_empresa
         where e.nro_empresa = 30)                                   as fluxos,
       (select count(*) from poseidon.dpc_conta_certif_digital_emp
         where cod_empresa = 30)                                     as certificado
  from dual;

--  Cinto de seguranca: cursor orfao em QUALQUER empresa. ESPERADO: 0.
--  Se der diferente de 0, algum rollback anterior deixou lixo.
select count(*) as cursor_orfao
  from poseidon.dpc_dfe_cursor c
 where not exists (select 1 from poseidon.dpc_dfe_empresa e
                    where e.cod_dfe_empresa = c.cod_dfe_empresa);
-- ============================================================================
