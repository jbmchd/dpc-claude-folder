async () => {
  // ---------------------------------------------------------------- apoio
  if (!window.__pend) {
    window.__pend = 0;
    const abre = XMLHttpRequest.prototype.send;
    XMLHttpRequest.prototype.send = function () {
      window.__pend++;
      this.addEventListener("loadend", () => { window.__pend--; });
      return abre.apply(this, arguments);
    };
    window.__exports = [];
    const criar = URL.createObjectURL;
    URL.createObjectURL = function (blob) {
      const r = new FileReader();
      r.onload = () => window.__exports.push({ tipo: blob.type, tam: blob.size, b64: String(r.result).split(",")[1] });
      r.readAsDataURL(blob);
      return criar.call(URL, blob);
    };
    HTMLAnchorElement.prototype.click = function () { window.__ultimoDownload = this.download; };
    window.confirm = () => true;
  }
  const dorme = (ms) => new Promise((r) => setTimeout(r, ms));
  const quieto = async () => {
    await dorme(150);
    let calmo = 0;
    for (let i = 0; i < 300 && calmo < 6; i++) { await dorme(100); calmo = window.__pend === 0 ? calmo + 1 : 0; }
    await dorme(150);
  };
  const tela = () => document.querySelector("#sefaz-documentos-nfe");
  const txt = (el) => (el ? el.innerText.replace(/\s+/g, " ").trim() : null);
  const porTexto = (sel, texto, raiz) =>
    Array.from((raiz || document).querySelectorAll(sel)).find((e) => txt(e).indexOf(texto) !== -1);
  const clica = async (el) => { if (!el) throw new Error("elemento nao encontrado"); el.click(); await quieto(); };
  const estilo = (el, p) => (el ? getComputedStyle(el)[p] : null);

  const foto = () => {
    const t = tela();
    const tabela = t.querySelector("table");
    const linhas = tabela ? Array.from(tabela.querySelectorAll("tbody tr")).slice(0, 8) : [];
    return {
      cabecalho: txt(t.querySelector("h3")) + " | " + txt(t.querySelector("h3 + p")),
      ultimaConsulta: !!porTexto("span", "Última consulta", t),
      abas: Array.from(t.querySelectorAll(".nav-tabs > li")).map((li) => (li.classList.contains("active") ? "*" : "") + txt(li)),
      totalizador: txt(porTexto("div", "Valor total das", t) && Array.from(t.querySelectorAll("div")).filter((d) => txt(d).indexOf("Valor total das") === 0).pop()),
      selecao: txt(porTexto("button", "Selecionar todas", t)),
      botoes: Array.from(t.querySelectorAll("button")).filter((b) => b.offsetParent).map((b) => txt(b) + (b.disabled ? "[off]" : "")).filter(Boolean),
      chips: Array.from(t.querySelectorAll(".chip-filtro")).map(txt),
      colunas: tabela ? Array.from(tabela.querySelectorAll("thead th")).map(txt) : [],
      linhas: linhas.map((tr) => Array.from(tr.querySelectorAll("td")).map(txt)),
      badges: linhas.slice(0, 5).map((tr) => Array.from(tr.querySelectorAll(".badge")).map((b) => txt(b) + "/" + estilo(b, "backgroundColor"))),
      vazio: txt(porTexto("h4", "Nenhum documento", t)),
      dica: !!porTexto("div", "Não encontra um documento", t),
      paginacao: txt(t.querySelector(".indice-paginacao")),
    };
  };

  const r = {};
  await quieto();

  r.inicial = foto();
  r.buscaOpcoes = Array.from(tela().querySelectorAll("select")[0].options).map((o) => o.text);
  r.periodoOpcoes = Array.from(tela().querySelectorAll("select")[1].options).map((o) => o.text);
  r.placeholder = tela().querySelector("input[type=text]").placeholder;

  // abas
  r.abas = {};
  for (const nome of ["Emitidas", "Transporte", "Citadas", "Indefinidas", "Recebidas"]) {
    await clica(porTexto(".nav-tabs a", nome, tela()));
    const f = foto();
    r.abas[nome] = { totalizador: f.totalizador, vazio: f.vazio, primeira: f.linhas[0] || null };
  }

  // ordenacao pelo cabecalho Valor (2 cliques)
  const thValor = () => Array.from(tela().querySelectorAll("thead th")).find((th) => txt(th) === "Valor");
  await clica(thValor());
  r.ordemValor1 = foto().linhas.map((l) => l[4]);
  await clica(thValor());
  r.ordemValor2 = foto().linhas.map((l) => l[4]);

  // pagina 2
  await clica(tela().querySelector(".pagination li:last-child a"));
  r.pagina2 = { paginacao: foto().paginacao, primeira: foto().linhas[0] };

  // busca
  const campo = tela().querySelector("input[type=text]");
  campo.value = "WELLA"; campo.dispatchEvent(new Event("input"));
  await clica(tela().querySelector("button[title=Buscar]"));
  r.busca = { totalizador: foto().totalizador, primeira: foto().linhas[0] };
  campo.value = ""; campo.dispatchEvent(new Event("input"));
  await clica(tela().querySelector("button[title=Buscar]"));

  // escopo da busca muda o placeholder
  const escopo = tela().querySelectorAll("select")[0];
  escopo.value = "chave"; escopo.dispatchEvent(new Event("change"));
  await dorme(100);
  r.placeholderChave = tela().querySelector("input[type=text]").placeholder;
  escopo.value = "todos"; escopo.dispatchEvent(new Event("change"));

  // filtro avancado + chip + remover chip
  await clica(tela().querySelector("button[title=Filtros]"));
  const sel = porTexto(".modal-container .form-group", "Status").querySelector("select");
  sel.value = "3"; sel.dispatchEvent(new Event("change"));
  await clica(porTexto(".modal-container button", "Aplicar"));
  r.filtroCanceladas = { chips: foto().chips, totalizador: foto().totalizador, badgeFiltros: txt(tela().querySelector(".badge-filtros")), primeira: foto().linhas[0], badges: foto().badges };
  await clica(tela().querySelector(".chip-filtro i"));
  r.semChip = { chips: foto().chips, totalizador: foto().totalizador };

  // selecao de uma linha + cor da linha selecionada
  const cb = tela().querySelector("tbody input[type=checkbox]");
  cb.click(); await dorme(200);
  const tr = cb.closest("tr");
  tr.click(); await dorme(200);
  r.selecaoUma = { selecao: foto().selecao, botoes: foto().botoes, classeLinha: tr.className, fundo: estilo(tr.querySelector("td"), "backgroundColor"), cor: estilo(tr.querySelector("td"), "color") };
  cb.click(); await dorme(200);

  // selecionar todas
  await clica(porTexto("button", "Selecionar todas", tela()));
  r.selecaoTodas = foto().selecao;
  await clica(porTexto("button", "Selecionar todas", tela()));
  r.selecaoLimpa = foto().selecao;

  // modal de colunas: Completo e volta ao Padrao
  await clica(porTexto("button", "Colunas", tela()));
  r.modalColunas = { titulo: txt(document.querySelector(".modal-container .titulo-modal")), visoes: txt(porTexto(".modal-container div", "Visões:") && document.querySelector(".visoes-colunas")) };
  await clica(porTexto(".modal-container button", "Completo"));
  await clica(porTexto(".modal-container button", "Confirmar"));
  r.colunasCompleto = foto().colunas;
  await clica(porTexto("button", "Colunas", tela()));
  await clica(porTexto(".modal-container button", "Padrão"));
  await clica(porTexto(".modal-container button", "Confirmar"));
  r.colunasPadrao = foto().colunas;

  // exportar colunas selecionadas no mes anterior
  const periodo = tela().querySelectorAll("select")[1];
  periodo.value = "mesAnterior"; periodo.dispatchEvent(new Event("change"));
  await quieto();
  r.mesAnterior = foto().totalizador;
  window.__exports = [];
  await clica(porTexto("button", "Relatórios", tela()));
  await clica(porTexto(".dropdown-menu a", "Exportar colunas selecionadas", tela()));
  await dorme(800);
  r.exportacao = { arquivo: window.__ultimoDownload, blobs: window.__exports.map((e) => ({ tipo: e.tipo, tam: e.tam })) };
  r.exportacaoB64 = window.__exports.length ? window.__exports[0].b64 : null;
  periodo.value = "90dias"; periodo.dispatchEvent(new Event("change"));
  await quieto();

  // ver nota
  await clica(tela().querySelector("button[title='Ver nota']"));
  await dorme(500);
  r.detalhe = { titulo: txt(document.querySelector(".modal-container .titulo-modal")), abas: Array.from(document.querySelectorAll(".modal-container .nav-tabs li")).map(txt) };
  await clica(document.querySelector(".modal-container .modal-top-header button"));
  r.depoisDetalhe = !!document.querySelector(".modal-container");

  return r;
}
