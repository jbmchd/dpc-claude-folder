Seu objetivo é gerar uma nova release do projeto Faisão, decidindo entre OTA (EAS Update, **sem mexer na versão**) e build novo (EAS Build, **com bump de versão**) a partir das mudanças desde a última release.

Caminho do projeto: `d:/Joabe/Documents/dev/projetos/dpc/workspace/Faisao`

## Argumentos aceitos

`/gerar-versao [tipo] [canal] [--ota|--build] [--lint] [--dry-run]`

- `tipo` (opcional): `patch` | `minor` | `major` | `x.y.z` específico. **Só se aplica ao caminho build no canal `production`.** No caminho OTA e no canal `preview` é ignorado (não há bump). Se omitido no build production, pergunte ao usuário (com a recomendação destacada).
- `canal` (opcional): `preview` | `production`. Default = `production`.
  - **`production`** → fluxo completo na **`main`** (checkout + sync + tag + GitHub Release).
  - **`preview`** → usa a **branch atual**, seja ela qual for (feature, integração ou a própria main). **Não** troca de branch, **não** cria tag/release, **não** commita nem faz push — só valida e imprime o comando `eas` do canal preview. É o caminho para testar código que ainda não foi mergeado na main.
- `--ota` / `--build`: força o método de entrega (default = autodetectado). As palavras posicionais `ota`/`build` (qualquer caixa, ex.: `OTA preview`) valem como `--ota`/`--build`.
- `--lint`: roda `npm run lint` antes da release (por padrão o lint **não** roda).
- `--dry-run`: simula, sem executar nada. No canal `production`, aborta se não estiver em main (não troca de branch); no canal `preview` roda normal (preview já não muda nada).

## Conceito-chave: OTA não mexe na versão

`runtimeVersion = expo.version` (1:1, ver `scripts/sync-runtime-version.js`). Por isso:

- **OTA** publica só o bundle JS sobre o build atual. **Não** bumpa `version` nem `runtimeVersion` — senão o OTA mudaria o `runtimeVersion` e **não chegaria** aos aparelhos já instalados. A "Versão X.Y.Z" exibida no app fica intacta; só o campo `OTA <id> (data)` (via `expo-updates`) é atualizado nos aparelhos que baixam. Mudanças nativas **não** vão por OTA.
- **Build** gera nova versão nativa (Play Store), bumpando `version` + `runtimeVersion` + `versionCode`.


> **Duas flags obrigatórias em todo comando `eas` impresso aqui:**
>
> - `--platform android` — **não há versão iOS do Faisão**. Sem a flag, o `-p` do `eas` usa
>   `[default: all]`, o export inclui iOS e **falha**: o `app.json` não declara `jsEngine` (o Expo
>   assume hermes) enquanto o `ios/Podfile.properties.json` está em `jsc`. O update nem chega a
>   publicar. Não "consertar" essa divergência: `ios/` é pasta sensível e `expo prebuild` é proibido.
>   Quando existir versão iOS, rever esta regra.
> - `--environment` — só no `eas update`, e **obrigatório a partir do Expo SDK 55** (o Faisão está
>   no 56). Sem ela o comando para num prompt interativo pedindo o ambiente. Não confundir com
>   `--branch`: `--branch` escolhe quem recebe o update; `--environment` escolhe o conjunto de
>   variáveis de ambiente do EAS usado durante o export. O `eas build` e o `eas submit` **não têm**
>   essa flag — tiram o ambiente do profile no `eas.json`.

## Pré-condições

Sempre `cd d:/Joabe/Documents/dev/projetos/dpc/workspace/Faisao` antes de qualquer comando.

Aborte com mensagem clara (em PT-BR) e pare a execução se qualquer pré-condição falhar. **Não tente "consertar" automaticamente.**

## Fluxo

### 1) Verificações iniciais

```bash
gh --version && gh auth status
git status --porcelain
```

- `gh` não instalado/autenticado → abortar.
- `git status --porcelain` retornou algo → working tree sujo, abortar listando os arquivos.

### 2) Branch correta (depende do canal)

```bash
git rev-parse --abbrev-ref HEAD
```

- **Canal `production`** — se != `main`:
  - **Em `--dry-run`**: abortar com "dry-run não troca de branch; rode sem --dry-run ou faça `git checkout main` manualmente".
  - **Modo normal**: rodar `git checkout main && git pull origin main`. Guardar a branch original em `ORIGINAL_BRANCH` para avisar no final.
