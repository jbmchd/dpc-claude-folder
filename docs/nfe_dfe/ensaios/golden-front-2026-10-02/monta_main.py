"""Reconstroi o Main.vue da NF-e sobre a casca TelaDocumentoFiscal.

As constantes de dominio (abas, catalogo, rotulos) sao copiadas EXATAMENTE do
arquivo original, por intervalo de linhas conferido.
"""
import subprocess

REPO = r"D:\joabe\Documents\dev\projetos\dpc\workspace\DPC"
ARQ = REPO + r"\src\app\sefaz\documentos\nfe\components\Main.vue"

orig = subprocess.run(["git", "-C", REPO, "show", "HEAD:src/app/sefaz/documentos/nfe/components/Main.vue"],
                      capture_output=True, text=True, encoding="utf-8").stdout.split("\n")


def trecho(ini, fim, espera):
    bloco = orig[ini - 1:fim]
    assert bloco[0].strip().startswith(espera), (ini, bloco[0], espera)
    return "\n".join(bloco)


TEMPLATE = '''<template>
  <div id="sefaz-documentos-nfe">
    <TelaDocumentoFiscal :config="config" @ver-documento="verNota($event)">

      <!-- Manifestacao manual (Fase 4) - so aparece com a permissao concedida
           em Sefaz > Parametros. A ApiNFE reconfere tudo de novo no envio. -->
      <template slot="acoes-extras" slot-scope="acoes">
        <button
          v-if="acoes.metadados.pode_manifestar === true"
          class="btn btn-danger btn-sm"
          @click="abrirManifestar(acoes)"
          :disabled="acoes.qtdSelecionadas === 0"
          title="Manifestar as notas selecionadas na SEFAZ"
        >
          <i class="fas fa-stamp" aria-hidden="true"></i> Manifestar
        </button>
      </template>

      <!-- Celulas com badge proprio da NF-e (ver CAMPOS_COM_CELULA) -->
      <template slot="celula" slot-scope="{ props }">
        <span v-if="props.column.field === 'cod_manifestacao_br'">
          <span
            class="badge"
            :class="badgeManifestacao(props.row)"
            :title="tituloManifestacao(props.row)"
          >
            {{ rotuloManifestacao(props.row) }}
          </span>
        </span>
        <span v-else-if="props.column.field === 'status_recebimento_br'">
          <span class="badge" :class="props.row.status_recebimento === 'S' ? 'badge-nfe-sync' : 'badge-nfe-nosync'">
            {{ props.row.status_recebimento === 'S' ? 'SINCRONIZADO' : 'NÃO SINCRONIZADO' }}
          </span>
        </span>
      </template>

      <!-- Modais da NF-e -->
      <template slot="modais" slot-scope="tela">
        <ModalFiltros
          v-if="tela.modalFiltrosAberto"
          :filtrosAtuais="tela.filtrosAvancados"
          :cfopOptions="cfopOptions(tela.linhas)"
          @aplicar="tela.aplicarFiltrosAvancados($event)"
          @close="tela.fecharModalFiltros()"
        />

        <ModalDetalheNota
          v-if="showModalDetalhe"
          :nota="notaSelecionada"
          @close="showModalDetalhe = false"
        />

        <ModalManifestar
          v-if="showModalManifestar"
          :chaves="tela.chavesSelecionadas"
          @manifestado="aoManifestar(tela)"
          @close="showModalManifestar = false"
        />
      </template>
    </TelaDocumentoFiscal>
  </div>
</template>

<script>
/**
 * Monitor NF-e (card #3280). Replica a tela "Documentos > NF-e" da Qive.
 *
 * A casca comum as telas de documento fiscal (empresa, abas, busca, periodo,
 * totais, selecao, colunas, exportacao, baixar/compartilhar, grade) esta em
 * ../../comum/TelaDocumentoFiscal.vue. Aqui fica o que e da NF-e: catalogo de
 * colunas, abas por papel, decorador da linha, manifestacao e os modais de
 * filtro, detalhe e manifestar.
 */
import bus from "@/utils/events/bus";
import TelaDocumentoFiscal from "../../comum/TelaDocumentoFiscal.vue";
import {
  formataData, formataMesAno, formataMoeda, formataCnpj,
} from "../../comum/formatadores";
import ModalFiltros from "./modal/ModalFiltros.vue";
import ModalDetalheNota from "./modal/ModalDetalheNota.vue";
import ModalManifestar from "./modal/ModalManifestar.vue";
'''

partes = [TEMPLATE]
partes.append(trecho(358, 360, "/** Chave do localStorage"))
partes.append(trecho(364, 526, "/** Espelha DfeManifestacaoController"))

