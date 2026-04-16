# Checklist base — nova feature

> Esqueleto comum de implementação de feature para qualquer projeto do workspace. Cada projeto tem um delta em `<projeto>-checklist-nova-feature.md` com camadas e ferramentas específicas.

### Antes de codar
- [ ] Entender o domínio, dados envolvidos e contratos afetados.
- [ ] Verificar se já existe código/camada que possa ser reaproveitado ou estendido.
- [ ] Definir contrato da API (quando aplicável): método, path, body, formato de resposta.
- [ ] Verificar permissões, menus e autenticação que a nova feature exige.

### Estrutura
- [ ] Criar arquivos/módulos respeitando a organização existente do projeto.
- [ ] Manter separação de responsabilidades já usada (controller/service/repo, componente/estado, etc.).
- [ ] Reutilizar componentes/utilitários compartilhados sempre que fizer sentido.

### Estado e dados
- [ ] Escolher a forma de estado adequada (global, servidor, local) seguindo o padrão do projeto.
- [ ] Tratar loading, erro e estado vazio com os componentes existentes.
- [ ] Validar entradas; não expor erros crus em produção.

### Testes e build
- [ ] Escrever ao menos um teste cobrindo o fluxo principal.
- [ ] Rodar testes e build locais antes de entregar.
- [ ] Navegar pelos fluxos novos e testar casos de borda (401, offline, input inválido).

### Revisão final
- [ ] Nomenclatura alinhada ao padrão do projeto.
- [ ] Contrato de resposta no formato padrão, códigos HTTP coerentes.
- [ ] Sem lógica de negócio pesada no lugar errado (template, controller sem service, etc.).
- [ ] Registrar em `desenvolvimento.md` o escopo final e impactos.
