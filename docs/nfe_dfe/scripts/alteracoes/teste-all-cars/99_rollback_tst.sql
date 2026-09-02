-- ============================================================================
--  99 - ROLLBACK do cadastro de teste da ALL CARS
--  Acrescentados em 02/09/2026 os deletes de DPC_DFE_NOTA_ITEM (v7) e
--  DPC_DFE_CTE_EVENTO (v10): tabelas criadas depois deste script, que ficavam
--  de pe num rollback que se apresentava como completo.
--
-- ============================================================================
--  SOMENTE HOMOLOGACAO (tst).
--
--  Remove TUDO: cadastro, certificado e todo o acervo capturado. Rode quando o
--  teste terminar de vez - nao ha razao para manter documento fiscal de PJ
--  distinta no banco de homologacao mais tempo que o necessario.
--
--  ATENCAO: hoje o acervo da 900 inclui as 8 NF-e e as 15 NFS-e que sao a massa
--  de validacao do motor (a NFS-e nao tem outra fonte de teste). Se a intencao
--  for apenas remover as linhas criadas na CONSINCO, que ficaram desnecessarias
--  depois do desacoplamento, use o 06_reverter_consinco_all_cars_tst.sql - ele
--  preserva certificado, cadastro e documentos.
--
--  ATUALIZADO EM 20/08/2026. A versao anterior deste script foi escrita antes do
--  alter_v2 e NAO apagava dpc_dfe_cursor, dpc_dfe_cte, dpc_dfe_cte_nfe nem
--  dpc_dfe_nfse. Como dpc_dfe_cursor tem FK para dpc_dfe_empresa
--  (DPC_DFE_CURSOR_FK1) e dpc_dfe_documento tem FK para o cursor
--  (DPC_DFE_DOCUMENTO_FK2), rodar a versao antiga hoje falharia com ORA-02292 no
--  meio da transacao.
--
--  A ORDEM IMPORTA: os documentos capturados apontam para cod_dfe_empresa.
--  Apagar a empresa antes dos documentos deixaria orfao (ou violaria a FK).
--
--  Se quiser manter o acervo bruto para continuar reprocessando o parser,
--  execute SOMENTE a secao 4 e pare - o cadastro fica, a captura fica, e o
--  status_sincronismo = 'P' impede novas consultas a SEFAZ.
-- ============================================================================

-- ---------------------------------------------------------------------------
--  1. Quanto ha para apagar (rode antes, para saber o que esta descartando)
-- ---------------------------------------------------------------------------
select (select count(*) from poseidon.dpc_dfe_documento d
          join poseidon.dpc_dfe_empresa e on e.cod_dfe_empresa = d.cod_dfe_empresa
         where e.nro_empresa = 900) as documentos,
       (select count(*) from poseidon.dpc_dfe_nota n
          join poseidon.dpc_dfe_empresa e on e.cod_dfe_empresa = n.cod_dfe_empresa
         where e.nro_empresa = 900) as notas,
       (select count(*) from poseidon.dpc_dfe_evento v
          join poseidon.dpc_dfe_empresa e on e.cod_dfe_empresa = v.cod_dfe_empresa
         where e.nro_empresa = 900) as eventos,
       (select count(*) from poseidon.dpc_dfe_cte c
          join poseidon.dpc_dfe_empresa e on e.cod_dfe_empresa = c.cod_dfe_empresa
         where e.nro_empresa = 900) as ctes,
       (select count(*) from poseidon.dpc_dfe_nfse n
          join poseidon.dpc_dfe_empresa e on e.cod_dfe_empresa = n.cod_dfe_empresa
         where e.nro_empresa = 900) as nfses,
       (select count(*) from poseidon.dpc_dfe_cursor c
          join poseidon.dpc_dfe_empresa e on e.cod_dfe_empresa = c.cod_dfe_empresa
         where e.nro_empresa = 900) as fluxos
  from dual;

-- ---------------------------------------------------------------------------
--  2. Dados capturados, de dentro para fora
-- ---------------------------------------------------------------------------
delete from poseidon.dpc_dfe_manifestacao
 where cod_dfe_nota in (select n.cod_dfe_nota
                          from poseidon.dpc_dfe_nota n
                          join poseidon.dpc_dfe_empresa e
                            on e.cod_dfe_empresa = n.cod_dfe_empresa
                         where e.nro_empresa = 900);

delete from poseidon.dpc_dfe_nota_item
 where cod_dfe_nota in (select n.cod_dfe_nota
                          from poseidon.dpc_dfe_nota n
                          join poseidon.dpc_dfe_empresa e
                            on e.cod_dfe_empresa = n.cod_dfe_empresa
                         where e.nro_empresa = 900);

delete from poseidon.dpc_dfe_cte_evento
 where cod_dfe_empresa in (select cod_dfe_empresa from poseidon.dpc_dfe_empresa
                            where nro_empresa = 900);

delete from poseidon.dpc_dfe_evento
 where cod_dfe_empresa in (select cod_dfe_empresa
                             from poseidon.dpc_dfe_empresa
                            where nro_empresa = 900);

