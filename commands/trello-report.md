Gera o relatório de entrega do dia anterior com base nas movimentações do Trello.

## Passos

### 1. Calcular datas

Use Bash para calcular as datas em UTC, considerando que o usuário está em America/Sao_Paulo (UTC-3). "Ontem" = dia anterior completo no fuso de Brasília.

```bash
ONTEM_INICIO=$(TZ=America/Sao_Paulo date -d "yesterday 00:00:00" --utc +%Y-%m-%dT%H:%M:%S.000Z)
ONTEM_FIM=$(TZ=America/Sao_Paulo date -d "today 00:00:00" --utc +%Y-%m-%dT%H:%M:%S.000Z)
ONTEM_LABEL=$(TZ=America/Sao_Paulo date -d "yesterday" +%d/%m/%Y)
echo "$ONTEM_INICIO $ONTEM_FIM $ONTEM_LABEL"
```

### 2. Buscar actions do board

Chame a Trello REST API para obter movimentações de cards no board principal:

```bash
curl -s "https://api.trello.com/1/boards/65452685593555d57aa6aaf7/actions?filter=updateCard:idList&since=${ONTEM_INICIO}&before=${ONTEM_FIM}&limit=1000&key=${TRELLO_API_KEY}&token=${TRELLO_TOKEN}"
```

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

Cards sem prefixo reconhecido: listar em grupo `[OUTROS]`.

### 5. Verificar card em Doing

Faça duas chamadas para buscar cards nas listas de Doing:

```bash
# Doing (Apenas 1, Informar Data)
curl -s "https://api.trello.com/1/lists/654526d8e848f7b27e32f3e7/cards?fields=name,shortLink&key=${TRELLO_API_KEY}&token=${TRELLO_TOKEN}"

# Doing (PAUSED/BLOCKED)
curl -s "https://api.trello.com/1/lists/6787e6feba62de1d7fd9ef3c/cards?fields=name,shortLink&key=${TRELLO_API_KEY}&token=${TRELLO_TOKEN}"
```

- Se encontrar card(s) em qualquer uma das duas listas: use o primeiro card encontrado para preencher a seção "No que estou trabalhando" com o nome e o link do card
- Se não encontrar nenhum card: pergunte ao usuário — *"Não há card em Doing no momento. O que você quer colocar na seção 'No que estou trabalhando'?"* — e aguarde a resposta antes de gerar o relatório

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
