# Instalar o módulo DFe em um ambiente novo (produção)

> **Estado em 13/10/2026:** a **produção já está instalada** e idêntica à homolog (23 tabelas, 466 colunas, 83 constraints, 66 índices, 13 triggers, 13 sequences, 489 comentários — `dfe:replicar --estrutura` dá zero diferenças). Este documento serve a um ambiente **novo** e é o registro do que foi feito.

## Ordem (3 arquivos, todos convergentes)

Conectado como `POSEIDON`, arquivo inteiro com Alt+X, **DBMS_OUTPUT ligado**. Cada um serve a base vazia, parcial ou completa e pode ser repetido.

| # | Arquivo | O que faz |
|---|---|---|
| 1 | `ddl/01_estrutura_motor_dbeaver.sql` | 17 tabelas do motor (captura, normalização, conciliação, manifestação) |
| 2 | `ddl/02_estrutura_telas_dbeaver.sql` | 6 tabelas de tela (permissões, colunas, modelos, alerta) |
| 3 | `ddl/03_parametros_dbeaver.sql` | os 11 parâmetros `dfe_*` (só insere o que falta) |

Depois: `ddl/04_validacao_dbeaver.sql` (somente leitura, comparar com o ESPERADO de cada seção) e, com a ApiNFE no ar, **`dfe:replicar --estrutura`** contra a homolog: **zero diferenças = pronto**.

**Não rodar em produção:** tudo de `homolog/` (cadastro de teste e `dfe_conexao_erp`, que **quebra** a conciliação se existir lá). Em produção os dados vêm da replicação.

## O que foi aplicado em produção em 13/10/2026

Com os scripts antigos (hoje consolidados nos 3 acima), na ordem: apagar as 12 tabelas órfãs de 25/08, estrutura do motor e das telas, parâmetros. O `dfe:replicar --estrutura` fechou em zero diferenças.

Duas decisões que valem registro:

- **Tabelas legadas renomeadas.** A produção tinha `dpc_sefaz_usuario_empresa` (45 linhas), `dpc_sefaz_usuario_aba` (16) e `dpc_sefaz_empresa_alerta` (0), criadas à mão em 25/08/2026. Foram **renomeadas** para `dpc_dfe_*` com os dados preservados. A ApiDPC de produção (`master`) ainda lê os nomes antigos até o deploy, **que é só do Douglas, via PR**: enquanto isso, as telas Sefaz de permissão e alerta dão ORA-00942.
- **Aba `PROPRIAS`.** Dada em 13/10/2026 aos 4 usuários que tinham `SEM_CLASSIFICACAO` (DOUGLAS, LEONARDO, SERGIOSANTOS, WARLITON), com o carimbo `AJUSTE 2026-10-13 ABA PROPRIA PRD`. Sem isso, depois do deploy as notas próprias da DPC somem das outras abas e ninguém vê a aba nova — a tela não dá erro, só fica menor.

## O que falta para o módulo andar em produção

1. **Carga inicial** dos dados: `dfe:replicar --carga-inicial --confirmar`, pelo servidor 16 (rede de ~15 ms: do notebook é 10× mais lenta), acompanhada, **só com autorização explícita**. Antes, confirmar espaço no `TSD_POSEIDON` (eram ~1,9 GB a copiar e havia 43 MB livres nos arquivos atuais, com autoextensão).
2. **Ligar o sincronismo** (`dfe_replicacao_prd = 'S'` na homolog), também com autorização.
3. **Deploy da ApiDPC e do DPC** — só o Douglas, via PR.

Ver `docs/06_operacao-comandos.md` (`dfe:replicar`) e `docs/07_ddl-instalacao.md`.