delete from poseidon.dpc_dfe_nota
 where cod_dfe_empresa in (select cod_dfe_empresa
                             from poseidon.dpc_dfe_empresa
                            where nro_empresa = 900);

-- CT-e: as chaves transportadas apontam para o CT-e, entao saem antes.
delete from poseidon.dpc_dfe_cte_nfe
 where cod_dfe_cte in (select c.cod_dfe_cte
                         from poseidon.dpc_dfe_cte c
                         join poseidon.dpc_dfe_empresa e
                           on e.cod_dfe_empresa = c.cod_dfe_empresa
                        where e.nro_empresa = 900);

delete from poseidon.dpc_dfe_cte
 where cod_dfe_empresa in (select cod_dfe_empresa
                             from poseidon.dpc_dfe_empresa
                            where nro_empresa = 900);

delete from poseidon.dpc_dfe_nfse
 where cod_dfe_empresa in (select cod_dfe_empresa
                             from poseidon.dpc_dfe_empresa
                            where nro_empresa = 900);

delete from poseidon.dpc_dfe_documento
 where cod_dfe_empresa in (select cod_dfe_empresa
                             from poseidon.dpc_dfe_empresa
                            where nro_empresa = 900);

delete from poseidon.dpc_dfe_execucao
 where cod_dfe_empresa in (select cod_dfe_empresa
                             from poseidon.dpc_dfe_empresa
                            where nro_empresa = 900);

-- O cursor sai DEPOIS de documento e execucao (DPC_DFE_DOCUMENTO_FK2 aponta
-- para ele) e ANTES de dpc_dfe_empresa (DPC_DFE_CURSOR_FK1). Era esta linha que
-- faltava na versao anterior.
delete from poseidon.dpc_dfe_cursor
 where cod_dfe_empresa in (select cod_dfe_empresa
                             from poseidon.dpc_dfe_empresa
                            where nro_empresa = 900);

-- ---------------------------------------------------------------------------
--  3. Cadastro
-- ---------------------------------------------------------------------------
delete from poseidon.dpc_dfe_empresa            where nro_empresa = 900;
delete from poseidon.dpc_conta_certif_digital_emp where cod_empresa = 900;
delete from consinco.ge_empresa                 where nroempresa  = 900;

-- CORRIGIDO EM 20/08/2026. A versao anterior deste comentario dizia que a pessoa
-- "nao reverte 100%", citando triggers de log e replicacao. Aquilo foi inferido
-- pelo nome das triggers. Medido no banco: o residuo do insert e UMA linha em
-- consinco.ge_pessoacadastro, e a FK dela (SYS_C00172785) e ON DELETE CASCADE -
-- sai junto. A trigger de delete LIMPA seis tabelas de log, e o registro que ela
-- acrescenta (GE_LOGEXCLUIPESSOA) e condicionado a pessoa FISICA, o que nao e o
-- caso. A reversao e limpa. Detalhamento no 06_reverter_consinco_all_cars_tst.sql.
delete from consinco.ge_pessoa
 where nrocgccpf = '456944070001'
   and digcgccpf = 2
   and usuinclusao = 'TESTE DFE';   -- trava: so remove o que ESTE teste criou

commit;

-- ---------------------------------------------------------------------------
--  4. ALTERNATIVA: manter o acervo, apenas parar de consultar a SEFAZ
-- ---------------------------------------------------------------------------
--  Use ESTE trecho no lugar das secoes 2 e 3 se quiser continuar reprocessando
--  o parser contra os brutos ja capturados (dfe:normalizar nao fala com a SEFAZ).
--
--  ATENCAO: status_sincronismo saiu de dpc_dfe_empresa para dpc_dfe_cursor no
--  alter_v2 - a empresa passou a ser identidade fiscal e o estado de leitura foi
--  para o cursor, um por empresa E tipo. O update abaixo pausa os QUATRO fluxos.
--
--  update poseidon.dpc_dfe_cursor
--     set status_sincronismo = 'P',
--         dsc_ultimo_motivo  = 'pausado: cadastro de teste',
--         updated_at         = sysdate,
--         updated_by         = 'TESTE DFE'
--   where cod_dfe_empresa in (select cod_dfe_empresa
--                               from poseidon.dpc_dfe_empresa
--                              where nro_empresa = 900);
--  commit;

-- ---------------------------------------------------------------------------
--  5. Conferencia: as 3 contagens devem ser 0
-- ---------------------------------------------------------------------------
select (select count(*) from consinco.ge_empresa where nroempresa = 900) as ge_empresa,
       (select count(*) from poseidon.dpc_conta_certif_digital_emp where cod_empresa = 900) as certificado,
       (select count(*) from poseidon.dpc_dfe_empresa where nro_empresa = 900) as dfe_empresa,
       (select count(*) from consinco.ge_pessoa
         where nrocgccpf = '456944070001' and digcgccpf = 2) as ge_pessoa,
       (select count(*) from poseidon.dpc_dfe_cursor c
         where c.cod_dfe_empresa not in (select cod_dfe_empresa
                                           from poseidon.dpc_dfe_empresa)) as cursor_orfao
  from dual;
