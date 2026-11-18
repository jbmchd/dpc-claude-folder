# /telegram-tarefa

**Objetivo:** ler mensagens do Telegram (via MCP `telegram`) **somente dentro de uma janela de tempo informada**, extrair as demandas pedidas nela e gerar o **planejamento** de cada uma. Fluxo irmão do [`/tarefa-completa`](tarefa-completa.md), mas **termina no planejamento** — não executa.

**Entrada (todas obrigatórias):**
1. **Chat/grupo/canal** — link, `@username`, id numérico ou nome (resolver com `list_dialogs`). **Obrigatório: se não vier, perguntar qual.**
2. **Início** — data **e hora** (ex.: `05/11 08:30`). **Obrigatório.**
3. **Fim** — data **e hora** (ex.: `09/11 10:44`). **Opcional: omitido = até agora.**

> **Chat não informado:** chamar `list_dialogs` (só a lista de chats, **sem ler nenhuma mensagem**), mostrar os ~10 mais ativos (a lista já vem por atividade recente, com não lidas) e **perguntar qual** — `AskUserQuestion` com os 4 primeiros como opções e o restante no texto; "Outro" aceita qualquer chat. Detalhes em [telegram-tarefa.md §2](../docs/regras/gerenciar-regras/telegram-tarefa.md). Nunca escolher o chat por conta própria.
>
> **Regra de ferro:** nunca ler o chat inteiro. Se faltar o **chat** ou o **início** — ou se vier algo vago ("últimas mensagens", "tudo", "N mensagens") — **parar e perguntar** (`AskUserQuestion`/texto). Sem chute.
>
> **Única exceção — mensagem em anexo:** quando uma mensagem da janela **responde a outra** (`[reply:ID]`), essa mensagem referenciada também é lida, **mesmo fora da janela**, só para melhorar o entendimento. Só ela (e a cadeia de respostas dela), nunca as vizinhas. Ver Fase 1, passo 5.
>
> **Fim omitido por completo = até agora** (autorizado pelo usuário): lê do início informado em diante, até o momento atual.
>
> **Componentes omitidos dentro do início/fim** (autorizado pelo usuário) assumem o valor **corrente** (agora): ano, **mês**, **dia** e **hora/minuto**. Ex.: `08:00` → hoje às 08:00; `05 08:00` → dia 05 do mês corrente; `05/11` (sem hora) → 05/11 na hora atual. Isso vale só para o que faltar **dentro** de um início/fim informado; um início ou fim **inteiramente ausente** continua exigindo pergunta.
>
> **Só dias informados, sem hora** (autorizado pelo usuário, 18/11/2026): `dias 17 e 18`, `dia 17`, `17 a 19`, `de 17/11 a 18/11` significam **dias inteiros**. Início = **00:00 do primeiro dia**; fim = **23:59:59 do último dia**, e se esse dia for **hoje** (ou futuro) o fim é **agora**. Isso **prevalece** sobre "hora omitida = agora", que vale só quando o usuário digita uma data/hora de início ou fim e esquece parte dela. Ex. (agora = 18/11 09:55): `dias 17 e 18` → `2026-11-17 00:00` até `2026-11-18 09:55`; `dia 12` → `2026-11-12 00:00` até `2026-11-12 23:59:59`. Sem ano/mês, usar os correntes; sem **chat**, continua perguntando.
>
> Antes de ler, repetir a janela interpretada, já com os valores preenchidos (`de AAAA-MM-DD hh:mm até AAAA-MM-DD hh:mm`), e exigir fim > início. Se o preenchimento produzir fim ≤ início ou um fim no futuro, perguntar.

**Saída:** uma pasta por demanda em `.claude/.work-items/` (via importar → classificar → planejar), cada uma com `planejamento.md`, e um relatório final.

**Não faz:** alterar código, criar branch, commitar, fazer push/PR, executar tarefa, enviar/responder mensagem no Telegram, ler ou resumir mensagens **fora** da janela (**exceto** a mensagem em anexo/respondida, lida só como contexto — Fase 1, passo 5).

**MCP:** usar **apenas** o MCP `telegram`. Se ele não estiver disponível na sessão, avisar e aguardar — sem curl/script/alternativa.

**Algoritmo de leitura, regras de agrupamento, mídia e formato do relatório:** [telegram-tarefa.md](../docs/regras/gerenciar-regras/telegram-tarefa.md).

---

## Fluxo

### Fase 0 — Validar a janela
Aplicar a regra de ferro acima. Só avançar com chat resolvido + início + fim confirmados.

