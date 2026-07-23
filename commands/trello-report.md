---
description: Gera o relatório de entrega do dia anterior com base nas movimentações do Trello, formatado para WhatsApp.
model: claude-haiku-4-5-20251001
---

# /trello-report

Gera o relatório de entrega do dia anterior com base nas movimentações do Trello.

## Passos

### 1. Calcular datas

Use Bash para calcular as datas em UTC. Brasília é UTC-3 fixo (sem horário de verão desde 2019). Regra:

- **Segunda-feira (DOW=1):** o relatório agrega **sexta + sábado + domingo** (o relatório de segunda inclui o fim de semana inteiro).
- **Qualquer outro dia:** "ontem" = dia anterior completo no fuso de Brasília.

Execute o bloco abaixo (todos os comandos começam com `date`, auto-permitido pelo Claude Code):

```bash
DOW=$(date +%u)
if [ "$DOW" = "1" ]; then
  RANGE_START=$(date -u -d "$(date -d '3 days ago' +%Y-%m-%d) 03:00:00" +%Y-%m-%dT%H:%M:%S.000Z)
  ONTEM_LABEL="$(date -d '3 days ago' +%d/%m) a $(date -d 'yesterday' +%d/%m/%Y)"
else
  RANGE_START=$(date -u -d "$(date -d 'yesterday' +%Y-%m-%d) 03:00:00" +%Y-%m-%dT%H:%M:%S.000Z)
  ONTEM_LABEL=$(date -d 'yesterday' +%d/%m/%Y)
fi
RANGE_END=$(date -u -d "$(date +%Y-%m-%d) 03:00:00" +%Y-%m-%dT%H:%M:%S.000Z)
echo "$RANGE_START"
echo "$RANGE_END"
echo "$ONTEM_LABEL"
echo "$DOW"
```

A saída tem 4 linhas: RANGE_START, RANGE_END, ONTEM_LABEL, DOW. Em dias de semana ONTEM_LABEL é a data de ontem (`DD/MM/YYYY`); em segundas é o intervalo do fim de semana (`DD/MM a DD/MM/YYYY`).

### 2. Buscar actions do board

⚠️ **Não use `mcp__trello__get_recent_activity`.** O tool do `@delorenj/mcp-server-trello` v1.7 não aceita o parâmetro `since` e `limit=300` em boards ativos retorna 500KB+ (ultrapassa o limite de tokens da tool e dispara fallback de chunked-read em sub-agente, que queima tokens em larga escala). Use curl direto à API do Trello, que aceita filtros server-side.

#### 2.1 Garantir credenciais no env

Antes do curl, verifique se `TRELLO_API_KEY` e `TRELLO_TOKEN` estão setadas:

```bash
[ -n "${TRELLO_API_KEY}" ] && [ -n "${TRELLO_TOKEN}" ] && echo "ok" || echo "missing"
```

Se "missing", tente buscar do Windows Credential Manager (funciona quando o usuário rodou `claude-mcp-setup/setup.ps1` do ai-toolkit pessoal). O `powershell.exe` está acessível a partir do shell que o Claude Desktop usa (Bash com interop):

```bash
export TRELLO_API_KEY=$(powershell.exe -NoProfile -Command "Import-Module CredentialManager; (Get-StoredCredential -Target 'claude-trello-api-key').GetNetworkCredential().Password" 2>/dev/null | tr -d '\r\n')
export TRELLO_TOKEN=$(powershell.exe -NoProfile -Command "Import-Module CredentialManager; (Get-StoredCredential -Target 'claude-trello-token').GetNetworkCredential().Password" 2>/dev/null | tr -d '\r\n')
```

Re-verifique com o mesmo `[ -n ... ] && echo "ok"`. Se ainda "missing", pare e peça ao usuário:

> *"Não encontrei `TRELLO_API_KEY` / `TRELLO_TOKEN` no ambiente nem no Windows Credential Manager. Configure de uma das formas: (Linux/WSL) `export TRELLO_API_KEY=...` em `~/.zshrc`; (Windows) rode `claude-mcp-setup/setup.ps1` do repositório `PettiSan/ai-toolkit`. Depois rode `/trello-report` de novo."*

#### 2.2 Buscar actions

