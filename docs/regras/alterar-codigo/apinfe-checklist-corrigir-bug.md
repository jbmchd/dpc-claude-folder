# ApiNFE — Checklist: corrigir bug

> Estende [_checklist-base-bug.md](_checklist-base-bug.md). Convenções: [apinfe-convencoes.md](apinfe-convencoes.md).

### Camadas a verificar
- Controller → Repository → Model (`app/*.php`) → Oracle. Não há Services neste projeto.
- Repositories de integração: `SpedNFeRepository` (SEFAZ), `SenigRepository` (SOAP), `DaRepository` (DANFE).
- Commands agendados (`senig:averbar`) — o mesmo repository costuma ser usado por rota **e** por cron.
- Consumidor: tela *Contabilidade → Gestão de Entrada* no DPC (`process.env.ENDERECO_APINFE`).

### Regras específicas
- Preservar as chaves do JSON de retorno (`entrada`, `evento`, `nsu`, `pessoa`, `xml`, `pdf`) — o DPC lê por nome.
- Erro é `['error' => 1, 'mensagem' => ...]` (**`mensagem`**, não `msg`).
- Nunca trocar `response()->json()` por `echo`; nunca voltar ao padrão `$request->auth`.
- Queries Oracle validadas no **MCP DPC** antes de virar código.
- Alterou `$fillable` de model? Lembre que ele é a lista do `SELECT`, e `DB::raw()` ali resolve a conexão **default**.
- Não incluir a coluna `certificado` em retorno de consulta.

### Antes de culpar o código
- `.env` carregado? Lumen 10 não auto-carrega — confira `bootstrap/app.php` intacto.
- `DB_CONNECTION_ORACLE` aponta para `oracle` ou `oracle_tst`? O bug pode ser "ambiente errado".
- `TIPO_AMBIENTE` (1 prod / 2 homologação) bate com o esperado? `sefazDownload()` força produção.
- Erro 500 com body vazio é o comportamento normal de `APP_DEBUG=false` — ler o log do container, não o response.
- Falha ao ler PFX (`error:0308010C`) = legacy provider do OpenSSL; validar com `openssl list -providers`.
- Cooldown de NSU: `liberadaProximaConsulta()` pode estar barrando a consulta legitimamente.

### Validação extra
- Testar com token ausente/expirado (401/400) — o token vai em **query string**, não no header.
- Para fluxo SEFAZ, validar com empresa que tenha certificado **ativo e não vencido**.
- Para Senig, usar `--dry-run` e `--chave=` antes de qualquer execução real (**não existe ambiente de homologação**).
- Conferir se o gatilho automático continua gravando `cod_msg` correto em `dpc_historico_gatilho`.

### Testes e deploy
- Não há suíte de testes real — validar manualmente pela tela do DPC e pelos logs.
- `docker exec apinfe-app bash -c "ls -t /var/www/storage/logs/*.log | head -1 | xargs tail -80"`.
- Após alterar código de comando agendado, `supervisorctl`/cron não precisam de restart (o scheduler relê a cada minuto); alterou config/`.env` → `kill -USR2 1` no PHP-FPM.
