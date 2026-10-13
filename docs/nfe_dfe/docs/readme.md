# Módulo DFe — captura própria de documentos fiscais de entrada

Hub de documentação do motor que substitui a **Qive**: captura NF-e, CT-e, MDF-e
e NFS-e de entrada direto da SEFAZ (`DistDFe`) e do ADN Nacional, dentro da
**ApiNFE**, com tela de monitoramento na **ApiDPC + DPC**.

> Centralizado aqui em **02/09/2026**. Antes o material estava em três lugares —
> `ApiNFE/docs/`, `ApiNFE/database/scripts/dfe-entrada/` e
> `itens/` — e o terceiro não era versionado.
>
> `ApiNFE/docs/` e `ApiNFE/database/scripts/` **deixaram de existir**. Este hub é
> o único lugar com documentação **e com os scripts** do módulo — todos `.sql`
> de DBeaver, em `scripts/`.
>
> Consequência a não esquecer: **um deploy da ApiNFE não carrega mais o próprio
> schema.** Quem instalar em ambiente novo vem buscar a DDL aqui.

---

## Comece por aqui

| Preciso de… | Documento |
|---|---|
| **Entender o comportamento da SEFAZ** — cStat, 656, cota, NSU, schemas, eventos | [02_conhecimento-sefaz.md](02_conhecimento-sefaz.md) 🔄 |
| **Entender o motor** — desenho, parâmetros, defeitos já vividos, medições | [03_conhecimento-motor.md](03_conhecimento-motor.md) 🔄 |
| **Quando o motor consulta a SEFAZ** — a regra de negócio inteira, num lugar só | [03_conhecimento-motor.md §2](03_conhecimento-motor.md) |
| **Rodar / operar** os comandos | [06_operacao-comandos.md](06_operacao-comandos.md) |
| **Subir em um ambiente** | [08_operacao-runbook-deploy.md](08_operacao-runbook-deploy.md) |
| **Levar o módulo para a PRODUÇÃO** — estrutura de banco, ordem dos scripts, replicação homolog → produção | [scripts/producao/LEIA_instalar_em_producao.md](../scripts/producao/LEIA_instalar_em_producao.md) + [`dfe:replicar` em 06](06_operacao-comandos.md#dfereplicar) |
| Saber **o que cada tabela** guarda | [04_dados-tabelas.md](04_dados-tabelas.md) |
| **Consumir os dados** numa tela | [05_dados-consumo-frontend.md](05_dados-consumo-frontend.md) |
| **Instalar ou alterar a base** | [07_ddl-instalacao.md](07_ddl-instalacao.md) |
| Achar **um script** | [09_catalogo-scripts.md](09_catalogo-scripts.md) |
| **Os dois CNPJs onde dá para testar** — e o que cada teste provou | [10_cadastros-de-teste.md](10_cadastros-de-teste.md) |
| O que foi tocado na **Consinco de teste**, e como desfazer | [11_registro-alteracoes-tst.md](11_registro-alteracoes-tst.md) |
| A investigação do **cStat 656** | [12_sefaz-656-consumo-indevido.md](12_sefaz-656-consumo-indevido.md) |
| A **tela de monitoramento** | [13_tela-monitor-dfe.md](13_tela-monitor-dfe.md) |
| A **decisão de negócio** sobre a Qive | [01_decisao-qive.md](01_decisao-qive.md) |
| **Conciliar com o ERP** — frente em andamento, documentada à parte | [14_conciliacao-erp.md](14_conciliacao-erp.md) 🚧 |

O **número no nome é a ordem sugerida de leitura**, de quem chega agora: por que o
motor existe, o comportamento da SEFAZ, o desenho, os dados, como operar, como
instalar, e por fim o material de referência. Quem já conhece o sistema usa a
tabela acima e ignora a ordem. O `readme.md` não tem número porque é o índice,
não um capítulo.

🚧 = **frente em andamento**, documentada à parte até o desenho assentar.

🔄 = **documento vivo**: atualizar sempre que um conhecimento for adquirido ou
cair. Os dois carregam marcas de confiança (🟢 normativo · 🔵 medido ·
🟡 hipótese · 🔴 derrubado), porque foi confundir hipótese com fato que custou
os diagnósticos mais longos.

## Onde o código vive

> Convenção fixada em **15/09/2026**.

Todo o trabalho do módulo — motor, Monitor, dashboards e relatórios — vai para
uma branch única, com o **mesmo nome nos três repositórios**, e **um PR por
repositório** contra `master`:

```
feature/dfe-documentos-fiscais
```

Isto **substitui a branch por card** neste módulo, e só neste. Fora do DFe, vale
a regra geral de [git-workflow-branches.md](../../regras/gerenciar-regras/git-workflow-branches.md).

**Por quê.** A frente é contínua e atravessa os três projetos: o mesmo assunto
rende commit na ApiNFE, na ApiDPC e no DPC, às vezes no mesmo dia. Com branch por
card, o resultado foi branch virando cópia de branch — em 15/09/2026 a
`feature/3280-sefaz-nfe` da ApiDPC era, commit a commit, a mesma da
`feature/dfe-monitor-documentos-fiscais`, e um commit novo não conseguiu ter PR
próprio sem duplicar dez commits já em revisão. No DPC a mesma frente vivia em
duas branches ao mesmo tempo, com dois PRs abertos.

**PRs da consolidação** — ApiNFE#14 · ApiDPC#1016 · DPC#1234.

**Substituíram** ApiNFE#13, ApiDPC#1010, DPC#1198 e DPC#1233. Eles fecharam
porque o GitHub **não troca o head ref de um PR existente**: mover a branch
obriga a recriar o PR, com número novo. Foi o que já tinha acontecido antes em
ApiNFE#12→#13 e ApiDPC#1005→#1010. Contar com isso ao planejar qualquer mudança
de branch daqui pra frente.

**Branches antigas mantidas no remoto** como rede de segurança, nenhuma
deletada: `feature/dfe-motor-captura-entrada` (ApiNFE),
`feature/dfe-monitor-documentos-fiscais` e `feature/3280-sefaz-nfe` (ApiDPC),
`feature/monitor-dfe` e `feature/3280-sefaz-nfe` (DPC).

## O sistema em um diagrama

```mermaid
flowchart TD
    subgraph EXT["Fontes externas"]
        SEF["SEFAZ<br/>NFeDistribuicaoDFe<br/>CTeDistribuicaoDFe<br/>MDFeDistribuicaoDFe"]
        ADN["ADN Nacional<br/>NFS-e"]
    end

    subgraph API["ApiNFE — Lumen 10 / PHP 8.2 — 100% CLI"]
        ING["dfe:ingerir<br/>fala com a fonte"]
        NOR["dfe:normalizar<br/>nunca fala com a fonte"]
        CON["dfe:conciliar"]
        MAN["dfe:manifestar<br/>agendado --auto (Ciência+Confirmação);<br/>trancas por empresa fechadas hoje"]
        MON["dfe:monitorar"]
    end

    subgraph OR["Oracle — schema poseidon"]
        CUR[("DPC_DFE_CURSOR<br/>posição de leitura")]
        DOC[("DPC_DFE_DOCUMENTO<br/>XML bruto = a fila")]
        NRM[("NOTA · ITEM · CTE<br/>NFSE · EVENTO · EMITENTE")]
        PAR[("DPC_PARAMETRO<br/>os 6 parâmetros")]
    end

    subgraph TELA["Monitor DFe"]
        DPCAPI["ApiDPC<br/>Laravel 5.5 / PHP 7.2"]
        DPCUI["DPC<br/>Vue 2"]
    end

    SEF & ADN --> ING
    ING --> DOC & CUR
    DOC --> NOR --> NRM
    NRM --> CON & MAN
    PAR --> ING & MON
    PAR --> DPCAPI
    NRM & DOC & CUR --> DPCAPI --> DPCUI
    MON -.->|"alerta no terminal"| OPS(["quem opera"])
```

## As duas invariantes que sustentam o desenho

```
1. dfe:normalizar NUNCA fala com a SEFAZ.
   Bug de parser deixou de significar documento perdido — a SEFAZ retém
   por ~90 dias, e antes a perda era definitiva.

2. Nada automático consulta a SEFAZ depois de um bloqueio.
   Consultar antes de vencer a hora ZERA o tempo e reinicia a contagem, e o
   fluxo nunca sai do laço sozinho - sem nenhum sinal de erro.
```

## Onde as coisas moram

```
workspace/
├── ApiNFE/                                  o motor (Lumen 10 / PHP 8.2)
│   ├── app/Console/Commands/Dfe*.php        os 5 comandos
│   ├── app/Repositories/Dfe*.php            parser, cursor, execução, nota...
│   └── app/Repositories/DpcParametroRepository.php
│                                            ↑ nenhuma doc e nenhum .sql aqui
├── ApiDPC/app/Repositories/SefazMonitorDfeRepository.php
├── ApiDPC/app/Repositories/SefazDocumentoRepository.php
│                                            ↑ casca das telas de documento
├── ApiDPC/app/Repositories/SefazNfeRepository.php    ┐
├── ApiDPC/app/Repositories/SefazCteRepository.php    │ as 3 familias
├── ApiDPC/app/Repositories/SefazNfseRepository.php   ┘
├── DPC/src/app/sefaz/monitor/               a tela de monitoramento
├── DPC/src/app/sefaz/documentos/comum/      a casca no front
├── DPC/src/app/sefaz/documentos/nfe/        tela de NF-e
├── DPC/src/app/sefaz/documentos/cte/        tela de CT-e
├── DPC/src/app/sefaz/documentos/nfse/       tela de NFS-e
│
└── .claude/docs/nfe_dfe/                    ◀ O HUB
    ├── docs/                                a documentação
    │   ├── readme.md                        este índice
    │   ├── 01_decisao-qive.md
    │   ├── 02_conhecimento-sefaz.md  🔄
    │   ├── 03_conhecimento-motor.md  🔄
    │   ├── 04_dados-tabelas.md
    │   ├── 05_dados-consumo-frontend.md
    │   ├── 06_operacao-comandos.md
    │   ├── 07_ddl-instalacao.md
    │   ├── 08_operacao-runbook-deploy.md
    │   ├── 09_catalogo-scripts.md
    │   ├── 10_cadastros-de-teste.md
    │   ├── 11_registro-alteracoes-tst.md
    │   ├── 12_sefaz-656-consumo-indevido.md
    │   ├── 13_tela-monitor-dfe.md
    │   └── 14_conciliacao-erp.md                frente aberta, à parte
    │
    ├── itens/                               o que NAO e versionado
    │   ├── *.pfx                            os dois certificados A1
    │   ├── 02_certificado_all_cars_tst.sql  PFX em base64 + senha
    │   └── sefaz-656-consumo-indevido.md    stub, sustenta um link do CLAUDE.md
    │
    └── scripts/                             SO .sql de DBeaver
        ├── levantamento-nfse-municipios.sql   diagnostico, nao instalacao
        ├── ddl/                             o UNICO caminho de instalacao (convergente)
        │   ├── 01_estrutura_motor           17 tabelas de captura
        │   ├── 02_estrutura_telas           6 tabelas de permissao, colunas, modelos e alerta
        │   ├── 03_parametros                os 11 dfe_*
        │   ├── 04_validacao                 somente leitura
        │   └── rollback/                    UM por DDL (01_99, 02_99, 03_99)
        ├── homolog/                         dado e valor SO da base de teste
        │   ├── 01_estabelecimentos · 02_parametros_homolog
        │   └── empresas/ 20_01 · 29_01 · 30_01
        ├── operacao/                        pausa_empresas · retomada_empresas
        └── producao/                        LEIA_instalar_em_producao.md
```

Arquitetura da ApiNFE como um todo (não só o DFe):
[apinfe-arquitetura.md](../../arquitetura/apinfe-arquitetura.md).

## Estado atual — 02/09/2026

| | |
|---|---|
| Base normalizada | **18.757 documentos**, todos concluídos — 0 pendente, 0 erro, 0 ignorado |
| Fluxos ativos | **0 de 60** (15 empresas × 4 tipos) — TODOS os cursores pausados desde 24/09/2026, janela para o teste real de manifestação. Estado exato de antes da pausa gravado (fora do repo, no scratchpad da sessão que pausou) |
| Ambiente | roda em `dkalpha00`, cron ativo, base **homolog**, SEFAZ **real** |
| Produção | **estrutura instalada em 13/10/2026, idêntica à da homolog** (`dfe:replicar --estrutura`: zero diferenças). Os dados ainda **não** foram copiados: a carga inicial exige autorização explícita. O motor não vive lá (decisão de 09/09/2026); prd serve ao `dfe:conciliar` para **ler** a Consinco. As tabelas legadas `dpc_sefaz_*` foram renomeadas para `dpc_dfe_*` (a ApiDPC de produção só muda no deploy do Douglas, via PR). Ver [LEIA_instalar_em_producao](../scripts/producao/LEIA_instalar_em_producao.md) |
| CNPJs livres da Qive | **apenas 900 (ALL CARS)**, que nem está cadastrada lá. **Correção de 23/09/2026:** a 30 (DPC MS) NÃO está livre — a lista anterior estava errada. Todos os outros 13 CNPJs, inclusive a 30, seguem com a Qive e o NSU é compartilhado (por CNPJ, não por certificado) |
| `dfe:replicar` | **agendado desde 07/10/2026, mas desligado** (`dfe_replicacao_prd` não existe ainda na homolog = off): a cada 5 min copia o motor da homolog para a produção até o motor subir lá; `--reconciliar` às 3h. Carga inicial em produção **só com autorização explícita**. Ver [06_operacao-comandos.md](06_operacao-comandos.md#dfereplicar) |
| `dfe:manifestar` | **agendado desde 24/09/2026** (Fases 2 e 3): `--evento=210210 --auto --confirmar` nos minutos `7,37`, `--evento=210200 --auto --confirmar` no minuto `22`, ambos com a janela noturna 22h-06h. Não manifesta nada sozinho hoje: as 15 empresas estão com `status_manifestar='N'` e as duas flags de automação em `'N'`. Endpoint manual `POST dfe/manifestar` (Fase 4) também existe, atrás da permissão `MANIFESTAR` (ninguém tem ainda). Ver [06_operacao-comandos.md](06_operacao-comandos.md) |
| Teste de volume (empresa 30) | **adiado, sem data.** Fluxos `NFE` e `CTE` pausados e acumulando atraso de propósito — ver [03_conhecimento-motor.md](03_conhecimento-motor.md) |

Itens abertos, com o porquê de cada um:
[03_conhecimento-motor.md §8](03_conhecimento-motor.md).

## Regras ao mexer nisto

| | |
|---|---|
| **Domínio fiscal não usa Context7** | ele indexa doc de bibliotecas; a `sped-nfe` documenta a API dela, não as regras do fisco. Ordem: portal da NF-e → bases de provedores. Detalhe no cabeçalho de [02_conhecimento-sefaz.md](02_conhecimento-sefaz.md) |
| **Certificado nunca é versionado** | os dois `.pfx` e o `02_certificado_all_cars_tst.sql` — que carrega o PFX em base64 e a senha — ficam em `itens/`, e a pasta **inteira** está no `.gitignore` desde 09/09/2026. A regra era por nome de arquivo e um rename a burlou em silêncio, pela segunda vez; ignorar a pasta protege o propósito, e não um nome. O motor lê o certificado do banco, não do disco |
| **Pasta `scripts/` só tem `.sql`** | nenhum README lá dentro: a explicação de cada grupo é um documento do hub, e o [catálogo](09_catalogo-scripts.md) diz qual |
| **DDL em CRLF** | em LF o DBeaver corta o bloco PL/SQL no `end if;` e devolve `PLS-00103`. Garantido por `workspace/.claude/.gitattributes` |
| **`ddl/03_parametros` antes do deploy** | ele carrega valores que o código **lê**; na ordem inversa o freio cai para 5 e o motor se trava em silêncio, e a conciliação passa a ler o clone de homologação em vez de produção |
| **A estrutura não carrega parâmetros** | `DPC_PARAMETRO` é tabela compartilhada do ecossistema, então `01_estrutura_motor` e `02_estrutura_telas` **não** carregam as linhas dela: é o `03_parametros` |
| **Nunca escrever `nro_ultimo_nsu` a mão** | valor arbitrário = `cStat 656` e certificado bloqueado por 1 hora, atingindo todas as filiais do e-CNPJ |
