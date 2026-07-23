---
description: Gera o relatório de entrega do dia anterior com base nas movimentações do Trello, formatado para WhatsApp.
model: claude-sonnet-5
---

# /trello-report

Gera o relatório de entrega do dia anterior com base nas movimentações do Trello.

O comando olha para **três listas do board**, e só elas:

- **To Validate (Homologacao/Preprod) - Negócio** e **To Validate (Producao) - Negócio** — por *movimentação* no período (Steps 2–3).
- **Doing (Apenas 1, Informar Data)** — por *estado atual*, para a seção "No que estou trabalhando" (Step 5).

Movimentação para qualquer outra lista (inclusive **To Review (PR)**) não entra no relatório. Decisão deliberada: o relatório informa o que ficou validável, não o que entrou em revisão.

> **Sem dependência externa.** Todo o parsing é feito por você, lendo o JSON que os `curl` devolvem. Não use `jq`, `node`, `python`, `grep`/`sed`/`cut` para extrair campos, e **não delegue a sub-agente**. Os filtros server-side do Step 2.2 deixam a resposta na casa dos kilobytes — pequena o bastante para você processar direto. Se ainda assim vier grande a ponto de ser truncada, o Step 2.2 tem um gate que detecta isso; pare ali, não improvise parser.

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

⚠️ O `export` não sobrevive entre chamadas da tool Bash — cada chamada é um shell novo. Repita as duas linhas de `export` no início de **todo** bloco que use `${TRELLO_API_KEY}` / `${TRELLO_TOKEN}`.

#### 2.2 Buscar actions

```bash
curl -s "https://api.trello.com/1/boards/65452685593555d57aa6aaf7/actions?since=${RANGE_START}&before=${RANGE_END}&filter=updateCard:idList&limit=1000&fields=data,date&memberCreator=false&member=false&key=${TRELLO_API_KEY}&token=${TRELLO_TOKEN}"
```

Parâmetros — todos server-side, é o que mantém a resposta pequena:

- `since=${RANGE_START}` — limite inferior. Em terças–sextas cobre só ontem; em segundas cobre sex+sáb+dom.
- `before=${RANGE_END}` — limite superior. **Não é opcional.** Sem ele a resposta inclui as actions de *hoje*, que o Step 3.2 descartaria de qualquer forma — mas aí o descarte acontece tarde demais: medido em 22/07/2026, a mesma janela de um dia devolveu 78 actions / 43KB sem `before` e 11 actions / 6KB com. Os 43KB estouram o corte da tool Bash.
- `filter=updateCard:idList` — retorna **apenas** actions de "card movido entre listas". Descarta comentários, edits de descrição, criações, etc.
- `limit=1000` — teto de segurança.
- `fields=data,date` + `memberCreator=false` + `member=false` — corta os blocos de membro embutidos em cada action, que não são usados em lugar nenhum deste comando. Não muda **quais** actions voltam, só o tamanho de cada uma.

**Gate de truncamento — obrigatório antes de seguir.** A tool Bash corta a saída em 30.000 caracteres. Confira que a resposta é um JSON completo, isto é, **termina com `]`**. Se não terminar, a saída foi truncada e você está vendo dados parciais — **pare**, não processe. Avise o usuário e refaça buscando um dia de cada vez (repetir o curl com `since`/`before` cobrindo cada dia do intervalo, e somar os resultados). Nunca gere relatório a partir de resposta truncada.

### 3. Filtrar e identificar posse

⚠️ **Não use `GET /members/me/cards`.** Esse endpoint devolve **todos** os cards atribuídos a você em **todos** os boards que você acessa, sem filtro de data — no board da Smartcob isso já passou de 180 cards num teste real, quando o relatório só precisa de um punhado. Pior que o custo: num teste ao vivo esse desenho produziu **falso positivo**, listando na seção "Doing" um card que não era do usuário. Filtrar por dono é a **última** etapa, não a primeira — só nos candidatos que já sobreviveram ao filtro de data e lista.

