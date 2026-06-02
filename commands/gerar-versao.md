Seu objetivo é gerar uma nova release do projeto Faisão, decidindo automaticamente entre OTA (EAS Update) e build novo (EAS Build) a partir das mudanças desde a última tag.

Caminho do projeto: `d:/Joabe/Documents/dev/projetos/dpc/workspace/Faisao`

## Argumentos aceitos

`/gerar-versao [tipo] [--ota|--build] [--lint] [--dry-run]`

- `tipo` (opcional): `patch` | `minor` | `major` | `x.y.z` específico. Se omitido, pergunte ao usuário (com a recomendação destacada).
- `--ota` / `--build`: força o método de entrega (default = autodetectado).
- `--lint`: roda `npm run lint` antes da release (por padrão o lint **não** roda).
- `--dry-run`: simula, sem executar nada. Aborta se não estiver em main (não troca de branch).

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

**Bump recomendado:**
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

**Aplicar flags:**
- `--build` → forçar `build`
- `--ota` → forçar `ota` (se houver NATIVO, **avisar** que mudanças nativas não chegam via OTA)

### 5) Decidir o bump

Calcule os 3 candidatos a partir da versão atual `X.Y.Z`:
- `patch` → `X.Y.(Z+1)`
- `minor` → `X.(Y+1).0`
- `major` → `(X+1).0.0`

- Se o `tipo` foi passado como argumento: valide (`patch`/`minor`/`major`/regex `^\d+\.\d+\.\d+$`) e use direto. Se inválido, abortar.
- Se não foi passado: chamar `AskUserQuestion` mostrando as 4 opções (patch, minor, major, custom) com a recomendação destacada como **(RECOMENDADO)**. Opção 4 (custom) pede o `x.y.z`.

### 6) Regras automáticas após escolha do bump

- Se o bump escolhido for `major` e método = `ota`: **forçar build novo**. Avisar: "major sobe runtimeVersion → OTA não atinge APKs antigos. Forçando build."
- Persistir `NEW_VERSION` e `TAG=v$NEW_VERSION` para os próximos passos.

### 7) Tag não pode existir

```bash
git rev-parse $TAG 2>/dev/null && echo "EXISTE_LOCAL"
git ls-remote --tags origin refs/tags/$TAG
```

Abortar se já existir local ou no remote.

### 8) Lint

Por padrão o lint **não roda** (é pulado). Só rode se foi passado `--lint`:

```bash
npm run lint
```

Se rodar e falhar, abortar reportando os erros (o usuário pediu o lint explicitamente, então não force a release).

### 9) Confirmação final

Mostre o resumo:

```
Versão:   X.Y.Z → NEW_VERSION
Tag:      vNEW_VERSION
Branch:   main (saindo de $ORIGINAL_BRANCH, se aplicável)
Método:   OTA (eas update)   |   build novo (Play Store)
Commits desde LAST_TAG: N
  (até 15 primeiros, em formato oneline)
```

Pergunte via `AskUserQuestion` "Confirmar release $TAG?" (sim/não).

**Em `--dry-run`, pare aqui** com "[dry-run] nenhuma alteração feita".

### 10) Executar

```bash
npm version $NEW_VERSION
git push --follow-tags origin main
gh release create $TAG --generate-notes --title "$TAG"
```

- `npm version` dispara o hook `bump-app-version.js`, que propaga a versão pra `app.json` (`expo.version`), `runtimeVersion` (`app.json` + `strings.xml`) e o `build.gradle` (`versionName` + incremento do `versionCode`), e cria commit `vNEW_VERSION` + tag local.
- Se algo falhar entre `npm version` e o `gh release create`, **não faça rollback automático**. Reporte exatamente onde falhou e instrua o usuário a continuar manualmente (ex: "tag local criada mas push falhou; rode `git push --follow-tags origin main`").

### 11) Saída final

Imprimir, em sucesso:

- `[OK] Release $TAG criada.`
- **Versão e versionCode gerados** (sempre exibir): leia o `versionCode` já incrementado em `android/app/build.gradle` (ex.: `grep versionCode android/app/build.gradle`) e imprima a linha: `Versão gerada: $NEW_VERSION  |  versionCode: <valor lido>`.
- Se houve troca de branch: `NOTA: você começou em "$ORIGINAL_BRANCH", agora está em main. Pra voltar: git checkout $ORIGINAL_BRANCH`.
- Próximo passo, **só o do método escolhido**:
  - **OTA**: `npx eas update --branch production --platform android --message "$TAG"`
  - **Build**: imprimir as duas formas de gerar + enviar pro Play:
    - Build + envio automático (um passo só): `npx eas build --platform android --profile production --auto-submit`
    - Ou separado: `npx eas build --platform android --profile production` e, após o build pronto, `npx eas submit --platform android --profile production --latest`
    - Nota: o `submit` publica no track **internal** (config em `eas.json` → `submit.production.android`). Promover para produção depois pelo Play Console (https://play.google.com/console). Alternativa manual: baixar o AAB e subir pelo console.

## Resultado

- **Sucesso**: release `$TAG` criada (commit + tag pushados + GitHub Release com release notes auto-geradas) e o usuário sabe qual é o próximo comando.
- **Falha**: reportar exatamente em qual passo falhou e o estado atual (ex: "passo 10 falhou em `gh release create`; tag e commit já estão em origin, basta rodar `gh release create $TAG --generate-notes --title $TAG`").

## Exceções

- `expo prebuild` é **proibido** — nunca rode, mesmo se algum erro sugerir isso.
- Não edite arquivos em `Faisao/android/**` diretamente. O hook do `npm version` já cuida das edições necessárias: `strings.xml` (runtimeVersion) e `build.gradle` (`versionName` + `versionCode`). O versionamento é local (`eas.json` → `appVersionSource: "local"`, sem `autoIncrement`); o `versionCode` é incrementado pelo hook a cada release.
- Não use `--no-verify`, `--force` ou variações destrutivas em git sem autorização explícita.
- Se o usuário interromper no meio (Ctrl+C ou "não" na confirmação), reportar como cancelado sem fazer nenhuma mudança parcial.

## Contexto pra dúvidas

Detalhes sobre Expo/EAS, Conventional Commits, OTA vs build, estrutura do projeto: [Faisao/docs/expo-eas-resumo.md](../../Faisao/docs/expo-eas-resumo.md).
