# /criar-menu-dinamico

**Objetivo:** criar um menu dinâmico no DPC (nó + vínculo pai + permissão de grupo) em ambiente **tst**, sem abrir o front, chamando os mesmos endpoints da ApiDPC que a tela de Menus Dinâmicos usa.

**Entrada:** descrição do menu — título, ícone, nome da rota (`acessar`) e o menu pai. Se algo faltar, o agente pergunta.

**Saída:** menu criado (`menu.dpc_menu_dinamico` + `menu.dpc_menu_pai`) e permissão concedida (Oracle + Postgres) aos grupos do JOABE (B.I e T.I); resumo final com o `cod_menu` gerado.

**Não faz:** operar em alpha/prd; SQL de escrita direto; commit/push; persistir o token JWT.

---

## Fluxo

Acionar o `Agente Menu Dinâmico` passando a descrição recebida.

- Se `{"status": "erro"}` → exibir o `motivo` e **encerrar** (orientar a corrigir a pré-condição que falhou).
- Se `{"status": "ok"}` → exibir o resumo do agente (`cod_menu`, título, `acessar`, pai, grupos, ambiente) e lembrar de **deslogar/logar** no DPC para o menu aparecer.

O agente já cuida internamente de: pedir o token, health-checks, coleta dos dados, resolução do pai, validação da rota, **pausa de aprovação obrigatória** e execução.

## Pré-condições (o agente aborta com mensagem clara se falhar)

- Token JWT colado pelo usuário.
- ApiDPC no ar em `http://localhost:8004/api/status` (subir com `php artisan serve --host=0.0.0.0 --port=8004` — sem Docker).
- MCP DPC no ar (`dpc_health`).

**Informações fixas** (idusuario 21950, login JOABE, grupos B.I `201` e T.I `1`, `cod_aplicativo` 134473, ambiente tst, base URL) já estão embutidas no próprio `agente-menu-dinamico.md`.

**Encerramento:** informar o resultado (menu criado ou motivo do bloqueio) e o próximo passo (relogar no DPC; a rota `acessar` precisa existir no front para não dar "Acesso negado").