#### 3.1 Resolver seu member ID

```bash
curl -s "https://api.trello.com/1/members/me?fields=id&key=${TRELLO_API_KEY}&token=${TRELLO_TOKEN}"
```

A resposta é `{"id":"..."}`. Guarde esse valor como `MY_MEMBER_ID`.

Compare sempre a string **inteira**. Ids de membro do mesmo board costumam compartilhar prefixo (`64a4994d…` e `64a47851…` são pessoas diferentes) — comparação por prefixo produz falso positivo.

#### 3.2 Filtrar e deduplicar as actions

Esta etapa é sua, não de uma ferramenta. Execute os 4 estágios **na ordem**, e anote a contagem de cada um — os números são o que prova que você filtrou em vez de estimar.

**Regras de execução, não negociáveis:**

- **Enumere, não resuma.** Percorra as actions uma a uma. Nada de amostragem, de "e outros", de "aproximadamente", de reticências.
- **Não delegue a sub-agente** e não escreva script para fazer isso.
- Se por qualquer motivo você não conseguir percorrer todas, **pare e avise** — relatório parcial silencioso é pior que relatório nenhum.

**Estágio 0 — recebidas.** Conte as actions retornadas pelo Step 2.2. Chame de **N0**.

**Estágio 1 — limite superior de data.** Mantenha só as actions com `date < RANGE_END` (comparação lexicográfica de string ISO-8601 resolve). Chame o total de **N1**. O `before` do Step 2.2 já deveria ter cuidado disso server-side; esta conferência existe para o caso de ele falhar silenciosamente. Se `N1 < N0`, o `before` não foi aplicado — siga com N1, mas avise o usuário.

**Estágio 2 — listas relevantes.** Mantenha só as actions cujo `data.listAfter.id` esteja na tabela abaixo, anotando o **rank** de cada uma:

| `listAfter.id` | Lista | Seção do relatório | Rank |
|---|---|---|---|
| `65525b515bd021894e00dcfb` | To Validate (Homologacao/Preprod) - Negócio | *Para Homologação* | 1 |
| `654be3c561f40a9dc0f49467` | To Validate (Producao) - Negócio | *Para Produção* | 2 |

Qualquer outro `listAfter.id` é descartado — inclusive `654be3bfa4f058f3010bdf90` (**To Review (PR)**), que **não** faz parte do relatório. Chame o total de **N2**.

**Estágio 3 — dedup por card, na lista mais avançada.** Agrupe as N2 actions por `data.card.id`. Para cada card, fique com **uma** entrada: a de **maior rank** (Produção > Homologação). Um card que ontem foi pra Homologação e depois pra Produção conta uma vez só, em Produção. Chame o total de **N3**.

**Saída obrigatória deste step:** escreva a lista completa dos N3 candidatos, uma linha por card, com `cardId`, `rank` e nome. É essa enumeração que o Step 3.3 consome.

#### 3.3 Filtrar por dono — só nos candidatos que sobraram

Agora, e só agora, descubra quais desses cards são seus. Monte um único comando com os `cardId` do Step 3.2 no lugar dos placeholders:

```bash
for id in CARD_ID_1 CARD_ID_2 CARD_ID_3; do
  curl -s "https://api.trello.com/1/cards/${id}?fields=name,desc,labels,idMembers,shortLink&key=${TRELLO_API_KEY}&token=${TRELLO_TOKEN}"
  echo
done
```

Uma linha de JSON por card. Mantenha só aqueles cujo `idMembers` contém `MY_MEMBER_ID`. Chame o total de **N4** — é a lista final do relatório.

Os campos `desc` e `labels` vêm nessa mesma resposta de propósito: o Step 4 pode precisar deles se algum prefixo for ambíguo, e assim não é preciso uma segunda chamada pro mesmo card.

Se `N4 = 0`, isso é um resultado legítimo, não um erro — significa que nenhum card seu chegou a Homologação ou Produção no período. Siga para o Step 5 e gere o relatório só com a seção "No que estou trabalhando".

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