- **Canal `preview`**: ficar na branch atual, qualquer que seja. Guardar o nome em `BRANCH_ATUAL` para os resumos/saídas. Não fazer checkout nem pull.

### 3) Sync com origin (só canal `production`)

```bash
git fetch origin main
git rev-list --left-right --count main...origin/main
```

A saída é `<ahead>\t<behind>`. Abortar se `ahead > 0` (sugerir `git push`) ou `behind > 0` (sugerir `git pull`).

**Canal `preview`**: pular este passo — a branch pode ser local-only (ex.: `integracao/…`) e nada será pushado.

### 4) Análise da release (commits + arquivos modificados)

```bash
LAST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "")
RANGE=${LAST_TAG:+$LAST_TAG..HEAD}
git log ${RANGE:-} --format=%s
git diff --name-only ${RANGE:-}
node -p "require('./package.json').version"
```

**Classifique os commits (Conventional Commits):**

| Padrão na linha | Categoria |
|---|---|
| `^[a-z]+(\([^)]*\))?!:` ou body com `BREAKING CHANGE` | BREAKING |
| `^feat(\([^)]*\))?:` | FEAT |
| `^fix(\([^)]*\))?:` | FIX |
| Resto (chore:, docs:, etc., ou sem prefixo) | OUTROS |

**Bump recomendado (só usado no caminho build):**
- ≥1 BREAKING → `major`
- ≥1 FEAT → `minor`
- senão → `patch`

**Classifique os arquivos:**

| Categoria | Critério |
|---|---|
| NATIVO | começa com `android/` ou `ios/`; ou exatamente `app.json`, `eas.json` |
| JS_PURO | começa com `src/`, `assets/`, `docs/`, `scripts/`; ou exatamente `App.tsx`, `index.js`, `babel.config.js`, `metro.config.js`, `tsconfig.json`, `tailwind.config.js`, `.prettierrc`, `.eslintrc.json`, `.gitignore` |
| AMBIGUO | exatamente `package.json` ou `package-lock.json` |
| DESCONHECIDO | qualquer outro |

**Se houver arquivo AMBIGUO**, perguntar via `AskUserQuestion`: "package.json modificado — alguma dep nova ou atualizada tem código nativo (android/ios)?" → resposta "sim" conta como NATIVO; "não" conta como JS_PURO. Em `--dry-run`, assumir SIM (conservador) e mencionar a suposição.

**Método recomendado:**
- ≥1 NATIVO ou ≥1 DESCONHECIDO ou sem `LAST_TAG` → `build`
- Senão → `ota`

### 5) Escolher o método de entrega

- Se `--ota` ou `--build` foi passado, use direto.
- Senão, chamar `AskUserQuestion` com 2 opções, destacando o recomendado (passo 4) como **(RECOMENDADO)**:
  - **OTA (eas update)** — não mexe na versão nem no runtimeVersion; publica só o bundle JS.
  - **Build novo (eas build)** — gera nova versão nativa (Play Store); bumpa a versão.

A partir daqui o fluxo **bifurca**. Siga **apenas** o caminho do método escolhido.

---

## Caminho BUILD (nova versão nativa)

### B0) Canal `preview` — atalho (sem bump, sem tag)

Se o canal for `preview`, **pular B1→B5 inteiros**. Build preview é APK de teste: usa `version`/`runtimeVersion`/`versionCode` atuais da branch, sem `npm version`, sem commit, sem tag, sem release, sem push.

1. Lint só com `--lint` (igual B3).
2. Mostrar o resumo:

```
Modo:     BUILD preview (APK de teste) — versão NÃO muda
Versão:   X.Y.Z (mantida)
Branch:   $BRANCH_ATUAL (mantida)
Commits desde LAST_TAG: N
  (até 15 primeiros, em formato oneline)
```

3. **Em `--dry-run`, pare aqui** com "[dry-run] nenhuma alteração feita". Fora dele, imprimir a saída final:
   - `[OK] Build preview validado na branch $BRANCH_ATUAL — nada foi commitado/tagueado.`
   - Próximo passo (rodar manualmente): `npx eas build --platform android --profile preview`
   - Lembrete: o APK sai do código da branch atual; o que estiver fora dela (ex.: não mergeado) não entra.

**Fim do caminho BUILD preview.** Os passos B1→B6 abaixo valem só para o canal `production`.

### B1) Decidir o bump

Calcule os 3 candidatos a partir da versão atual `X.Y.Z`:
- `patch` → `X.Y.(Z+1)`
- `minor` → `X.(Y+1).0`
- `major` → `(X+1).0.0`