```bash
curl -s "https://api.trello.com/1/boards/65452685593555d57aa6aaf7/actions?since=${RANGE_START}&filter=updateCard:idList&limit=1000&key=${TRELLO_API_KEY}&token=${TRELLO_TOKEN}"
```

Parâmetros:

- `since=${RANGE_START}` — filtra server-side por data. Em terças–sextas vem só ontem; em segundas vem sex+sáb+dom.
- `filter=updateCard:idList` — retorna **apenas** actions de "card movido entre listas". Descarta comentários, edits de descrição, criações, etc.
- `limit=1000` — teto de segurança. Depois dos filtros server-side, realisticamente <50 actions/dia.

**Não delegue parsing para sub-agente.** O JSON resultante é pequeno (kilobytes, não megabytes) e o parse na próxima etapa é trivial. Se ainda houver erro de "exceeds maximum allowed tokens" mesmo com esses filtros, é sinal de bug — pare e avise o usuário.

### 3. Identificar o usuário e filtrar

**3.1 — Resolver "meus cards" a partir do token.** Com as credenciais já carregadas (Step 2.1), descubra quais cards são seus — sem precisar de `TRELLO_MEMBER_ID`:

```bash
curl -s "https://api.trello.com/1/members/me/cards?fields=id&key=${TRELLO_API_KEY}&token=${TRELLO_TOKEN}"
```

Monte um conjunto `MEUS_CARD_IDS` com os `id` retornados — são os cards onde você é membro (atribuído). Como os ids do Trello são globais, a interseção por id é segura sem filtrar por board.

> Por que assim: o token que o dev configura pro MCP **já é a identidade dele**. `GET /members/me/cards` devolve os cards dele direto. A skill se auto-escopa por quem roda, sem nenhuma env de member id.

**3.2 — Filtrar as actions.** O curl do Step 2.2 já trouxe só `updateCard:idList` com `>= RANGE_START`. Resta:

1. **Filtrar `action.date < RANGE_END`** — descarta actions de hoje (o `since` não tem upper bound).
2. **Filtrar por `data.listAfter.id` entre os 3 destinos relevantes:**

- `654be3bfa4f058f3010bdf90` → **To Review (PR)** → seção *Revisão*
- `65525b515bd021894e00dcfb` → **To Validate (Homologacao/Preprod) - Negócio** → seção *Homologação*
- `654be3c561f40a9dc0f49467` → **To Validate (Producao) - Negócio** → seção *Produção*

3. **Filtrar por dono:** manter só cards cujo `data.card.id` ∈ `MEUS_CARD_IDS`.

Para cada action que sobrar, extraia `data.card.name`, `data.card.shortLink` e `data.listAfter.id`.

**Dedup por estado mais avançado:** se o mesmo card aparecer em mais de uma lista no período, conte **uma vez só**, na lista mais avançada — ordem **Produção > Homologação > Revisão**.

### 4. Agrupar por prefixo de projeto

Classifique cada card pelo prefixo no início do nome. Este comando é global (roda de qualquer diretório) — a tabela de prefixos vem embutida aqui, não por referência a um arquivo de repositório:

| Prefixo                 | Escopo                                                        | Repositório        |
| ------------------------ | -------------------------------------------------------------- | -------------------- |
| `[PORTAL-GENERICO]`     | portal-generico                                                | smartcob-monorepo  |
| ~~`[PORTAL-BRADESCO]`~~ | 🛑 **DESCONTINUADO** — portal fora do ar, não aceitar card    | smartcob-monorepo  |
| `[PORTAL-ITAU]`         | portal-itau                                                    | smartcob-monorepo  |
| `[PORTAL-EMPRESA]`      | portal-empresa                                                 | smartcob-monorepo  |
| `[LANDING PAGE]`        | portal-landing-page                                            | smartcob-monorepo  |
| `[DESIGN-SYSTEM]`       | libs/design-system                                             | smartcob-monorepo  |
| `[MONOREPO]`            | Infra, pipeline, configuração geral do repo                   | smartcob-monorepo  |
| `[WEBCHAT-GENERICO]`    | —                                                               | lovabledue-chat    |
| `[WEBCHAT-ITAU]`        | —                                                               | chat-mm-itau       |