1. `desc` e `labels` já vieram no Step 3.3 — não faça uma nova chamada pro mesmo card.
2. Leia o nome completo, descrição e labels para inferir o projeto. Use palavras-chave no texto (ex: "Itaú", "Genérico", "monorepo", "portal", "webchat") para determinar a classificação correta.
3. Se conseguir inferir com confiança, classifique no projeto correspondente sem perguntar.
4. **Somente se ainda não conseguir determinar** com clareza, pergunte ao usuário antes de gerar o relatório:
   > *"O card '[nome]' não tem prefixo reconhecido e não consegui identificar o projeto pela descrição. Qual projeto é esse? (WEBCHAT-GENERICO, WEBCHAT-ITAU, PORTAL-GENERICO, PORTAL-BRADESCO, PORTAL-ITAU, PORTAL-EMPRESA, LANDING PAGE, DESIGN-SYSTEM, MONOREPO)"*

Se houver múltiplos cards ambíguos, agrupe todos na mesma pergunta.

### 5. Verificar card em Doing atribuído ao usuário

Use o MCP tool `mcp__trello__get_cards_by_list_id` com `listId=654526d8e848f7b27e32f3e7` (Doing — Apenas 1, Informar Data). É uma consulta de **estado atual**, independente das actions dos Steps 2–3 — por isso não entra no funil e não há risco de contar o mesmo card duas vezes.

A lista pode ter cards de vários membros — **mantenha só os que têm `MY_MEMBER_ID` (Step 3.1) em `idMembers`**.

- Se encontrar 1+ card seu: use para preencher a seção "No que estou trabalhando" com nome e link.
- Se não encontrar nenhum card seu: pergunte — *"Não há card em Doing atribuído a você. O que quer colocar na seção 'No que estou trabalhando'?"* — e aguarde a resposta antes de gerar o relatório.

### 6. Gerar o relatório

**6.1 — Funil (diagnóstico, fora do texto do WhatsApp).** Antes do relatório, imprima o funil dos Steps 3.2/3.3:

```
Funil: N0 actions → N1 no range → N2 nas listas → N3 candidatos → N4 meus
```

Ele existe para que dê pra ver, no uso diário, que a filtragem aconteceu de fato — um relatório curto por filtro correto e um relatório curto por action perdida têm a mesma aparência sem ele. Deixe explícito que esse bloco **não faz parte** do texto a ser colado no WhatsApp.

**6.2 — Relatório.** Formate a saída **exatamente** assim (WhatsApp usa `*texto*` para negrito):

```
📊 *Relatório de Ontem — {ONTEM_LABEL}*

🏗️ *Para Homologação*

*[PREFIXO]* (N card(s))
• Nome do Card
  🔗 https://trello.com/c/shortLink
• Outro Card
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
- As 2 seções (`🏗️ Para Homologação`, `🚀 Para Produção`) são categorias **distintas** — cada card aparece em **uma só**, na lista mais avançada que atingiu no período (ordem Produção > Homologação). Não fundir nem duplicar.
- `📦 Total` conta os cards das seções de movimentação (**N4**); não inclui o card em Doing.
- Omita prefixos que não tiveram nenhum card no período dentro de uma seção.
- Se uma seção inteira (Homologação ou Produção) não tiver nenhum card, **omita a seção inteira** (não exibir o header).
- Se `N4 = 0`, o relatório sai só com o título, `📦 *Total: 0 cards*` e a seção "No que estou trabalhando". É saída válida — não invente conteúdo para preencher.
- Em segundas-feiras o título continua `📊 *Relatório de Ontem — {ONTEM_LABEL}*` — o `ONTEM_LABEL` já vem com o intervalo do fim de semana embutido pelo Step 1.
- Não use markdown de links `[texto](url)` — o WhatsApp não renderiza isso; escreva a URL na linha seguinte com o emoji 🔗.
- Exiba os grupos em ordem alfabética de prefixo dentro de cada seção.
