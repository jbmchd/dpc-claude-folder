# Glossário de domínio — DPC

Dicionário vivo dos termos de negócio e técnicos que aparecem nas tarefas do ecossistema DPC (ApiDPC, DPC, Faisao, DpcInventario). Serve para que qualquer pessoa — inclusive não-dev — entenda o vocabulário usado nos cards.

## Como este arquivo é mantido
- O command [`/explicar`](../commands/explicar.md) **consulta** este glossário antes de explicar uma tarefa e **complementa** com termos novos que encontrar.
- Ao adicionar um termo: uma linha por termo, ordem alfabética dentro da seção, definição em 1–2 frases em linguagem simples. Se o termo for específico do DPC e a definição não for certa, registrar com `(confirmar com tech lead)` em vez de inventar.
- Não duplicar: se o termo já existe, refinar a definição existente.

## Termos de negócio / fiscais

| Termo | Significado |
|---|---|
| CFOP | Código Fiscal de Operações e Prestações — código numérico que classifica a natureza de uma operação de circulação de mercadoria ou serviço na nota fiscal. |
| EDI | Electronic Data Interchange — troca eletrônica e padronizada de documentos (pedidos, notas, etc.) entre sistemas de empresas diferentes, sem digitação manual. |
| Simples Nacional | Regime tributário simplificado para micro e pequenas empresas, com recolhimento unificado de impostos. |

## Termos técnicos / da plataforma

| Termo | Significado |
|---|---|
| OTA | Over-The-Air update — atualização do app Faisao entregue direto pelo EAS Update, sem gerar novo APK/build na loja. Ver fluxo em `/gerar-versao`. |
| WMS | Warehouse Management System — sistema de gestão de armazém/estoque; no ecossistema é o DpcInventario. |

## Schemas / fontes de dados

| Termo | Significado |
|---|---|
| consinco | Schema Oracle principal do ERP usado pelo ApiDPC. |
| poseidon | Schema Oracle acessível pelo MCP DPC. |
| dovemail | Schema acessível pelo MCP DPC. |
