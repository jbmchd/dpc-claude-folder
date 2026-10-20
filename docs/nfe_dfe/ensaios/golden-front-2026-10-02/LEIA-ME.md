# Golden test da extração da tela de NF-e para a casca comum (02/10/2026)

Scripts do ensaio que validou a refatoração descrita em `..\..\docs\05_dados-consumo-frontend.md`: a tela de NF-e (`Main.vue`) foi extraída para uma casca comum (`TelaDocumentoFiscal` + `formatadores`), que as telas de CT-e e NFS-e reaproveitam. Resultado registrado nessa doc: **37 requisições capturadas no código antigo e no novo, iguais campo a campo**; só o PDF varia (e varia também entre duas execuções do código antigo).

Resgatados em 20/10/2026 da pasta temporária da sessão do Claude "Motor SEFAZ Qive" (id 30881aac). No front (`DPC`), a casca comum já está nas branches `master` e `alpha` (conferido em 20/10/2026; a `beta` ainda não a contém).

| Arquivo | Para quê (resumo pelo cabeçalho; não foi reexecutado) |
|---|---|
| `golden.py` | `python golden.py capturar <pasta>` captura as respostas da ApiDPC **local** para um conjunto fixo de requisições; `python golden.py comparar <pastaA> <pastaB>` compara duas capturas campo a campo, ignorando só o que muda sozinho (a conciliação com o ERP roda a cada 30 min). Lê o token de `C:\Users\joabe\AppData\Roaming\dpc-dev-box\token-apidpc.json` (fora do repositório). |
| `front_baseline.js` | Função assíncrona para rodar dentro da página (no navegador automatizado): conta requisições XHR pendentes e captura o que a tela exporta, para comparar o front antes e depois. |
| `monta_main.py`, `monta_nfe.py` | Geradores dos arquivos da tela usados na extração (inferido pelo nome e pelos comentários). |

**Não foi guardado** (ficava na pasta temporária, 37 MB, e foi descartado): as 7 capturas de 37 arquivos cada (`antes1`, `antes2`, `depois`, `depois2`, `alpha`, `faseD`, `faseD2`), as cópias `.mjs` do código do front e os `front_*.json` / `.b64.json`. As capturas "antes" vinham do código antigo: para repetir a comparação é preciso regenerá-las com o código anterior ao commit `refactor(sefaz): casca comum das telas de documento fiscal no front` (o código antigo está no histórico do git do `DPC`).
