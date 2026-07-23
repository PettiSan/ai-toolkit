---
description: Gera o relatório de entrega do dia anterior com base nas movimentações do Trello, formatado para WhatsApp.
model: claude-haiku-4-5-20251001
---

# /trello-report

Gera o relatório de entrega do dia anterior com base nas movimentações do Trello.

## Como funciona

Toda a lógica (member ID, cálculo de datas, credenciais, chamadas à API do Trello, filtro
de candidatos por data+lista antes de buscar detalhes por card — evita o bug conhecido de
`GET /members/me/cards` retornar todos os cards de todos os boards sem filtro —,
classificação por prefixo, formatação) está em
[`trello-report.js`](trello-report.js) — um script único, sem composição de shell (sem
`$()`/`${}`/`&&`/heredoc/loop), pra que a chamada Bash seja sempre literal e nunca caia no
gate de "shell syntax que não pode ser analisada estaticamente" do Claude Code.

Este comando é **global** — roda de qualquer diretório, não depende de estar dentro do
`smartcob-monorepo` nem de nenhum outro repo.

## Passo único

Execute o comando literal abaixo (sem variável, sem argumento — o caminho é fixo):

```bash
node C:\Users\filip\projects\ai-toolkit\commands\trello-report.js
```

O script já resolve `TRELLO_API_KEY`/`TRELLO_TOKEN` (env var primeiro, fallback pro Windows
Credential Manager) e imprime o relatório pronto no formato WhatsApp.

### Se a saída tiver `ERRO: TRELLO_API_KEY/TRELLO_TOKEN não encontradas`

Pare e peça ao usuário:

> *"Não encontrei `TRELLO_API_KEY` / `TRELLO_TOKEN` no ambiente nem no Windows Credential Manager. Configure de uma das formas: (Linux/WSL) `export TRELLO_API_KEY=...` em `~/.zshrc`; (Windows) rode `claude-mcp-setup/setup.ps1` do repositório `PettiSan/ai-toolkit`. Depois rode `/trello-report` de novo."*

### Se a saída tiver uma linha `⚠️ NO_DOING_CARD`

Não há card em Doing atribuído ao usuário. Pergunte:

> *"Não há card em Doing atribuído a você. O que quer colocar na seção 'No que estou trabalhando'?"*

Aguarde a resposta, substitua a seção `🔧 *No que estou trabalhando*` pelo texto fornecido, e
**remova a linha `⚠️ NO_DOING_CARD`** antes de apresentar o relatório final.

### Se a saída tiver uma seção `⚠️ AMBIGUOUS_CARDS`

O script não conseguiu classificar um ou mais cards por prefixo nem por palavra-chave no
nome/descrição/labels. Pergunte ao usuário, agrupando todos os cards ambíguos na mesma
pergunta:

> *"O card '[nome]' não tem prefixo reconhecido e não consegui identificar o projeto pela descrição. Qual projeto é esse? (WEBCHAT-GENERICO, WEBCHAT-ITAU, PORTAL-GENERICO, PORTAL-ITAU, PORTAL-EMPRESA, LANDING PAGE, DESIGN-SYSTEM, MONOREPO)"*

Classifique manualmente na seção correta e **remova a seção `⚠️ AMBIGUOUS_CARDS`** antes de
apresentar o relatório final.

### Caso contrário

Apresente a saída do script ao usuário exatamente como veio (é o relatório final, já
formatado para colar no WhatsApp).

## Regras de negócio (referência)

- **Segunda-feira:** o relatório agrega sexta + sábado + domingo. Qualquer outro dia: "ontem"
  = dia anterior completo, fuso de Brasília (UTC-3 fixo, sem horário de verão desde 2019).
- As 3 seções (Revisão/Homologação/Produção) são categorias distintas — cada card aparece em
  **uma só**, na lista mais avançada que atingiu no período (ordem Produção > Homologação >
  Revisão). Seção sem nenhum card no período é omitida inteira.
- Prefixos de projeto: [`smartcob-monorepo/docs/governanca/trello-refs.md`](../../smartcob-monorepo/docs/governanca/trello-refs.md)
  é a fonte real — a tabela vem **duplicada** dentro do script (`PREFIXES`/`PREFIX_KEYWORDS`)
  porque este comando roda de qualquer diretório, fora do monorepo. Se a tabela mudar lá,
  atualizar também as constantes no script.
- "Meus cards" = cards onde o member ID resolvido (`GET /members/me?fields=id`) aparece em
  `idMembers` — nunca `GET /members/me/cards` (bug: retorna todos os cards de todos os
  boards, sem filtro de data, >180 cards já visto em produção).
- Caminho do script é fixo pro clone Windows do ai-toolkit
  (`C:\Users\filip\projects\ai-toolkit`, per o `README.md` do próprio repo). Se o clone
  mudar de lugar, atualizar o caminho aqui.
