Seu objetivo é atualizar a branch `alpha` de um projeto do workspace no servidor 16
(`dkalpha00`, 192.168.2.16). O projeto é passado como argumento do comando.

## Se o projeto não foi informado

**Pergunte antes de continuar.** Não adivinhe pelo contexto da conversa. As opções
conhecidas hoje são:

- `ApiNFE` (API)
- `ApiDPC` (API)
- `DPC` (front)

Se o nome vier em variação óbvia (`api nfe`, `apinfe`, `api dpc`, `apidpc`, `dpc`,
`front`, `front dpc`), resolva sem perguntar. Se vier um projeto que não é nenhum
destes três (`Faisao`, `DpcInventario`, etc.), **pare e pergunte** como proceder —
o fluxo abaixo não foi validado para eles.

## Pré-checagens (sempre, antes de qualquer ação)

Rode as quatro checagens abaixo **antes** de tocar em qualquer coisa — fetch,
merge, checkout, reset ou build. Qualquer falha para o comando ali mesmo, com
um relatório claro de qual checagem falhou e por quê. Nunca tente corrigir
sozinho (reconectar VPN, `reset --hard` no servidor, trocar de branch por
conta própria) — isso é decisão do usuário.

### 1. VPN e SSH até o servidor 16

Isto é só conectividade até o `dkalpha00` — **não** é o túnel Oracle
(`tunnel-dpc`, portas 1521/1522 etc.). Este comando não fala com o banco,
então checar aquele túnel checaria algo que ele nem usa.

```bash
ping -n 2 192.168.2.16
```

- **100% de perda** → VPN fora do ar. Não tente reconectar sozinho — é ação
  do usuário. Diagnostique mais para dar um relatório útil:
  ```bash
  ipconfig | grep -A6 "TAP-Windows6"
  ping -n 2 8.8.8.8
  ```
  Isso distingue "VPN caiu" (adaptador TAP sem gateway, mas internet geral
  funciona) de "sem rede nenhuma". Reporte qual dos dois e peça para
  reconectar a VPN antes de tentar de novo.
- **Ping ok** → confirme que a autenticação SSH funciona, não só a rota:
  ```bash
  ssh -o BatchMode=yes -o ConnectTimeout=5 dkalpha00 "echo ok"
  ```
  Se isso falhar com a VPN de pé, é problema de chave/known_hosts — reporte o
  erro exato do SSH, sem tentar mais de uma variação.

### 2 e 4a. Checkout local: branch e limpeza

Mesmo bloco para os três projetos, trocando o caminho:

```bash
cd d:/joabe/Documents/dev/projetos/dpc/workspace/<PROJETO> &&
git branch --show-current &&
git status --short
```

- `git status --short` precisa vir vazio. Se não vier, **pare e liste os
  arquivos modificados** — nunca `stash`/`reset` sem perguntar.
- Branch precisa ser `alpha` — **mas isso só bloqueia para `ApiNFE` e
  `ApiDPC`**. Se não for `alpha`, pare e informe qual branch está checked
  out.
- **Exceção para `DPC`:** o próprio fluxo Front troca para `alpha` daqui a
  pouco (é assim que ele builda a partir da ponta real da branch). Então,
  para `DPC`, a checagem de branch aqui é só informativa — o que bloqueia é
  só a árvore limpa. Não exija `alpha` antes de rodar o `git checkout alpha`
  do fluxo Front.

### 3 e 4b. Checkout no servidor 16: branch e limpeza (só API)

**Não se aplica ao Front `DPC`** — `/containers/DPC/prod` não roda `git`, é
diretório de arquivos estáticos.

```bash
ssh dkalpha00 "cd /containers/<PROJETO>; git branch --show-current; git status --short"
```

- Branch precisa ser `alpha`. Se não for, **pare** — o servidor está rodando
  outra coisa, e um `merge --ff-only` ali seria contra a branch errada.
- `git status --short` precisa vir vazio. Se não vier, **pare** — alguém
  editou direto no container, fora do fluxo de deploy, e isso exige decisão
  humana antes de qualquer merge.

## Fluxo API (`ApiNFE` ou `ApiDPC`)

"Atualizar a branch no 16" aqui significa **só** sincronizar o checkout do
servidor com o `origin/alpha` remoto. Este comando **não** commita nem faz push
de nada local — se houver trabalho local pendente para ir ao ar, isso é um passo
separado, a pedido explícito do usuário (ver `.claude/CLAUDE.md`).

```bash
ssh dkalpha00 "cd /containers/<PROJETO>; \
  git fetch origin alpha 2>&1 | tail -3; \
  git merge --ff-only origin/alpha 2>&1 | tail -3; \
  git log --oneline -1"
```

Troque `<PROJETO>` por `ApiNFE` ou `ApiDPC` — é o mesmo nome da pasta em
`/containers/` no servidor.