> ⚠️ **Fonte da verdade real:** [`smartcob-monorepo/docs/governanca/trello-refs.md`](../../smartcob-monorepo/docs/governanca/trello-refs.md) (path relativo só resolve se `ai-toolkit` e `smartcob-monorepo` forem clonados lado a lado em `~/projects/`). Se um portal novo for adicionado ou um prefixo mudar lá, atualize a tabela acima manualmente — é a mesma duplicação assumida deliberadamente para o comando funcionar fora do monorepo.

**Regra para prefixos ambíguos ou não reconhecidos:**

Se um card não começar com nenhum dos prefixos da tabela acima (ex: começa com número de ticket como `[1445][WEBCHAT]`, variação de capitalização, ou prefixo desconhecido), antes de classificar:

1. Busque os detalhes completos do card via API:
   ```bash
   curl -s "https://api.trello.com/1/cards/{cardId}?fields=name,desc,labels&key=${TRELLO_API_KEY}&token=${TRELLO_TOKEN}"
   ```
2. Leia o nome completo, descrição e labels para inferir o projeto. Use palavras-chave no texto (ex: "Itaú", "Genérico", "monorepo", "portal", "webchat") para determinar a classificação correta.
3. Se conseguir inferir com confiança, classifique no projeto correspondente sem perguntar.
4. **Somente se ainda não conseguir determinar** com clareza, pergunte ao usuário antes de gerar o relatório:
   > *"O card '[nome]' não tem prefixo reconhecido e não consegui identificar o projeto pela descrição. Qual projeto é esse? (WEBCHAT-GENERICO, WEBCHAT-ITAU, PORTAL-GENERICO, PORTAL-BRADESCO, PORTAL-ITAU, PORTAL-EMPRESA, LANDING PAGE, DESIGN-SYSTEM, MONOREPO)"*

Se houver múltiplos cards ambíguos, agrupe todos na mesma pergunta.

### 5. Verificar card em Doing atribuído ao usuário

Use o MCP tool `mcp__trello__get_cards_by_list_id` com `listId=654526d8e848f7b27e32f3e7` (Doing — Apenas 1, Informar Data). A lista pode ter cards de vários membros — **mantenha só os que estão em `MEUS_CARD_IDS`** (o conjunto resolvido no Step 3.1).

- Se encontrar 1+ card seu: use para preencher a seção "No que estou trabalhando" com nome e link.
- Se não encontrar nenhum card seu: pergunte — *"Não há card em Doing atribuído a você. O que quer colocar na seção 'No que estou trabalhando'?"* — e aguarde a resposta antes de gerar o relatório.

### 6. Gerar o relatório

Formate a saída **exatamente** assim (WhatsApp usa `*texto*` para negrito):

```
📊 *Relatório de Ontem — {ONTEM_LABEL}*

🔍 *Em Revisão (PR)*

*[PREFIXO]* (N card(s))
• Nome do Card
  🔗 https://trello.com/c/shortLink
• Outro Card
  🔗 https://trello.com/c/shortLink

🏗️ *Para Homologação*

*[PREFIXO]* (N card(s))
• Nome do Card
  🔗 https://trello.com/c/shortLink

🚀 *Para Produção*

*[PREFIXO]* (N card(s))
• Nome do Card
  🔗 https://trello.com/c/shortLink

📦 *Total: N cards*

🔧 *No que estou trabalhando*

• Nome do Card em Doing
  🔗 https://trello.com/c/shortLink
```

Se não havia card em Doing, substitua o bloco final pela resposta que o usuário forneceu.

Regras de formatação:
- As 3 seções (`🔍 Em Revisão (PR)`, `🏗️ Para Homologação`, `🚀 Para Produção`) são categorias **distintas** — cada card aparece em **uma só**, na lista mais avançada que atingiu no período (ordem Produção > Homologação > Revisão). Não fundir nem duplicar.
- Omita prefixos que não tiveram nenhum card no período dentro de uma seção
- Se uma seção inteira (Revisão, Homologação ou Produção) não tiver nenhum card, **omita a seção inteira** (não exibir o header)
- Em segundas-feiras o título continua `📊 *Relatório de Ontem — {ONTEM_LABEL}*` — o `ONTEM_LABEL` já vem com o intervalo do fim de semana embutido pelo Step 1
- Não use markdown de links `[texto](url)` — o WhatsApp não renderiza isso; escreva a URL na linha seguinte com o emoji 🔗
- Exiba os grupos em ordem alfabética de prefixo dentro de cada seção