**Fuso:** o usuário fala em horário **local**, mas o MCP devolve timestamps em **UTC**. Ler o relógio (`date "+%Y-%m-%d %H:%M:%S %z"`), converter início/fim para UTC antes de comparar e mostrar o relatório em horário local. Ver [§2 do doc](../docs/regras/gerenciar-regras/telegram-tarefa.md).

### Fase 1 — Ler a janela (Haiku/Sonnet)
1. Localizar o primeiro id da janela por **sondagem** com `fetch_since` (`limit 1`, `oldestFirst`) — ids crescem com o tempo.
2. Paginar com `fetch_since` (`oldestFirst`, `limit 200`) **até a primeira mensagem com timestamp > fim** ou o fim do chat. Parar ali: nada depois do fim é lido nem listado.
3. Descartar o que cair fora de `[início, fim]` (as sondas são só para achar o id; não entram na análise).
4. Ignorar **mensagens de serviço** (`[no text]` sem mídia: entrada/saída de membro, "Incluso …").
5. **Mensagem em anexo (contexto):** toda mensagem da janela com `[reply:ID]` responde a outra. **Ler essa mensagem também** — `get_message(chat, ID)`, sem chamada extra se o id já estiver entre as lidas — **mesmo que esteja fora da janela**, para entender melhor o pedido. Se ela também tiver `[reply:ID]`, seguir a cadeia, **até 3 níveis**; mensagem apagada/não encontrada → registrar e seguir. Regras: só a mensagem referenciada (**nunca as vizinhas**); ela **não amplia a janela, não conta nela e não gera demanda por si** (o pedido continua sendo o da mensagem dentro da janela); fica marcada como **contexto**. Detalhes em [§3.1 do doc](../docs/regras/gerenciar-regras/telegram-tarefa.md).
6. Mídia (imagem/PDF/áudio) **só das mensagens dentro da janela e das mensagens em anexo (contexto)**, e só quando necessária para entender o pedido.
7. Janela com mais de ~500 mensagens → informar a contagem e confirmar antes de continuar (as mensagens em anexo não entram nessa contagem).

### Fase 2 — Extrair demandas
Separar **pedidos** de conversa solta, agrupando por resposta/autor/assunto e **usando as mensagens em anexo (contexto) para entender o que a mensagem da janela quer dizer** ("feito?", "isso mesmo", "ajusta aquilo"). Para cada demanda: título, autor, ids e horários das mensagens-fonte, projeto provável (ApiDPC, DPC, Faisao, DpcInventario, ApiNFE) e card Trello citado (`#NNNN`), se houver. **Agrupamento ou classificação ambígua → perguntar** em vez de decidir. Nenhuma demanda encontrada → dizer isso e encerrar.

### Fase 3 — Importar (Haiku)
`Agente Importar Tarefa`, **uma vez por demanda**, sequencial. Passar o texto das mensagens-fonte como conteúdo da tarefa (+ chat, ids, janela e anexos baixados), **e as mensagens em anexo numa seção separada "Contexto (mensagem respondida)"**, com id, data/hora e autor, deixando claro que estão fora do pedido em si. Card Trello citado → importar como card; senão, pasta por slug.
`{"status":"erro"}` → exibir o motivo e parar aquela demanda; seguir com as demais, listando-a no relatório.

### Fase 4 — Classificar (Sonnet)
`Agente Classificar Tarefa` por pasta → `complexidade` e `motivo`.

### Fase 5 — Planejar (sempre Sonnet; Opus só como recomendação)
**Sempre** `Agente Planejar Tarefa Sonnet`, independentemente da `complexidade`. O `Agente Planejar Tarefa Opus` **nunca** é acionado automaticamente: para demandas `"complexa"`, apenas **recomendar** o Opus no relatório (Fase 6) e só rodá-lo se o usuário confirmar. Informar ao usuário que o planejamento usa Sonnet antes de spawnar. Gera `planejamento.md` (com a seção **Branch** apenas como planejamento — a branch **não** é criada).

### Fase 6 — Relatório
Apresentar: janela lida (e quantas mensagens), tabela de demandas (título · autor · projeto · complexidade · pasta/`planejamento.md`), mensagens **ignoradas** (para o usuário corrigir se algo era pedido), **mensagens em anexo lidas fora da janela** (id · data/hora · autor · a qual mensagem da janela respondem), dúvidas em aberto, e — se houver demandas `"complexa"` — a **recomendação de refazer o planejamento delas com Opus** (listar quais e o motivo), perguntando se o usuário confirma. Sem confirmação, não usar Opus.

---

**Encerramento:** deixar claro que **nada foi executado**. Próximo passo por demanda: revisar o `planejamento.md` e rodar [`/executar-tarefa`](executar-tarefa.md) (ou [`/tarefa-completa`](tarefa-completa.md) sobre a pasta/card).
