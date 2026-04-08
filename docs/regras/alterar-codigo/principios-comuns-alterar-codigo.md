# Princípios comuns de alteração de código

- Alterar apenas o necessário para a tarefa em questão, sem refatorar código adjacente ou ampliar escopo sem necessidade funcional clara.
- Seguir os padrões já existentes do projeto afetado, mesmo quando eles não coincidirem com a melhor prática mais moderna.
- Não sugerir migrações de stack, framework ou arquitetura fora do escopo explícito da tarefa.
- Manter comentários, mensagens técnicas e textos em português quando isso já for o padrão do projeto.
- Nunca alterar arquivos/pacotes em `node_modules/**`, sob nenhuma hipótese, exceto quando o usuário pedir explicitamente essa alteração na mesma mensagem.
