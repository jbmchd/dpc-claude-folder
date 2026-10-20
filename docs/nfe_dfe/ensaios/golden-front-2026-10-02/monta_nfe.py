"""Reconstroi SefazNfeRepository como filha de SefazDocumentoRepository.

Copia trechos EXATOS do arquivo original (por intervalo de linhas, conferindo
a primeira linha de cada trecho) para nao reescrever logica a mao.
"""
import subprocess

REPO = r"D:\joabe\Documents\dev\projetos\dpc\workspace\ApiDPC"
ARQ = REPO + r"\app\Repositories\SefazNfeRepository.php"

orig = subprocess.run(["git", "-C", REPO, "show", "HEAD:app/Repositories/SefazNfeRepository.php"],
                      capture_output=True, text=True, encoding="utf-8").stdout.split("\n")


def trecho(ini, fim, espera):
    """Linhas ini..fim (1-based, inclusive). espera = inicio da primeira linha."""
    bloco = orig[ini - 1:fim]
    assert bloco[0].strip().startswith(espera), (ini, bloco[0], espera)
    return "\n".join(bloco)


partes = []

partes.append('''<?php

namespace App\\Repositories;

use Illuminate\\Support\\Facades\\DB;
use Tymon\\JWTAuth\\Facades\\JWTAuth;

/**
 * Repositorio da listagem de NF-e capturadas da SEFAZ (card #3280).
 *
 * Le o modulo DFe (poseidon.dpc_dfe_*), alimentado pelos commands da ApiNFE
 * (dfe:ingerir / dfe:normalizar / dfe:conciliar). Replica a tela
 * "Documentos > NF-e" da Qive.
 *
 * A casca comum as tres telas de documento (permissao, paginacao, totais,
 * exportacao, XML, ZIP, e-mail) mora em SefazDocumentoRepository. Aqui fica so
 * o que e da NF-e: a consulta, as colunas, as abas, manifestacao, detalhe com
 * itens e eventos, e a DANFE.
 *
 * SOMENTE LEITURA, de proposito. Nenhum metodo aqui escreve NSU, manifesta ou
 * dispara consulta a SEFAZ: reposicionar NSU devolve cStat 656 e bloqueia o
 * certificado por 1 hora para TODAS as filiais que compartilham o e-CNPJ.
 * Ver .claude-work-items/nfe/sefaz-656-consumo-indevido.md
 *
 * Decisoes registradas:
 *   - Permissao: reusa poseidon.dpc_dfe_usuario_empresa (mesma governanca do
 *     card #3235). NAO usa dpc_dfe_usuario_aba: categoria (DEVOLUCAO/COMPRAS/
 *     SUPRIMENTOS) e conceito do dashboard, nao desta listagem.
 *   - CFOP vem de dpc_dfe_nota_item (multivalorado por nota) via subquery
 *     correlacionada com LISTAGG DISTINCT. Nota resNFe nao tem item => null.
 *   - Abas por papel: filtram DPC_DFE_NOTA.SIG_PAPEL_EMPRESA, preenchido pelo
 *     dfe:normalizar da ApiNFE. Ver mapaDeAbas().
 *   - XML: join documento x nota por CHAVE_NF + EMPRESA. A tabela
 *     dpc_dfe_documento NAO tem cod_dfe_nota.
 */
class SefazNfeRepository extends SefazDocumentoRepository
{''')

# constantes de evento e prazo (sem os tetos, que foram para a base)
partes.append(trecho(36, 63, "/**"))

partes.append('''
    // =========================================================================
    // Contrato com SefazDocumentoRepository
    // =========================================================================

    public function tipoDfe()
    {
        return 'NFE';
    }

    protected function colunaValor()
    {
        return 'vlr_nota';
    }

    protected function colunaChave()
    {
        return 'chave_nf';
    }

    protected function campoOrdemPadrao()
    {
        return 'dta_emissao';
    }

    protected function colunaDesempate()
    {
        return 'n.cod_dfe_nota';
    }

    /** Completo (procNF) antes do resumo (resNFe). */
    protected function tiposDocumentoXml()
    {
        return ['procNF', 'resNFe'];
    }

    protected function rotuloPdf()
    {
        return 'DANFE';
    }

    protected function mensagemSemPdf()
    {
        return 'Nenhuma das notas selecionadas tem XML completo — sem ele nao existe DANFE.';
    }

    protected function mensagemPdfIgnorados($ignorados)
    {
        return $ignorados . ' nota(s) ficaram de fora por terem apenas o resumo da SEFAZ.';
    }

    /**
     * Governa so a VISIBILIDADE do botao de manifestar (Fase 4). A ApiNFE
     * reconfere tudo no envio - ver DfeManifestacaoController@manifestar.
     */
    public function metadadosListagem()
    {
        return ['pode_manifestar' => $this->podeManifestar()];
    }
''')

