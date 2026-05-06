# /relatorio

Slash command for Claude Code that generates the previous day's delivery report from Trello, formatted for WhatsApp.

## What it does

Queries the Trello board for all cards moved to the validation lists the day before, groups them by project prefix, and outputs a ready-to-paste WhatsApp message.

## Output format

```
📊 *Relatório de Ontem — DD/MM/YYYY*

🏗️ *Para Homologação (Staging)*

*[PORTAL-ITAU]* (2 cards)
• Card title here
  🔗 https://trello.com/c/...

🚀 *Para Produção*

_(nenhum card ontem)_

📦 *Total: 2 cards entregues ontem*

🔧 *No que estou trabalhando*

_(preencher antes de enviar)_
```

The last section — "No que estou trabalhando" — is always left blank. Fill it in manually before sending on WhatsApp.

## Project prefixes tracked

| Prefix | Project |
|--------|---------|
| `[PORTAL-GENERICO]` | smartcob-monorepo / Portal Genérico |
| `[PORTAL-BRADESCO]` | smartcob-monorepo / Portal Bradesco |
| `[PORTAL-ITAU]` | smartcob-monorepo / Portal Itaú |
| `[PORTAL-EMPRESA]` | smartcob-monorepo / Portal Empresa |
| `[DESIGN-SYSTEM]` | smartcob-monorepo / Design System |
| `[MONOREPO]` | smartcob-monorepo / Infra & pipeline |
| `[WEBCHAT-GENERICO]` | lovabledue-chat |
| `[WEBCHAT-ITAU]` | chat-mm-itau |

## Trello board & lists

| List | ID |
|------|----|
| To Validate (Homologação/Preprod) | `65525b515bd021894e00dcfb` |
| To Validate (Produção) | `654be3c561f40a9dc0f49467` |

Board ID: `65452685593555d57aa6aaf7`

## Usage

```
/relatorio
```

On Mondays, Claude will ask whether you want Sunday's report or Friday's.

## Setup

See [SETUP.md](./SETUP.md).
