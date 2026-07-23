---
description: Gera o relatório de entrega do dia anterior com base nas movimentações do Trello, formatado para WhatsApp.
model: claude-haiku-4-5-20251001
---

# /trello-report

Gera o relatório de entrega do dia anterior com base nas movimentações do Trello.

> **Pré-requisito:** `jq` precisa estar instalado e no PATH do shell que executa este comando (Windows: `winget install jqlang.jq`; Linux/WSL/macOS: `apt install jq` / `brew install jq`). Todo o parsing de JSON abaixo é feito com `jq` — não delegue pra `grep`/`sed`/`cut` nem para um sub-agente, é frágil em volume maior (ex: relatório de segunda-feira, com 3 dias de actions).

## Passos

### 0. Checar `jq` — gate obrigatório, não pule

```bash
jq --version
```

⚠️ **Se este comando falhar (`command not found` ou similar), PARE aqui.** Não improvise um caminho alternativo com `node`, `python`, ou script em outra linguagem/processo. Motivo: qualquer arquivo intermediário (`/tmp/actions.json` etc.) é escrito pelo **mesmo shell Bash** que rodou o `curl` — um processo `node`/`python` chamado à parte pode rodar num runtime diferente (ex.: Node nativo do Windows tentando ler um `/tmp` que só existe dentro do WSL, ou vice-versa), e o path simplesmente não existe do outro lado. Isso já quebrou em produção (`ENOENT` tentando ler `\\wsl.localhost\...\tmp\actions.json` que não existia). Se `jq` não estiver disponível, pare e diga ao usuário:

> *"`jq` não está disponível neste shell. Se você acabou de instalar (`winget install jqlang.jq` ou `apt install jq`), pode ser que o processo do Claude Code ainda tenha o PATH antigo — feche o app **completamente** (não só a janela/aba) e abra de novo, não apenas inicie uma sessão nova dentro do mesmo processo. Depois rode `/trello-report` de novo."*

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

A chamada real (com `curl` e o redirecionamento pra `/tmp/actions.json`) está no Step 3.2 — não repita aqui, é a mesma requisição. Parâmetros usados nela:

- `since=${RANGE_START}` — filtra server-side por data. Em terças–sextas vem só ontem; em segundas vem sex+sáb+dom.
- `filter=updateCard:idList` — retorna **apenas** actions de "card movido entre listas". Descarta comentários, edits de descrição, criações, etc.
- `limit=1000` — teto de segurança. Depois dos filtros server-side, realisticamente <50 actions/dia.

**Não delegue parsing para sub-agente.** O JSON resultante é pequeno (kilobytes, não megabytes) e o parse na próxima etapa é feito com `jq`. Se ainda houver erro de "exceeds maximum allowed tokens" mesmo com esses filtros, é sinal de bug — pare e avise o usuário.

### 3. Identificar o usuário e filtrar

⚠️ **Não use `GET /members/me/cards`.** Esse endpoint devolve **todos** os cards atribuídos a você em **todos os boards** que você acessa, sem filtro de data — no board da Smartcob isso já passou de 180 cards num teste real, quando o relatório só precisa de um punhado (tipicamente <10, o que sobrou depois do filtro de data+lista). Filtrar por dono é a **última** etapa, não a primeira — só nos candidatos que já sobreviveram ao filtro de data e lista.

**3.1 — Resolver seu member ID.** Uma chamada leve, só o id:

```bash
MY_MEMBER_ID=$(curl -s "https://api.trello.com/1/members/me?fields=id&key=${TRELLO_API_KEY}&token=${TRELLO_TOKEN}" | jq -r '.id')
```

**3.2 — Filtrar e deduplicar as actions com `jq`.** O curl do Step 2.2 já trouxe só `updateCard:idList` com `>= RANGE_START`. Salve a resposta em `/tmp/actions.json` e rode:

