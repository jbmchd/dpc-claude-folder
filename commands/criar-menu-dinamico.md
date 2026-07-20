# /criar-menu-dinamico

**Objetivo:** criar um menu dinâmico no DPC (nó + vínculo pai + permissão de grupo), sem abrir o front, chamando os mesmos endpoints da ApiDPC que a tela de Menus Dinâmicos usa. **Default: ambiente `tst`.** Produção (`prd`) **somente** quando o usuário pedir explicitamente (ex.: "criar em produção", "em prd").

**Entrada:** descrição do menu — título, ícone, nome da rota (`acessar`) e o menu pai. Se algo faltar, o agente pergunta.

**Saída:** menu criado (`menu.dpc_menu_dinamico` + `menu.dpc_menu_pai`) e permissão concedida (Oracle + Postgres) aos grupos do JOABE (B.I e T.I); resumo final com o `cod_menu` gerado **e**, sempre, o bloco com os **dados para criar o mesmo menu em produção pela tela** (ver seção "Dados para criação em produção").

**Não faz:** operar em **alpha**; SQL de escrita direto; commit/push; persistir o token JWT. Produção só a pedido explícito (com aprovação reforçada `sim, produção` no agente).

---

## Fluxo

Acionar o `Agente Menu Dinâmico` passando a descrição recebida.

- Se `{"status": "erro"}` → exibir o `motivo` e **encerrar** (orientar a corrigir a pré-condição que falhou).
- Se `{"status": "ok"}` → exibir o resumo do agente (`cod_menu`, título, `acessar`, pai, grupos, ambiente), lembrar de **deslogar/logar** no DPC para o menu aparecer **e** exibir **sempre** o bloco **Dados para criação em produção** (ver seção abaixo) — mesmo quando o ambiente criado foi `tst`.

O agente já cuida internamente de: pedir o token, health-checks, coleta dos dados, resolução do pai, validação da rota, **pausa de aprovação obrigatória** e execução.

## Pré-condições (o agente aborta com mensagem clara se falhar)

- **Ambiente** definido: `tst` (default) ou `prd` (só a pedido explícito). Na dúvida, o agente assume `tst`.
- Token JWT colado pelo usuário — **do mesmo ambiente** (tst↔tst, prd↔prd).
- ApiDPC no ar, na base do ambiente:
  - `tst`: `http://localhost:8004/api/status` (subir com `php artisan serve --host=0.0.0.0 --port=8004` — sem Docker).
  - `prd`: `https://apidpc.dpcnet.com.br/api/status` (servidor de produção — não subir nada).
- MCP DPC no ar (`dpc_health`) e, em `prd`, confirmando leitura contra produção.

**Informações fixas** (idusuario 21950, login JOABE, grupos B.I `201` e T.I `1`, `cod_aplicativo` 134473, ambiente default `tst`, base URLs por ambiente) já estão embutidas no próprio `agente-menu-dinamico.md`.

> **Produção:** o agente exige token de prd, resolve o pai/`cod_menu` na base de prd e faz **aprovação reforçada** (confirmação `sim, produção`). Ver seção "Seleção de ambiente" do `agente-menu-dinamico.md`.

## Dados para criação em produção (sempre exibir quando `status: ok`)

Toda vez que a criação terminar com `{"status": "ok"}`, **além** do resumo, exibir **obrigatoriamente** um bloco com os dados para o usuário **criar/replicar o mesmo menu em produção** pela tela `Administração > Sistemas > Menus Dinâmicos`. Vale mesmo quando o ambiente criado foi `tst` (caso mais comum); quando já foi `prd`, apresentar como referência de replicação.

Preencher com os valores efetivamente usados na criação:

```
Dados para criar este menu em PRODUÇÃO (tela Menus Dinâmicos):

  Título:         <titulo>
  Rota (acessar): <acessar>
  Ícone:          <icone>
  Menu pai:       <titulo do pai>   ⚠ selecionar pelo NOME na tela
                  (cuidado com homônimos: escolha o nó que aparece no
                   sidebar, não um nó interno de mesmo título)
  É menu:         <S/N>
  Status:         Ativo
  Baixar ícone:   <S/N>
  Grupos:         <grupos que devem ter acesso>

  ⚠ Antes de criar em prod, a rota "<acessar>" precisa já estar
    DEPLOYADA no front de produção, senão o clique dá "Acesso negado".
```

O `cod_menu_pai` numérico do `tst` **não** entra nesse bloco — em produção o pai é escolhido pelo nome na tela e o `id` pode ser diferente.

**Encerramento:** informar o resultado (menu criado ou motivo do bloqueio), exibir o bloco **Dados para criação em produção** (quando `status: ok`) e o próximo passo (relogar no DPC; a rota `acessar` precisa existir no front para não dar "Acesso negado").
