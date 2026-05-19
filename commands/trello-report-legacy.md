---
description: ⚠️ Versão legacy — só pra webchats (lovabledue-chat, chat-mm-itau). Canônica vive em smartcob-monorepo/.claude/commands/trello-report.md.
---

# /trello-report-legacy

> ⚠️ **Versão canônica vive em `smartcob-monorepo/.claude/commands/trello-report.md`.**
>
> Esta cópia (ai-toolkit) continua aqui pra cobrir os webchats (`lovabledue-chat`, `chat-mm-itau`) até a migração deles pro monorepo, e como registro pessoal. Foi renomeada de `trello-report.md` pra `trello-report-legacy.md` em maio/2026 pra evitar duplicação no autocomplete do Claude Code quando trabalhando no monorepo.
>
> Esta versão **não recebe** as melhorias da versão do monorepo:
>
> - Inclusão da lista `Done` como destino válido (cards de doc que pulam validação)
> - Agregação automática de sexta + sábado + domingo no relatório de segunda (sem perguntar)
> - Leitura de `TRELLO_MEMBER_ID` via env var
> - Header `✅ Finalizados` separado de `🚀 Para Produção`

Gera o relatório de entrega do dia anterior com base nas movimentações do Trello.

## Passos

### 1. Calcular datas

Use Bash para calcular as datas em UTC. Brasília é UTC-3 fixo (sem horário de verão desde 2019). "Ontem" = dia anterior completo no fuso de Brasília.

Execute o comando abaixo — começa com `date`, que é auto-permitido pelo Claude Code:

```bash
date -u -d "$(date -d 'yesterday' +%Y-%m-%d) 03:00:00" +%Y-%m-%dT%H:%M:%S.000Z && date -u -d "$(date +%Y-%m-%d) 03:00:00" +%Y-%m-%dT%H:%M:%S.000Z && date -d "yesterday" +%d/%m/%Y && date +%u
```

A saída tem 4 linhas: ONTEM_INICIO, ONTEM_FIM, ONTEM_LABEL, DAY_OF_WEEK.

### 2. Buscar actions do board

Use o MCP tool `trello_get_recent_activity` com `boardId=65452685593555d57aa6aaf7` e `limit=300`. Esse limite cobre ~6 dias de atividade do board com folga suficiente para capturar todas as movimentações de ontem.

### 3. Filtrar e processar

Do JSON retornado, filtre apenas as actions onde:
- `data.listAfter.id` == `65525b515bd021894e00dcfb` → **To Validate (Homologação/Preprod)**
- `data.listAfter.id` == `654be3c561f40a9dc0f49467` → **To Validate (Produção)**

Para cada action relevante, extraia:
- Nome do card: `data.card.name`
- Link: `https://trello.com/c/` + `data.card.shortLink`
- Lista destino: `data.listAfter.id`

Se o mesmo card aparecer múltiplas vezes na mesma lista (movido, voltado e movido de novo), conte apenas uma vez.

### 4. Agrupar por prefixo de projeto

Classifique cada card pelo prefixo no início do nome:

| Prefixo | Projeto |
|---------|---------|
| `[PORTAL-GENERICO]` | Portal Genérico |
| `[PORTAL-BRADESCO]` | Portal Bradesco |
| `[PORTAL-ITAU]` | Portal Itaú |
| `[PORTAL-EMPRESA]` | Portal Empresa |
| `[DESIGN-SYSTEM]` | Design System |
| `[MONOREPO]` | Monorepo |
| `[WEBCHAT-GENERICO]` | Webchat Genérico |
| `[WEBCHAT-ITAU]` | Webchat Itaú |

**Regra para prefixos ambíguos ou não reconhecidos:**

Se um card não começar com nenhum dos prefixos da tabela acima (ex: começa com número de ticket como `[1445][WEBCHAT]`, variação de capitalização, ou prefixo desconhecido), antes de classificar:

1. Busque os detalhes completos do card via API:
   ```bash
   curl -s "https://api.trello.com/1/cards/{cardId}?fields=name,desc,labels&key=${TRELLO_API_KEY}&token=${TRELLO_TOKEN}"
   ```
2. Leia o nome completo, descrição e labels para inferir o projeto. Use palavras-chave no texto (ex: "Itaú", "Genérico", "monorepo", "portal", "webchat") para determinar a classificação correta.
3. Se conseguir inferir com confiança, classifique no projeto correspondente sem perguntar.
4. **Somente se ainda não conseguir determinar** com clareza, pergunte ao usuário antes de gerar o relatório:
   > *"O card '[nome]' não tem prefixo reconhecido e não consegui identificar o projeto pela descrição. Qual projeto é esse? (WEBCHAT-GENERICO, WEBCHAT-ITAU, PORTAL-GENERICO, PORTAL-BRADESCO, PORTAL-ITAU, PORTAL-EMPRESA, DESIGN-SYSTEM, MONOREPO)"*

Se houver múltiplos cards ambíguos, agrupe todos na mesma pergunta.

### 5. Verificar card em Doing atribuído ao usuário

Member ID do usuário: `64a4994dd6033175ad5e5a07`

Use o MCP tool `trello_get_cards_by_list` com `listId=654526d8e848f7b27e32f3e7` (Doing — Apenas 1, Informar Data). A lista pode ter cards de vários membros — filtre pelo `idMembers` que contenha `64a4994dd6033175ad5e5a07`.

- Se encontrar card do usuário: use-o para preencher a seção "No que estou trabalhando" com nome e link
- Se não encontrar nenhum card do usuário: pergunte — *"Não há card em Doing atribuído a você. O que quer colocar na seção 'No que estou trabalhando'?"* — e aguarde a resposta antes de gerar o relatório

### 6. Gerar o relatório

Formate a saída **exatamente** assim (WhatsApp usa `*texto*` para negrito):

```
📊 *Relatório de Ontem — {ONTEM_LABEL}*

🏗️ *Para Homologação (Staging)*

*[PREFIXO]* (N card(s))
• Nome do Card
  🔗 https://trello.com/c/shortLink
• Outro Card
  🔗 https://trello.com/c/shortLink

🚀 *Para Produção*

*[PREFIXO]* (N card(s))
• Nome do Card
  🔗 https://trello.com/c/shortLink

📦 *Total: N cards entregues ontem*

🔧 *No que estou trabalhando*

• Nome do Card em Doing
  🔗 https://trello.com/c/shortLink
```

Se não havia card em Doing, substitua o bloco final pela resposta que o usuário forneceu.

Regras de formatação:
- Omita prefixos que não tiveram nenhum card no dia
- Se uma seção inteira (Homologação ou Produção) não tiver cards, exiba apenas: `_(nenhum card ontem)_`
- Não use markdown de links `[texto](url)` — o WhatsApp não renderiza isso; escreva a URL na linha seguinte com o emoji 🔗
- Exiba os grupos em ordem alfabética de prefixo dentro de cada seção

### Nota sobre segundas-feiras

Se hoje for segunda-feira, "ontem" é domingo. Pergunte ao usuário: *"Hoje é segunda — quer o relatório de domingo mesmo, ou prefere ver o de sexta-feira?"* antes de executar.
