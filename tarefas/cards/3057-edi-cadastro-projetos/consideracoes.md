# Considerações – Card #3057 EDI - Cadastro de Projetos

## O que deve ser feito

Criar a tela **CadastroProjetosEdi** no projeto DPC Aplicativos, migrando a funcionalidade equivalente do sistema Maracanã.

## Entendimento da tarefa

- A tela existe no Maracanã e precisa ser portada para o DPC Aplicativos.
- O ponto de acesso no DPC já está mapeado: menu `CadastroProjetosEdi`.
- O layout deve seguir o padrão DPC: botões **Novo** e **Editar** no topo da tela e tabela de dados abaixo.
- O código fonte da tela no Maracanã está disponível como referência (ver imagem {5} em `conteudo-do-card.md`).

## Escopo aparente

- Nova tela de listagem de Projetos EDI com botões de ação no topo.
- Integração com a API para listar, criar e editar projetos EDI.
- A tela deve estar acessível a partir do menu `CadastroProjetosEdi` no DPC Aplicativos.

## Pontos a clarificar no planejamento

- Quais campos compõem um "Projeto EDI" (verificar no Maracanã e na API).
- Existe endpoint na ApiDPC para projetos EDI ou precisa ser criado?
- A tela de edição/criação é modal ou navegação para nova tela?
- Permissões e perfis de acesso necessários.
