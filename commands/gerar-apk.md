Seu objetivo é gerar o APK do Android do projeto Faisao.

## Fluxo principal

Execute tudo em um único bloco encadeado:

```bash
cd d:/Joabe/Documents/dev/projetos/dpc/workspace/Faisao &&
HASH=$(git rev-parse --short HEAD) &&
RELEASED_AT=$(date '+%d/%m %H:%M') &&
printf 'export const COMMIT_HASH = "%s";\nexport const RELEASED_AT = "%s";\n' "$HASH" "$RELEASED_AT" > src/utils/buildInfo.ts &&
cd android &&
./gradlew assembleRelease --warning-mode all &&
cd .. &&
test -f android/app/build/outputs/apk/release/app-release.apk &&
ls -lh android/app/build/outputs/apk/release/app-release.apk
```

## Resultado

- **Sucesso**: confirmar o caminho do APK gerado.
- **Falha**: reportar em qual passo falhou e sugerir solução.
- Nunca considerar sucesso apenas por logs intermediários; somente quando o arquivo `.apk` existir no caminho final.

## Se o usuário pedir limpeza de cache

Adicionar estes passos **antes** do `./gradlew assembleRelease`:

```bash
cd d:/Joabe/Documents/dev/projetos/dpc/workspace/Faisao &&
git status &&
rm -rf android/app/build &&
cd android &&
./gradlew clean &&
./gradlew assembleRelease --warning-mode all &&
cd .. &&
test -f android/app/build/outputs/apk/release/app-release.apk &&
ls -lh android/app/build/outputs/apk/release/app-release.apk
```