# podeManifestar
partes.append(trecho(149, 176, "/**"))

# docblock de papeis vira mapaDeAbas
partes.append('''
    /**
     * Papeis de SIG_PAPEL_EMPRESA que cada aba da tela mostra. A primeira e a
     * padrao (ver SefazDocumentoRepository::papeisDaAba).
     *
     * Dominio preenchido pelo dfe:normalizar da ApiNFE:
     *   DEST   destinataria   EMIT  emitente     TRANSP transportadora
     *   AUTXML citada         OUTRO CNPJ lido, sem papel conhecido
     *   INDEF  papel indeterminavel (tipico de resNFe: o resumo nao traz os papeis)
     *
     * INDEF ganha aba propria de proposito. Jogar essas notas em "Recebidas"
     * afirmaria algo que o documento nao diz; escondê-las sumiria com nota real —
     * e elas serao comuns, porque o resumo chega antes do XML completo e as vezes
     * o completo nunca chega. Mesmo tratamento que SEM_CLASSIFICACAO no card #3235.
     *
     * OUTRO fica fora das abas: ali a informacao existia, foi lida, e o CNPJ nao
     * esta em nenhum papel conhecido.
     *
     * @return array
     */
    protected function mapaDeAbas()
    {
        return [
            'recebidas'    => ['DEST'],
            'emitidas'     => ['EMIT'],
            'transporte'   => ['TRANSP'],
            'citadas'      => ['AUTXML'],
            'indefinidas'  => ['INDEF'],
        ];
    }
''')

# subqueries de manifestacao e documento completo + cabecalho de queryBase
partes.append(trecho(238, 339, "// ====="))
bloco = trecho(340, 614, "private function queryBase")
bloco = bloco.replace("    private function queryBase(array $params, array $empresas)",
                      "    protected function queryBase(array $params, array $empresas)", 1)
partes.append(bloco)

# allowlist
bloco = trecho(645, 680, "/** Colunas liberadas")
bloco = bloco.replace("    private function colunasOrdenaveis()", "    protected function colunasOrdenaveis()", 1)
partes.append("\n" + bloco)

# montaLinha (docblock 762)
bloco = trecho(762, 817, "/**")
bloco = bloco.replace("    private function montaLinha($row)", "    protected function montaLinha($row)", 1)
partes.append("\n" + bloco)

# detalhe e montadores
bloco = trecho(876, 1081, "// =====")
bloco = bloco.replace("     * @param  int  $codDfeNota\n     * @return array|null\n     */\n    public function detalhe($codDfeNota)",
                      "     * @param  int  $codDfeNota\n     * @return array|null\n     */\n    public function detalhe($codDfeNota)", 1)
partes.append("\n" + bloco)

# DANFE: cabecalho da secao + danfe() (xml() foi para a base)
partes.append('''
    // =========================================================================
    // DANFE
    // =========================================================================
''')
partes.append(trecho(1138, 1176, "/**"))

bloco = trecho(1346, 1389, "/**")
bloco = bloco.replace("     * Renderiza a DANFE de um XML. Devolve null quando nao e NF-e completa.",
                      "     * Renderiza a DANFE de um XML. Devolve null quando nao e NF-e completa\n"
                      "     * (resNFe so tem o resumo: a DANFE nao tem o que desenhar).", 1)
bloco = bloco.replace("    private function renderizaDanfe($xml)", "    protected function renderizaPdf($xml)", 1)
partes.append("\n" + bloco)

texto = "\n".join(partes) + "\n}\n"
texto = texto.replace("$this->renderizaDanfe(", "$this->renderizaPdf(")

open(ARQ, "w", encoding="utf-8", newline="\n").write(texto)
print("linhas:", texto.count("\n"))
