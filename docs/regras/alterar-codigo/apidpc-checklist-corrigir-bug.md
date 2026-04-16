# ApiDPC — Checklist: corrigir bug

> Estende [_checklist-base-bug.md](_checklist-base-bug.md).

### Camadas a verificar
- Controller, Service, Repository, Model ou integração externa.
- Chamadores: rotas, outros controllers ou jobs que usam o mesmo Repository/Service/Model.
- Dependências de banco: constraints, triggers, outras tabelas afetadas.
- Integrações Guzzle (NFe, Boleto, Pedido, Atendimento), FTP, filas.

### Regras específicas
- Manter formato de resposta JSON e tratamento de exceção do arquivo sendo editado.
- Sem SQL raw no Controller; não remover validações sem substituir.
- Adicionar `Log::warning/error` se o bug envolver falha silenciosa.
- Queries Oracle passam pelo MCP DPC antes de virar código — ver [apidpc-oracle-padroes.md §3](apidpc-oracle-padroes.md).

### Validação extra
- Verificar resposta (formato, HTTP codes) e comportamento com token inválido/expirado (401).
- Testar outro filtro/usuário no mesmo endpoint.
- Se houver migration, validar rollback/rerun em ambiente de teste.

### Testes e deploy
- `./vendor/bin/phpunit` ou `php artisan test`.
- Deploy em alpha/beta; monitorar logs (storage + Discord).