- Se o `tipo` foi passado como argumento: valide (`patch`/`minor`/`major`/regex `^\d+\.\d+\.\d+$`) e use direto. Se inválido, abortar.
- Se não foi passado: chamar `AskUserQuestion` mostrando as 4 opções (patch, minor, major, custom) com a recomendação destacada como **(RECOMENDADO)**. Opção 4 (custom) pede o `x.y.z`.

Persistir `NEW_VERSION` e `TAG=v$NEW_VERSION`.

### B2) Tag não pode existir

```bash
git rev-parse $TAG 2>/dev/null && echo "EXISTE_LOCAL"
git ls-remote --tags origin refs/tags/$TAG
```

Abortar se já existir local ou no remote.

### B3) Lint

Por padrão o lint **não roda** (é pulado). Só rode se foi passado `--lint`:

```bash
npm run lint
```

Se rodar e falhar, abortar reportando os erros.

### B4) Resumo (sem confirmação)

Mostre o resumo e **siga direto** para a execução — não peça confirmação ao usuário:

```
Modo:     BUILD novo (Play Store)
Versão:   X.Y.Z → NEW_VERSION
Tag:      vNEW_VERSION
Branch:   main (saindo de $ORIGINAL_BRANCH, se aplicável)
Commits desde LAST_TAG: N
  (até 15 primeiros, em formato oneline)
```

**Em `--dry-run`, pare aqui** com "[dry-run] nenhuma alteração feita". Fora do `--dry-run`, prossiga automaticamente para B5.

### B5) Executar

```bash
npm version $NEW_VERSION
git push --follow-tags origin main
gh release create $TAG --generate-notes --title "$TAG"
```

- `npm version` dispara o hook `bump-app-version.js`, que propaga a versão pra `app.json` (`expo.version`), `runtimeVersion` (`app.json` + `strings.xml`), o `build.gradle` (`versionName` + incremento do `versionCode`), regenera `src/utils/buildInfo.ts` e adiciona tudo ao commit `vNEW_VERSION` + tag local.
- Se algo falhar entre `npm version` e o `gh release create`, **não faça rollback automático**. Reporte exatamente onde falhou e instrua o usuário a continuar manualmente (ex: "tag local criada mas push falhou; rode `git push --follow-tags origin main`").

### B6) Saída final

Imprimir, em sucesso:

