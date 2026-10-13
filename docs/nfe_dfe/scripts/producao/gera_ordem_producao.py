# -*- coding: utf-8 -*-
"""Gera producao/rodar_em_ordem/: copias NUMERADAS, na ordem exata de execucao.

ddl/ continua sendo o UNICO caminho de instalacao (os nomes 01_01, 04_02... sao
citados pelos rollbacks e pelo hub). Esta pasta existe so para o DBeaver listar
os arquivos na ordem em que se roda. Nunca edite aqui: edite a origem e rode

    python gera_ordem_producao.py          # regera
    python gera_ordem_producao.py --confere   # so confere se esta em dia (exit 1 se nao)
"""
import os
import shutil
import sys

AQUI = os.path.dirname(os.path.abspath(__file__))
DDL = os.path.join(AQUI, '..', 'ddl')
AJ = os.path.join(AQUI, '..', 'ajustes_unicos')
DEST = os.path.join(AQUI, 'rodar_em_ordem')

# (nome novo, origem)
ORDEM = [
    ('00_HOMOLOG_param_replicacao_prd_dbeaver.sql', os.path.join(AJ, '2026-10-07_param_replicacao_prd.sql')),
    ('01_drop_orfas_prd_dbeaver.sql',               os.path.join(AQUI, 'P1_01_drop_orfas_prd_dbeaver.sql')),
    ('02_estrutura_motor_dbeaver.sql',              os.path.join(DDL, '01_01_estrutura_dbeaver.sql')),
    ('03_telas_parametrizacao_dbeaver.sql',         os.path.join(DDL, '03_01_parametrizacao_telas_dbeaver.sql')),
    ('04_manifestacao_dbeaver.sql',                 os.path.join(DDL, '04_01_manifestacao_dbeaver.sql')),
    ('05_manifestacao_fases_2a4_dbeaver.sql',       os.path.join(DDL, '04_02_manifestacao_fases_2a4_dbeaver.sql')),
    ('06_colunas_usuario_dbeaver.sql',              os.path.join(DDL, '06_01_colunas_usuario_dbeaver.sql')),
    ('07_nfse_tipo_emissao_dbeaver.sql',            os.path.join(DDL, '07_01_nfse_tipo_emissao_dbeaver.sql')),
    ('08_nfe_satelites_dbeaver.sql',                os.path.join(DDL, '08_01_nfe_satelites_dbeaver.sql')),
    ('09_nfe_volume_listas_dbeaver.sql',            os.path.join(DDL, '08_02_nfe_volume_listas_dbeaver.sql')),
    ('10_cte_conferencia_mensal_dbeaver.sql',       os.path.join(DDL, '09_01_cte_conferencia_mensal_dbeaver.sql')),
    ('11_relatorio_colunas_dbeaver.sql',            os.path.join(DDL, '10_01_relatorio_colunas_dbeaver.sql')),
    ('12_modelos_usuario_dbeaver.sql',              os.path.join(DDL, '11_01_modelos_usuario_dbeaver.sql')),
    ('13_nota_cfop_xml_dbeaver.sql',                os.path.join(DDL, '12_01_nota_cfop_xml_dbeaver.sql')),
    ('14_manifestacao_pedido_dbeaver.sql',          os.path.join(DDL, '13_01_manifestacao_pedido_dbeaver.sql')),
    ('15_usuario_aba_propria_dbeaver.sql',          os.path.join(DDL, '14_01_usuario_aba_propria_dbeaver.sql')),
    ('16_parametros_prd_dbeaver.sql',               os.path.join(AQUI, 'P1_02_parametros_prd_dbeaver.sql')),
]


def main():
    confere = '--confere' in sys.argv
    os.makedirs(DEST, exist_ok=True)
    atrasados = []
    for nome, origem in ORDEM:
        if not os.path.exists(origem):
            sys.exit('origem ausente: ' + origem)
        destino = os.path.join(DEST, nome)
        igual = os.path.exists(destino) and open(origem, 'rb').read() == open(destino, 'rb').read()
        if confere:
            if not igual:
                atrasados.append(nome)
        elif not igual:
            shutil.copyfile(origem, destino)
            print('copiado ', nome)
    # sobras (arquivo que saiu da lista)
    esperados = {n for n, _ in ORDEM}
    for f in os.listdir(DEST):
        if f.endswith('.sql') and f not in esperados:
            atrasados.append('SOBRA ' + f) if confere else (os.remove(os.path.join(DEST, f)), print('removido', f))
    if confere:
        if atrasados:
            print('FORA DE DIA:', ', '.join(atrasados))
            sys.exit(1)
        print('rodar_em_ordem esta em dia com as origens (%d arquivos)' % len(ORDEM))
    else:
        print('ok: %d arquivos em %s' % (len(ORDEM), DEST))


if __name__ == '__main__':
    main()
