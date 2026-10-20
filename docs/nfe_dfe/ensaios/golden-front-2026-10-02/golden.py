"""Golden test da listagem de NF-e (Fase B).

    python golden.py capturar <pasta>
    python golden.py comparar <pastaA> <pastaB>

Captura as respostas da ApiDPC LOCAL para um conjunto fixo de requisicoes e
compara duas capturas campo a campo, ignorando so os campos que mudam sozinhos
(conciliacao com o ERP roda a cada 30 min).
"""
import base64
import hashlib
import io
import json
import os
import sys
import urllib.parse
import urllib.request
import zipfile

BASE = os.environ.get("GOLDEN_BASE", "http://devdpc.local:8004/api/sefaz/documentos/nfe")
TOKEN = json.load(open(r"C:/Users/joabe/AppData/Roaming/dpc-dev-box/token-apidpc.json"))["token"]
AQUI = os.path.dirname(os.path.abspath(__file__))

# Campos que a conciliacao com o ERP reescreve sozinha a cada 30 min. Nao sao
# contrato: compara-los faz toda captura feita com horas de diferenca "falhar".
VOLATEIS = {
    "updated_at", "dta_conciliacao", "dta_estado_erp", "ultima_consulta",
    "dta_entrada_erp", "dta_lancamento_erp", "sig_estado_erp", "num_estado_erp_max",
    "seq_nf_erp", "seq_notamestre_erp", "seq_comprador_erp", "dsc_comprador_erp",
    "status_recebimento",
}

# chaves e ids fixos, escolhidos uma vez e gravados (ver fixos.json)
FIXOS = json.load(open(os.path.join(AQUI, "fixos.json"))) if os.path.exists(os.path.join(AQUI, "fixos.json")) else None

SET = "2026-09-01"
SET_FIM = "2026-09-30"


def requisicoes():
    r = [
        ("lista_p1", "GET", "", {"limit": 25, "offset": 0}),
        ("lista_p2", "GET", "", {"limit": 25, "offset": 25}),
        ("aba_emitidas", "GET", "", {"limit": 25, "offset": 0, "papel": "emitidas"}),
        ("aba_transporte", "GET", "", {"limit": 25, "offset": 0, "papel": "transporte"}),
        ("aba_citadas", "GET", "", {"limit": 25, "offset": 0, "papel": "citadas"}),
        ("aba_indefinidas", "GET", "", {"limit": 25, "offset": 0, "papel": "indefinidas"}),
        ("aba_invalida", "GET", "", {"limit": 5, "offset": 0, "papel": "xpto"}),
        ("ordem_valor_asc", "GET", "", {"limit": 25, "offset": 0, "orderBy": json.dumps({"coluna": "vlr_nota", "ordem": "asc"})}),
        ("ordem_razao_desc", "GET", "", {"limit": 25, "offset": 0, "orderBy": json.dumps({"coluna": "razao_emitente", "ordem": "desc"})}),
        ("ordem_invalida", "GET", "", {"limit": 10, "offset": 0, "orderBy": json.dumps({"coluna": "1; drop", "ordem": "asc"})}),
        ("busca_todos", "GET", "", {"limit": 25, "offset": 0, "searchTerm": "WELLA", "searchScope": "todos"}),
        ("busca_numero", "GET", "", {"limit": 25, "offset": 0, "searchTerm": "12", "searchScope": "numero"}),
        ("periodo_empresa", "GET", "", {"limit": 25, "offset": 0, "de": SET, "ate": SET_FIM, "nro_empresa[]": 17}),
        ("canceladas", "GET", "", {"limit": 25, "offset": 0, "cod_situacao": 3}),
        ("manif_ciencia", "GET", "", {"limit": 25, "offset": 0, "manifestacao[]": "210210"}),
        ("manif_sem", "GET", "", {"limit": 25, "offset": 0, "manifestacao[]": "SEM_MANIFESTACAO"}),
        ("nao_recebidas", "GET", "", {"limit": 25, "offset": 0, "status_recebimento": "N"}),
        ("cfop_valor", "GET", "", {"limit": 25, "offset": 0, "cfops": "5102,6102", "valor_de": 100, "valor_ate": 5000}),
        ("empresas", "GET", "/empresas", {}),
        ("ultima_consulta", "GET", "/ultima-consulta", {}),
        ("ultima_consulta_17", "GET", "/ultima-consulta", {"nro_empresa": 17}),
        ("chaves", "GET", "/chaves", {"de": SET, "ate": SET_FIM}),
        ("exportar", "GET", "/exportar", {"de": SET, "ate": SET_FIM}),
        ("colunas", "GET", "/colunas", {"tela": "NFE"}),
    ]
    if FIXOS:
        for i in FIXOS["detalhes"]:
            r.append(("detalhe_%s" % i, "GET", "/detalhe/%s" % i, {}))
        r.append(("detalhe_inexistente", "GET", "/detalhe/999999999", {}))
        r.append(("xml", "GET", "/xml/%s" % FIXOS["chaves"][0], {}))
        r.append(("danfe", "GET", "/danfe/%s" % FIXOS["chaves"][0], {}))
        r.append(("danfe_resumo", "GET", "/danfe/%s" % FIXOS["chave_resumo"], {}))
        r.append(("zip_xml", "POST", "/zip-xml", {"chaves": FIXOS["chaves"]}))
        r.append(("zip_pdf", "POST", "/zip-pdf", {"chaves": FIXOS["chaves"] + [FIXOS["chave_resumo"]]}))
        r.append(("zip_xml_teto", "POST", "/zip-xml", {"chaves": ["1"] * 1001}))
        r.append(("email_sem_dest", "POST", "/enviar-email", {"chaves": FIXOS["chaves"], "destinatarios": [], "tipo_anexo": "xml"}))
        r.append(("email_invalido", "POST", "/enviar-email", {"chaves": FIXOS["chaves"], "destinatarios": ["nao-e-email"], "tipo_anexo": "xml"}))
        r.append(("email_teto", "POST", "/enviar-email", {"chaves": ["1"] * 51, "destinatarios": ["a@b.com"], "tipo_anexo": "pdf"}))
    return r