partes.append('''
/** Filtros do modal no estado inicial (e o que "Limpar filtros" restaura). */
const FILTROS_VAZIOS = {
  cod_situacao: null,
  manifestacao: null,
  dsc_tipo_doc: null,
  protocolada: null,
  status_recebimento: null,
  nro_serie: null,
  valor_de: null,
  valor_ate: null,
  cfops: null,
};

const CAMPOS_BUSCA = [
  { valor: "todos",   rotulo: "Todos os campos",       placeholder: "Busque por chave, número, nome ou CNPJ do emitente" },
  { valor: "empresa", rotulo: "Nome/CNPJ da Empresa",  placeholder: "Digite o nome ou CNPJ do emitente" },
  { valor: "chave",   rotulo: "Chave de Acesso",       placeholder: "Digite a chave de acesso (44 dígitos)" },
  { valor: "numero",  rotulo: "Número da NF-e",        placeholder: "Digite o número da NF-e" },
];

/** Colunas que a NF-e desenha pelo slot "celula" da casca. */
const CAMPOS_COM_CELULA = ["cod_manifestacao_br", "status_recebimento_br"];

export default {
  name: "SefazDocumentosNfe",
  components: {
    TelaDocumentoFiscal, ModalFiltros, ModalDetalheNota, ModalManifestar,
  },

  data() {
    return {
      config: {
        idTela: "sefaz-nfe",
        titulo: "NF-e (Nota Fiscal Eletrônica)",
        subtitulo: "Documentos capturados da SEFAZ",
        rotulo: "NF-e",
        endpoint: "/documentos/nfe",
        tela: "NFE",
        chaveColunas: CHAVE_COLUNAS,
        catalogo: CATALOGO_COLUNAS,
        colunasPadrao: COLUNAS_PADRAO.slice(),
        // A coluna "Manifestação" se chamava status_manifestacao: quem ja
        // tinha salvo preferencia a perderia em silencio sem esta traducao.
        migracaoColunas: { status_manifestacao: "cod_manifestacao_br" },
        abas: ABAS,
        camposBusca: CAMPOS_BUSCA,
        rotuloPeriodo: "Período de emissão:",
        campoChave: "chave_nf",
        ordemPadrao: { coluna: "dta_emissao", campoGrid: "dta_emissao_br" },
        rotuloPdf: "DANFE",
        nomeZipPdf: "danfes.zip",
        arquivoExportacao: "nfe-sefaz.xlsx",
        abaExportacao: "NF-e",
        temFiltros: true,
        filtrosVazios: FILTROS_VAZIOS,
        rotulosFiltros: ROTULOS_FILTROS,
        valoresFiltros: VALORES_FILTROS,
        camposComCelula: CAMPOS_COM_CELULA,
        decorar: this.decoraNota,
        rotuloSituacao: this.rotuloSituacao,
      },

      // Modais da NF-e
      showModalDetalhe: false,
      showModalManifestar: false,
      notaSelecionada: null,
    };
  },

  methods: {
    /** CFOPs presentes nas notas carregadas, para alimentar o treeselect do filtro. */
    cfopOptions(notas) {
      var vistos = {};
      notas.forEach(function(nota) {
        if (!nota.cfop) return;
        nota.cfop.split(",").forEach(function(cfop) {
          var limpo = cfop.trim();
          if (limpo) vistos[limpo] = true;
        });
      });
      return Object.keys(vistos)
        .sort()
        .map(function(cfop) {
          return { id: cfop, label: cfop };
        });
    },
''')

# decoraNota (902-952) - troca this.formataX pelas funcoes importadas
bloco = trecho(902, 952, "/** Acrescenta os campos formatados")
for nome in ["formataData", "formataMesAno", "formataMoeda", "formataCnpj"]:
    bloco = bloco.replace("this." + nome + "(", nome + "(")
partes.append(bloco + "\n")

partes.append('''    verNota(nota) {
      this.notaSelecionada = nota;
      this.showModalDetalhe = true;
    },

''')

# abrirManifestar (1277-1297) recebe o escopo do slot
bloco = trecho(1277, 1297, "/**")
bloco = bloco.replace("    abrirManifestar() {\n      this.fecharMenus();\n      if (this.qtdSelecionadas === 0) {",
                      "    abrirManifestar(acoes) {\n      acoes.fecharMenus();\n      if (acoes.qtdSelecionadas === 0) {", 1)
bloco = bloco.replace("      if (this.qtdSelecionadas > MAX_CHAVES_MANIFESTAR) {",
                      "      if (acoes.qtdSelecionadas > MAX_CHAVES_MANIFESTAR) {", 1)
bloco = bloco.replace('"(limite da SEFAZ para o envio em lote). Você selecionou " + this.qtdSelecionadas + ".",',
                      '"(limite da SEFAZ para o envio em lote). Você selecionou " + acoes.qtdSelecionadas + ".",', 1)
assert "this.qtdSelecionadas" not in bloco and "this.fecharMenus" not in bloco
partes.append(bloco + "\n")

partes.append('''
    /** Ao menos uma manifestacao foi processada: o estado da nota pode ter mudado. */
    aoManifestar(tela) {
      tela.limparSelecao();
      tela.recarregar();
    },

    // -----------------------------------------------------------------------
    // Rotulos
    // -----------------------------------------------------------------------

''')

# rotuloSituacao (1456-1461) e manifestacao (1469-1525)
partes.append(trecho(1456, 1461, "rotuloSituacao(nota)") + "\n")
partes.append(trecho(1468, 1525, "") + "\n")
partes.append('''  },
};
</script>

<style lang="scss">
/* Badges da NF-e: fora do scoped porque a vue-good-table renderiza em slot.
   Os de situacao (autorizada/cancelada/denegada) sao da casca. */
#sefaz-documentos-nfe {
''')
partes.append(trecho(1770, 1780, "// Manifestacao: 4 eventos"))
partes.append('''}
</style>
''')

texto = "\n".join(partes)
open(ARQ, "w", encoding="utf-8", newline="\n").write(texto)
print("linhas:", texto.count("\n"))
