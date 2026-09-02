-- ============================================================================
--  01 - certificado da empresa 30 (DPC Mato Grosso do Sul)
-- ============================================================================
--  CNPJ 66.471.517/0030-01 - raiz 66471517, a mesma da matriz.
--
--  NAO precisa de arquivo nem de senha: o e-CNPJ A1 da matriz serve para todas
--  as filiais de mesma raiz. Este script COPIA a linha da empresa 1, que e a que
--  tem o certificado renovado e valido (ate 20/10/2026).
--
--  Copiar em vez de reinserir tem duas vantagens:
--    - o base64 do PFX vai identico, sem risco de truncamento
--    - senha_certificado ja esta no formato da dpcf_convertesenhas; copiar o
--      valor pronto evita reconverter e errar
--
--  cod_certi_digital nao vai no insert: a trigger DPCT_CONTA_CERTIF_DIGITAL_EMP
--  preenche pela sequence.
-- ============================================================================

insert into poseidon.dpc_conta_certif_digital_emp
  (cod_empresa, emitir_cte, consultar_distri_dfe, nome_arquivo,
   certificado, tamanho, senha_certificado, status, created_at, created_by)
select 30,
       0,
       1,                       -- consultar_distri_dfe: participa da captura
       c.nome_arquivo,
       c.certificado,
       c.tamanho,
       c.senha_certificado,     -- valor JA convertido, copiado como esta
       1,
       sysdate,
       'CADASTRO DFE'
  from poseidon.dpc_conta_certif_digital_emp c
 where c.cod_empresa = 1
   and c.status = 1
   and not exists (select 1
                     from poseidon.dpc_conta_certif_digital_emp
                    where cod_empresa = 30
                      and status = 1);

commit;

-- ---------------------------------------------------------------------------
--  Conferencia: mesmo tamanho e mesma senha que a empresa 1
-- ---------------------------------------------------------------------------
--  ESPERADO: 2 linhas com tamanho e senha_lida identicos.
select cod_certi_digital, cod_empresa, tamanho,
       dbms_lob.getlength(certificado) as tam_base64,
       consinco.dpcf_desconvertesenhas(senha_certificado) as senha_lida,
       consultar_distri_dfe, status
  from poseidon.dpc_conta_certif_digital_emp
 where cod_empresa in (1, 30)
   and status = 1
 order by cod_empresa;