**Confirmação de sucesso:** o hash do `git log --oneline -1` do servidor precisa
bater com o de `git log --oneline -1 origin/alpha` visto localmente. Se
`merge --ff-only` falhar (o servidor divergiu do remoto — alguém editou direto lá,
ou um force-push aconteceu), **pare e reporte o conflito**; nunca resolva com
`reset --hard` sem perguntar, porque isso descarta o que estiver só no servidor.

Nenhum dos dois containers precisa de restart depois do pull: o PHP lê os arquivos
do zero a cada requisição/execução, sem opcache persistente entre chamadas — foi
assim que todo deploy de `ApiNFE` funcionou ao longo deste módulo.

## Fluxo Front (`DPC`)

Diferente das APIs: aqui não existe branch para atualizar no 16, porque o
front é servido como arquivos estáticos em `/containers/DPC/prod` — não roda
`git` lá. O que se publica é o resultado do `npm run build:alpha`, copiado por
`scp`.

### Por que não builda na `.219`

A `.219` (VM onde o usuário roda isso manualmente) **não tem** credencial de
`git` para buscar do GitHub nem chave SSH configurada para o servidor 16 numa
sessão não interativa — só funciona quando o usuário autentica à mão. Faça o
build e o `scp` **desta máquina** (o ambiente onde você está rodando), que já
tem os dois: acesso `git` normal e a chave SSH de `dkalpha00` já testada ao
longo deste workspace.

Se em algum momento a `.219` passar a ter git+SSH configurados de forma não
interativa, os dois fluxos passam a ser equivalentes — mas não assuma isso sem
testar de novo.

### Passo 1 — sincronizar o checkout local com o `origin/alpha` real

A pré-checagem 4a já confirmou que a árvore está limpa — é o que torna este
`reset --hard` seguro, mesmo trocando de branch.

```bash
cd d:/joabe/Documents/dev/projetos/dpc/workspace/DPC &&
git fetch origin alpha &&
git checkout alpha &&
git reset --hard origin/alpha &&
git log --oneline -1
```

Isso importa: o checkout local pode estar em qualquer branch de feature, e o
`origin/alpha` pode estar à frente do que a `.219` tem (outras pessoas mergeiam
ali o tempo todo). Buildar a partir da ponta real do `alpha` é o comportamento
esperado de "atualizar o alpha" numa branch compartilhada — não perguntar "a
partir de qual commit" de novo; isso já foi decidido.

### Passo 2 — trocar para Node 14 antes de buildar

```bash
nvm use 14.21.3 &&
node -v
```

**Não pule isso.** O projeto compila SCSS com `node-sass`/LibSass, sensível à
versão do Node. Em Node mais novo o `dart-sass` assume silenciosamente e
**esconde erro real de compilação** — já aconteceu (`min()`/`max()` do CSS
quebrando com "Incompatible units", só visível no Node 14 do projeto). O nvm
neste ambiente é o nvm4w baseado em link simbólico: a troca persiste entre
chamadas de comando, não precisa repetir `nvm use` a cada bloco.

### Passo 3 — build

```bash
cd d:/joabe/Documents/dev/projetos/dpc/workspace/DPC &&
npm run build:alpha
```

**Confirmação de sucesso:** a saída termina com `Build complete.` **e**
`dist/index.html` existe com data/hora posterior ao início do build. Nunca
considere sucesso só pelos logs do webpack passando — o `Build complete.` no
final é o que importa, igual à regra do `gerar-apk`: só o artefato final conta.

### Passo 4 — publicar no servidor 16

```bash
cd d:/joabe/Documents/dev/projetos/dpc/workspace/DPC &&
scp -r ./dist/* dkalpha00:/containers/DPC/prod
```

### Passo 5 — confirmar que chegou

```bash
ssh dkalpha00 "ls -la /containers/DPC/prod/index.html /containers/DPC/prod/static"
```

O `index.html` e as subpastas de `static/` precisam ter o horário do build que
acabou de rodar. `scp -r` só sobrescreve o que existe no `dist/` novo — não
apaga arquivo antigo que tenha saído do build atual; se isso importar, avise o
usuário em vez de decidir sozinho por uma limpeza.

## Resultado

- **Sucesso (API):** hash do servidor bate com `origin/alpha`. Reportar o hash.
- **Sucesso (front):** os 5 passos completam e o `ls` final mostra arquivos com
  o timestamp do build. Reportar isso.
- **Falha na pré-checagem:** dizer exatamente qual das quatro falhou (VPN/SSH,
  branch local, branch do servidor, ou árvore suja em qual dos dois lados) e
  não avançar para nenhum fluxo. Nunca contornar sozinho.
- **Falha no fluxo:** dizer exatamente em qual passo parou e por quê. Nunca
  prosseguir para o passo seguinte com um passo anterior falho — em especial
  não copiar (`scp`) um `dist/` que não terminou com `Build complete.`, e não
  fazer `reset --hard` com a árvore local suja.