def chama(metodo, caminho, params):
    url = BASE + caminho
    cab = {"Authorization": "Bearer " + TOKEN, "Accept": "application/json"}
    if metodo == "GET":
        if params:
            url += "?" + urllib.parse.urlencode(params, doseq=True)
        req = urllib.request.Request(url, headers=cab)
    else:
        cab["Content-Type"] = "application/json"
        req = urllib.request.Request(url, data=json.dumps(params).encode(), headers=cab, method="POST")
    try:
        with urllib.request.urlopen(req, timeout=300) as resp:
            return resp.status, resp.read()
    except urllib.error.HTTPError as e:
        return e.code, e.read()


def sem_data_pdf(b):
    """O PDF grava a hora em que foi gerado; tira isso para comparar o conteudo."""
    import re
    b = re.sub(rb"/CreationDate\s*\([^)]*\)", b"", b)
    b = re.sub(rb"/ModDate\s*\([^)]*\)", b"", b)
    b = re.sub(rb"/ID\s*\[[^\]]*\]", b"", b)
    return b


def normaliza(nome, corpo):
    """Tira o que muda sozinho; troca binarios por algo comparavel."""
    try:
        dado = json.loads(corpo)
    except Exception:
        return {"_bruto_sha": hashlib.sha256(corpo).hexdigest()}

    def limpa(x):
        if isinstance(x, dict):
            return {k: ("<volatil>" if k in VOLATEIS else limpa(v)) for k, v in x.items()}
        if isinstance(x, list):
            return [limpa(v) for v in x]
        return x

    dado = limpa(dado)
    d = dado.get("data") if isinstance(dado, dict) else None
    if isinstance(d, dict) and d.get("zip"):
        z = zipfile.ZipFile(io.BytesIO(base64.b64decode(d["zip"])))
        d["zip"] = {n: hashlib.sha256(sem_data_pdf(z.read(n)) if n.endswith(".pdf") else z.read(n)).hexdigest()
                    for n in sorted(z.namelist())}
    if isinstance(d, dict) and d.get("pdf"):
        # o PDF carrega data de geracao; compara so o tamanho aproximado e o cabecalho
        b = base64.b64decode(d["pdf"])
        d["pdf"] = {"inicio": b[:8].decode("latin1"), "kb": round(len(b) / 1024)}
    return dado


def capturar(pasta):
    os.makedirs(pasta, exist_ok=True)
    for nome, metodo, caminho, params in requisicoes():
        status, corpo = chama(metodo, caminho, params)
        json.dump({"status": status, "corpo": normaliza(nome, corpo)},
                  open(os.path.join(pasta, nome + ".json"), "w", encoding="utf-8"),
                  ensure_ascii=False, indent=1, sort_keys=True)
        print("%-22s %s %7d bytes" % (nome, status, len(corpo)))


def comparar(a, b):
    difs = 0
    for nome in sorted(os.listdir(a)):
        pa, pb = os.path.join(a, nome), os.path.join(b, nome)
        if not os.path.exists(pb):
            print("FALTA em B:", nome); difs += 1; continue
        ja, jb = json.load(open(pa, encoding="utf-8")), json.load(open(pb, encoding="utf-8"))
        if ja == jb:
            print("igual   ", nome)
        else:
            difs += 1
            print("DIFERENTE", nome)
            mostra(ja, jb, "")
    print("\n%d diferenca(s)" % difs)
    return difs


def mostra(x, y, caminho, limite=[0]):
    if limite[0] > 15:
        return
    if type(x) != type(y):
        print("   %s: %r -> %r" % (caminho, x, y)); limite[0] += 1; return
    if isinstance(x, dict):
        for k in sorted(set(x) | set(y)):
            if x.get(k) != y.get(k):
                mostra(x.get(k), y.get(k), caminho + "." + k)
    elif isinstance(x, list):
        if len(x) != len(y):
            print("   %s: %d itens -> %d itens" % (caminho, len(x), len(y))); limite[0] += 1
        for i, (u, v) in enumerate(zip(x, y)):
            if u != v:
                mostra(u, v, "%s[%d]" % (caminho, i))
    else:
        print("   %s: %r -> %r" % (caminho, x, y)); limite[0] += 1


if __name__ == "__main__":
    if sys.argv[1] == "capturar":
        capturar(os.path.join(AQUI, sys.argv[2]))
    else:
        sys.exit(1 if comparar(os.path.join(AQUI, sys.argv[2]), os.path.join(AQUI, sys.argv[3])) else 0)