```bash
curl -s "https://api.trello.com/1/boards/65452685593555d57aa6aaf7/actions?since=${RANGE_START}&filter=updateCard:idList&limit=1000&key=${TRELLO_API_KEY}&token=${TRELLO_TOKEN}" > /tmp/actions.json

jq --arg end "$RANGE_END" '
  [.[]
   | select(.date < $end)
   | select(.data.listAfter.id as $l | ["654be3bfa4f058f3010bdf90","65525b515bd021894e00dcfb","654be3c561f40a9dc0f49467"] | index($l) != null)
   | {cardId: .data.card.id, cardName: .data.card.name, listId: .data.listAfter.id}]
  | group_by(.cardId)
  | map(max_by({"654be3bfa4f058f3010bdf90":1,"65525b515bd021894e00dcfb":2,"654be3c561f40a9dc0f49467":3}[.listId]))
' /tmp/actions.json > /tmp/candidates.json
```

Em uma passada, isso:

1. **Filtra `action.date < RANGE_END`** — descarta actions de hoje (o `since` não tem upper bound).
2. **Filtra por `data.listAfter.id`** entre os 3 destinos relevantes:
   - `654be3bfa4f058f3010bdf90` → **To Review (PR)** → seção *Revisão*
   - `65525b515bd021894e00dcfb` → **To Validate (Homologacao/Preprod) - Negócio** → seção *Homologação*
   - `654be3c561f40a9dc0f49467` → **To Validate (Producao) - Negócio** → seção *Produção*
3. **Deduplica por card na lista mais avançada** — ordem **Produção > Homologação > Revisão** — se o mesmo card aparecer em mais de uma lista no período, conta uma vez só.

**3.3 — Filtrar por dono, só nos candidatos que sobraram.** `/tmp/candidates.json` já é pequeno. Para cada card, uma única chamada busca ao mesmo tempo o pertencimento **e** os campos que o Step 4 vai precisar se o prefixo for ambíguo (evita uma segunda chamada pro mesmo card depois):

```bash
jq -c '.[]' /tmp/candidates.json | while read -r entry; do
  cardId=$(echo "$entry" | jq -r '.cardId')
  details=$(curl -s "https://api.trello.com/1/cards/${cardId}?fields=name,desc,labels,idMembers,shortLink&key=${TRELLO_API_KEY}&token=${TRELLO_TOKEN}")
  isMine=$(echo "$details" | jq --arg m "$MY_MEMBER_ID" '.idMembers | index($m) != null')
  if [ "$isMine" = "true" ]; then
    echo "$entry" | jq --argjson d "$details" '. + {name: $d.name, desc: $d.desc, labels: $d.labels, shortLink: $d.shortLink}'
  fi
done | jq -s '.' > /tmp/my_cards.json
```

`/tmp/my_cards.json` é a lista final pro relatório: só cards seus, já com `desc`/`labels` prontos caso o Step 4 precise deles.

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

1. `desc` e `labels` já estão em `/tmp/my_cards.json` (Step 3.3 já buscou — não faça uma nova chamada pro mesmo card).
2. Leia o nome completo, descrição e labels para inferir o projeto. Use palavras-chave no texto (ex: "Itaú", "Genérico", "monorepo", "portal", "webchat") para determinar a classificação correta.
3. Se conseguir inferir com confiança, classifique no projeto correspondente sem perguntar.
4. **Somente se ainda não conseguir determinar** com clareza, pergunte ao usuário antes de gerar o relatório:
   > *"O card '[nome]' não tem prefixo reconhecido e não consegui identificar o projeto pela descrição. Qual projeto é esse? (WEBCHAT-GENERICO, WEBCHAT-ITAU, PORTAL-GENERICO, PORTAL-BRADESCO, PORTAL-ITAU, PORTAL-EMPRESA, LANDING PAGE, DESIGN-SYSTEM, MONOREPO)"*

Se houver múltiplos cards ambíguos, agrupe todos na mesma pergunta.

### 5. Verificar card em Doing atribuído ao usuário

Use o MCP tool `mcp__trello__get_cards_by_list_id` com `listId=654526d8e848f7b27e32f3e7` (Doing — Apenas 1, Informar Data). A lista pode ter cards de vários membros — **mantenha só os que têm `MY_MEMBER_ID` (Step 3.1) em `idMembers`**.

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
