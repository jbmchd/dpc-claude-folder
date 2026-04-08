Seu objetivo é gerar o APK do Android do projeto Faisao.

## Regras de execução

1. Entrar no projeto do Faisao: `cd d:/Joabe/Documents/dev/projetos/dpc/Faisao`

2. **ANTES de buildar, atualizar hash e datetime da release em `src/utils/buildInfo.ts`:**
   - Executar:
     - `HASH=$(git rev-parse --short HEAD)`
     - `RELEASED_AT=$(date '+%d/%m %H:%M')`
     - `printf 'export const COMMIT_HASH = "%s";\nexport const RELEASED_AT = "%s";\n' "$HASH" "$RELEASED_AT" > src/utils/buildInfo.ts`
   - Garantir que o arquivo ficou com:
     - `export const COMMIT_HASH = "...";`
     - `export const RELEASED_AT = "dd/mm HH:MM";`

3. Executar sempre o fluxo confiável de build:
   ```bash
   cd android
   ./gradlew assembleRelease --warning-mode all
   cd ..
   ```

4. Validar obrigatoriamente se o artefato final existe em:
   - `android/app/build/outputs/apk/release/app-release.apk`

5. Conferir se o APK foi gerado com sucesso e:
   - Se sim, enviar o endereço do APK
   - Se não, reportar o erro encontrado durante a geração, já fornecendo uma possível solução

6. Nunca considerar sucesso apenas por logs intermediários; somente considerar sucesso quando o arquivo `.apk` existir no caminho final.

## Executar se o usuário pedir limpeza de cache

```bash
cd d:/Joabe/Documents/dev/projetos/dpc/Faisao
git status
rm -rf android/app/build
cd android
./gradlew clean
./gradlew assembleRelease --warning-mode all
cd ..
test -f android/app/build/outputs/apk/release/app-release.apk && ls -lh android/app/build/outputs/apk/release/app-release.apk
```