- `[OK] Release $TAG criada.`
- **Versão e versionCode gerados** (sempre exibir): leia o `versionCode` já incrementado em `android/app/build.gradle` (ex.: `grep versionCode android/app/build.gradle`) e imprima: `Versão gerada: $NEW_VERSION  |  versionCode: <valor lido>`.
- Se houve troca de branch: `NOTA: você começou em "$ORIGINAL_BRANCH", agora está em main. Pra voltar: git checkout $ORIGINAL_BRANCH`.
- Próximo passo (gerar + enviar pro Play):
  - Build + envio automático (um passo só): `npx eas build --platform android --profile production --auto-submit`
  - Ou separado: `npx eas build --platform android --profile production` e, após o build pronto, `npx eas submit --platform android --profile production --latest`
  - Nota: o `submit` publica no track **internal** (config em `eas.json` → `submit.production.android`). Promover para produção depois pelo Play Console (https://play.google.com/console). Alternativa manual: baixar o AAB e subir pelo console.

---

## Caminho OTA (sem bump de versão)

### O0) Montar a mensagem do `eas update`

A mensagem aparece no dashboard do EAS e é o que identifica o update depois. `branch@hash` sozinho não diz **o que** mudou, então ela leva também um resumo do conteúdo.

```bash
LIMITE=3
ITENS=$(git log ${LAST_TAG:+$LAST_TAG..HEAD} --no-merges --reverse --format=%s \
  | grep -E '^(feat|fix)(\([^)]*\))?!?:' \
  | sed -E 's/^(feat|fix)\(([^)]*)\)!?: */\2: /; s/^(feat|fix)!?: *//')
TOTAL=$(printf '%s\n' "$ITENS" | grep -c .)
RESUMO=$(printf '%s\n' "$ITENS" | head -$LIMITE | paste -sd '~' - | sed 's/~/; /g')
[ "$TOTAL" -gt "$LIMITE" ] && RESUMO="$RESUMO (+$((TOTAL-LIMITE)) outras)"
```

Regras:

- **Sem merges** (`--no-merges`): "Merge pull request #61" não informa nada.
- **Só `feat:`/`fix:`**: `chore:`/`docs:` não interessam a quem vai testar.
- **Mantém o escopo como rótulo**: `fix(gestao): X` → `gestao: X`.
- **Ordem cronológica** (`--reverse`), itens unidos por `; `.
- **Teto de 3 itens**, com `(+N outras)` no fim — senão uma release com 15 `fix:` gera mensagem gigante.
- Se `RESUMO` sair **vazio** (nenhum `feat`/`fix` no intervalo), usar só `branch@hash` / a tag, sem o ` — `.
- **Nada de `$0`..`$9` nos blocos deste arquivo**: o carregador de slash command substitui esses placeholders pelos argumentos da invocação. Um `awk '{... $0 ...}'` aqui chega ao agente já corrompido (com `/gerar-versao ota produção`, o `$0` virou `ota`). Por isso a junção usa `paste`/`sed`, que dispensa `$0`.

### O1) Guarda de mudança nativa

Reclassifique os arquivos modificados **desde o último build** (tag de versão, ignorando tags `-ota`):

```bash
LAST_BUILD_TAG=$(git tag --list 'v*' --sort=-v:refname | grep -v -- '-ota' | head -1)
git diff --name-only ${LAST_BUILD_TAG:+$LAST_BUILD_TAG..HEAD}
```

- Se **não houver** `LAST_BUILD_TAG` → abortar: "sem build base (nenhuma tag de versão); gere um build antes de publicar OTA".
- Se algum arquivo for **NATIVO** (mesma classificação do passo 4) → **abortar** com aviso, listando os arquivos: "mudança nativa detectada — não chega via OTA; rode o modo build (`/gerar-versao --build`)".
- Se houver **AMBIGUO** (`package.json`/`-lock`) → mesma pergunta do passo 4; resposta "sim" (tem nativo) → abortar pelo mesmo motivo.

> A guarda O1 vale para **os dois canais** — mudança nativa não chega via OTA nem em preview. No canal `preview`, rodar o diff na branch atual (`${LAST_BUILD_TAG}..HEAD`).

### O1.5) Canal `preview` — atalho (sem tag, sem commit)

Se o canal for `preview`, **pular O2→O5 inteiros**. OTA preview é teste descartável: sem sub-versão `-ota.N`, sem `update-build-info.js` (o `buildInfo.ts` fica o do build base), sem commit, sem tag, sem release, sem push.

1. Lint só com `--lint` (igual O3).
2. Mostrar o resumo:

```
Modo:           OTA preview (eas update) — a versão NÃO muda
Versão:         X.Y.Z (mantida)
runtimeVersion: X.Y.Z (mantido)
Base build:     LAST_BUILD_TAG
Branch:         $BRANCH_ATUAL (mantida)
Commits desde LAST_TAG: N
  (até 15 primeiros, em formato oneline)
```

3. **Em `--dry-run`, pare aqui** com "[dry-run] nenhuma alteração feita". Fora dele, imprimir a saída final:
   - `[OK] OTA preview validado na branch $BRANCH_ATUAL — nada foi commitado/tagueado.`
   - Próximo passo (rodar manualmente), com o `$RESUMO` do passo O0: `npx eas update --branch preview --environment preview --platform android --message "preview $BRANCH_ATUAL@<hash-curto-do-HEAD> — $RESUMO"`
     - Ex.: `--message "preview main@3544adc — gestao: exibir a mensagem da API no estado vazio da lista; login: web usa a API de autenticacao oficial"`
   - Lembrete: só aparelhos com build do canal **preview** e `runtimeVersion` X.Y.Z recebem; o canal `production` não é afetado.

**Fim do caminho OTA preview.** Os passos O2→O6 abaixo valem só para o canal `production`.

### O2) Calcular a sub-versão OTA

```bash
CURRENT_VERSION=$(node -p "require('./package.json').version")
BASE="v$CURRENT_VERSION"
LAST_OTA_N=$(git tag --list "${BASE}-ota.*" | sed -E 's/.*-ota\.([0-9]+)$/\1/' | sort -n | tail -1)
NEXT_N=$(( ${LAST_OTA_N:-0} + 1 ))
OTA_TAG="${BASE}-ota.${NEXT_N}"
```

Conferir que `OTA_TAG` não existe (abortar se existir):

```bash
git rev-parse "$OTA_TAG" 2>/dev/null && echo "EXISTE_LOCAL"
git ls-remote --tags origin "refs/tags/$OTA_TAG"
```

### O3) Lint

Igual ao build: por padrão **não roda**; só com `--lint`. Se rodar e falhar, abortar.

### O4) Resumo (sem confirmação)

Mostre o resumo e **siga direto** para a execução — não peça confirmação ao usuário:

```
Modo:           OTA (eas update) — a versão NÃO muda
Versão:         X.Y.Z (mantida)
runtimeVersion: X.Y.Z (mantido)
Base build:     LAST_BUILD_TAG
Tag OTA:        OTA_TAG
Branch:         main (saindo de $ORIGINAL_BRANCH, se aplicável)
Commits desde LAST_TAG: N
  (até 15 primeiros, em formato oneline)
```

**Em `--dry-run`, pare aqui** com "[dry-run] nenhuma alteração feita". Fora do `--dry-run`, prossiga automaticamente para O5.

### O5) Executar

```bash
node scripts/update-build-info.js
git add src/utils/buildInfo.ts
git commit -m "chore: ota $OTA_TAG sobre $BASE"
git tag "$OTA_TAG"
git push --follow-tags origin main
gh release create "$OTA_TAG" --generate-notes --title "$OTA_TAG"
```

- **Não** rodar `npm version` — `version`, `runtimeVersion` e `versionCode` ficam intactos.
- `update-build-info.js` regenera `src/utils/buildInfo.ts` (`COMMIT_HASH` + `RELEASED_AT`); o commit `chore: ota ...` carrega esse arquivo pro bundle.
- Se falhar entre o `git commit` e o `gh release create`, **não faça rollback automático**. Reporte onde parou e como continuar (ex: "tag local criada mas push falhou; rode `git push --follow-tags origin main`").

### O6) Saída final

Imprimir, em sucesso:

- `[OK] OTA $OTA_TAG preparado — versão $CURRENT_VERSION mantida.`
- Se houve troca de branch: `NOTA: você começou em "$ORIGINAL_BRANCH", agora está em main. Pra voltar: git checkout $ORIGINAL_BRANCH`.
- Próximo passo (publicar o OTA), com o `$RESUMO` do passo O0: `npx eas update --branch production --environment production --platform android --message "$OTA_TAG — $RESUMO"`
  - Ex.: `--message "v1.21.1-ota.7 — gestao: exibir a mensagem da API no estado vazio da lista"`
- Lembrete: a "Versão $CURRENT_VERSION" exibida no app **não muda**; nos aparelhos que baixarem o OTA, só o campo `OTA <id> (data)` será atualizado.

## Resultado

- **Sucesso (build production)**: release `vNEW_VERSION` criada (commit + tag pushados + GitHub Release) e o usuário sabe qual comando de build rodar.
- **Sucesso (OTA production)**: tag `OTA_TAG` criada (commit do build-info + tag + GitHub Release) **sem alterar a versão**, e o usuário sabe qual `eas update` rodar.
- **Sucesso (preview, OTA ou build)**: validações passaram na branch atual, **nenhuma alteração em git** (sem commit/tag/release/push), e o usuário sabe qual comando `eas` do canal preview rodar.
- **Falha**: reportar exatamente em qual passo falhou e o estado atual (ex: "passo B5/O5 falhou em `gh release create`; commit e tag já estão em origin, basta rodar `gh release create <tag> --generate-notes --title <tag>`").

## Exceções

- **Nunca execute `eas` (`eas build`, `eas submit`, `eas update`).** O skill só vai até criar commit/tag/GitHub Release; o comando `eas` é apenas **impresso** na saída (B6/O6) para o usuário rodar manualmente. Vale para os dois caminhos.
- `expo prebuild` é **proibido** — nunca rode, mesmo se algum erro sugerir isso.
- Não edite arquivos em `Faisao/android/**` diretamente. No caminho build, o hook do `npm version` cuida das edições (`strings.xml`, `build.gradle`). No caminho OTA, nada nativo é tocado. O versionamento é local (`eas.json` → `appVersionSource: "local"`, sem `autoIncrement`).
- Não use `--no-verify`, `--force` ou variações destrutivas em git sem autorização explícita.
- Não há confirmação final: o resumo (B4/O4) é informativo e o fluxo prossegue automaticamente. Confirmação só existe nos passos de **escolha** (método, bump, ambíguo). Se o usuário interromper no meio (Ctrl+C), reportar como cancelado sem fazer nenhuma mudança parcial.

## Contexto pra dúvidas

Detalhes sobre Expo/EAS, Conventional Commits, OTA vs build, estrutura do projeto: [Faisao/docs/expo-eas-resumo.md](../../Faisao/docs/expo-eas-resumo.md).
