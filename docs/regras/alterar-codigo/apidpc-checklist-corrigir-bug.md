# ApiDPC – Checklist: corrigir bug

## Checklist: corrigir bug sem gerar regressão

### Reprodução e escopo

- [ ] Reproduzir o bug em ambiente local ou de teste (passos, dados, usuário/token).
- [ ] Identificar o ponto exato: Controller, Service, Repository, Model ou integração externa.
- [ ] Verificar se o mesmo padrão existe em outros endpoints; anotar para corrigir junto se necessário.

### Análise de impacto

- [ ] Listar chamadores: quais rotas, outros controllers ou jobs usam o mesmo Repository/Service/Model.
- [ ] Verificar dependências de banco (constraints, triggers, outras tabelas afetadas).
- [ ] Checar integrações (APIs externas, FTP, filas) que o fluxo usa.
- [ ] Revisar testes existentes que cobrem a área; rodar suite local.

### Correção

- [ ] Fazer a alteração mínima necessária para corrigir o bug.
- [ ] Manter padrão do projeto: resposta JSON, tratamento de exceção, uso de Repository/Service.
- [ ] Não introduzir SQL raw em Controller; não remover validações sem substituir por alternativa segura.
- [ ] Adicionar ou ajustar log (Log::warning/error) se o bug for relacionado a falha silenciosa.

### Validação

- [ ] Testar novamente o cenário que falhava e confirmar que o bug foi resolvido.
- [ ] Testar cenários de sucesso do mesmo endpoint (ex.: outro filtro, outro usuário).
- [ ] Testar fluxos relacionados que usam o mesmo Repository/Service/Model.
- [ ] Verificar resposta da API (formato, códigos HTTP) e comportamento com token inválido/expirado (401).

### Regressão e deploy

- [ ] Rodar suite de testes: `./vendor/bin/phpunit` ou `php artisan test`.
- [ ] Se houver migrations, validar em ambiente de teste (rollback/rerun).
- [ ] Revisar diff (git): sem código de debug ou alteração em arquivo não relacionado.
- [ ] Deploy em alpha/beta; monitorar logs (storage + Discord) após deploy.
