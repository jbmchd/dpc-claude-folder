Seu objetivo é gerar uma nova release do projeto Faisão, decidindo entre OTA (EAS Update, **sem mexer na versão**) e build novo (EAS Build, **com bump de versão**) a partir das mudanças desde a última release.

Caminho do projeto: `d:/Joabe/Documents/dev/projetos/dpc/workspace/Faisao`

## Argumentos aceitos

`/gerar-versao [tipo] [--ota|--build] [--lint] [--dry-run]`

- `tipo` (opcional): `patch` | `minor` | `major` | `x.y.z` específico. **Só se aplica ao caminho build.** No caminho OTA é ignorado (não há bump). Se omitido no build, pergunte ao usuário (com a recomendação destacada).
- `--ota` / `--build`: força o método de entrega (default = autodetectado).
- `--lint`: roda `npm run lint` antes da release (por padrão o lint **não** roda).
- `--dry-run`: simula, sem executar nada. Aborta se não estiver em main (não troca de branch).

## Conceito-chave: OTA não mexe na versão

`runtimeVersion = expo.version` (1:1, ver `scripts/sync-runtime-version.js`). Por isso:

- **OTA** publica só o bundle JS sobre o build atual. **Não** bumpa `version` nem `runtimeVersion` — senão o OTA mudaria o `runtimeVersion` e **não chegaria** aos aparelhos já instalados. A "Versão X.Y.Z" exibida no app fica intacta; só o campo `OTA <id> (data)` (via `expo-updates`) é atualizado nos aparelhos que baixam. Mudanças nativas **não** vão por OTA.
- **Build** gera nova versão nativa (Play Store), bumpando `version` + `runtimeVersion` + `versionCode`.

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

### 2) Branch correta

```bash
git rev-parse --abbrev-ref HEAD
```

- Se != `main`:
  - **Em `--dry-run`**: abortar com "dry-run não troca de branch; rode sem --dry-run ou faça `git checkout main` manualmente".
  - **Modo normal**: rodar `git checkout main && git pull origin main`. Guardar a branch original em `ORIGINAL_BRANCH` para avisar no final.

### 3) Sync com origin

```bash
git fetch origin main
git rev-list --left-right --count main...origin/main
```

A saída é `<ahead>\t<behind>`. Abortar se `ahead > 0` (sugerir `git push`) ou `behind > 0` (sugerir `git pull`).

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

### O1) Guarda de mudança nativa

Reclassifique os arquivos modificados **desde o último build** (tag de versão, ignorando tags `-ota`):

```bash
LAST_BUILD_TAG=$(git tag --list 'v*' --sort=-v:refname | grep -v -- '-ota' | head -1)
git diff --name-only ${LAST_BUILD_TAG:+$LAST_BUILD_TAG..HEAD}
```

- Se **não houver** `LAST_BUILD_TAG` → abortar: "sem build base (nenhuma tag de versão); gere um build antes de publicar OTA".
- Se algum arquivo for **NATIVO** (mesma classificação do passo 4) → **abortar** com aviso, listando os arquivos: "mudança nativa detectada — não chega via OTA; rode o modo build (`/gerar-versao --build`)".
- Se houver **AMBIGUO** (`package.json`/`-lock`) → mesma pergunta do passo 4; resposta "sim" (tem nativo) → abortar pelo mesmo motivo.

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
- Próximo passo (publicar o OTA): `npx eas update --branch production --platform android --message "$OTA_TAG"`
- Lembrete: a "Versão $CURRENT_VERSION" exibida no app **não muda**; nos aparelhos que baixarem o OTA, só o campo `OTA <id> (data)` será atualizado.

## Resultado

- **Sucesso (build)**: release `vNEW_VERSION` criada (commit + tag pushados + GitHub Release) e o usuário sabe qual comando de build rodar.
- **Sucesso (OTA)**: tag `OTA_TAG` criada (commit do build-info + tag + GitHub Release) **sem alterar a versão**, e o usuário sabe qual `eas update` rodar.
- **Falha**: reportar exatamente em qual passo falhou e o estado atual (ex: "passo B5/O5 falhou em `gh release create`; commit e tag já estão em origin, basta rodar `gh release create <tag> --generate-notes --title <tag>`").

## Exceções

- **Nunca execute `eas` (`eas build`, `eas submit`, `eas update`).** O skill só vai até criar commit/tag/GitHub Release; o comando `eas` é apenas **impresso** na saída (B6/O6) para o usuário rodar manualmente. Vale para os dois caminhos.
- `expo prebuild` é **proibido** — nunca rode, mesmo se algum erro sugerir isso.
- Não edite arquivos em `Faisao/android/**` diretamente. No caminho build, o hook do `npm version` cuida das edições (`strings.xml`, `build.gradle`). No caminho OTA, nada nativo é tocado. O versionamento é local (`eas.json` → `appVersionSource: "local"`, sem `autoIncrement`).
- Não use `--no-verify`, `--force` ou variações destrutivas em git sem autorização explícita.
- Não há confirmação final: o resumo (B4/O4) é informativo e o fluxo prossegue automaticamente. Confirmação só existe nos passos de **escolha** (método, bump, ambíguo). Se o usuário interromper no meio (Ctrl+C), reportar como cancelado sem fazer nenhuma mudança parcial.

## Contexto pra dúvidas

Detalhes sobre Expo/EAS, Conventional Commits, OTA vs build, estrutura do projeto: [Faisao/docs/expo-eas-resumo.md](../../Faisao/docs/expo-eas-resumo.md).
