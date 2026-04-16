# Checklist base — corrigir bug

> Esqueleto comum de correção de bug para qualquer projeto do workspace. Cada projeto tem um delta em `<projeto>-checklist-corrigir-bug.md` com comandos e camadas específicas.

### Reprodução e escopo
- [ ] Reproduzir o bug em ambiente controlado (passos, dados, usuário/token, rede).
- [ ] Identificar a camada exata onde o bug ocorre.
- [ ] Verificar se o mesmo padrão existe em outros pontos; anotar para avaliar junto.

### Análise de impacto
- [ ] Listar chamadores / consumidores do código afetado.
- [ ] Verificar dependências diretas (banco, integrações, filas, estado global).
- [ ] Revisar testes que cobrem a área; rodar a suíte local.

### Correção mínima
- [ ] Aplicar a menor alteração possível que resolve o problema.
- [ ] Manter o padrão do projeto (formato de resposta, tratamento de exceção, camadas existentes).
- [ ] Não remover validações sem substituí-las por alternativa segura.

### Validação
- [ ] Testar o cenário que falhava e confirmar a correção.
- [ ] Testar cenários de sucesso do mesmo fluxo (filtros, outros registros).
- [ ] Testar fluxos relacionados que compartilham estado, endpoint ou componente.
- [ ] Testar borda: token inválido/expirado, rede off, dados vazios.

### Regressão e entrega
- [ ] Rodar a suíte de testes do projeto.
- [ ] Revisar o diff: sem logs de debug, sem alteração em arquivos não relacionados.
- [ ] Registrar em `desenvolvimento.md` a causa-raiz e o que foi alterado.
