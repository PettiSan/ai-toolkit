# /trello-report

Slash command for Claude Code that generates the previous day's delivery report from Trello, formatted for WhatsApp.

## What it does

Queries the Trello board for all cards moved to the target lists the day before, groups them by project prefix, checks for any card currently in Doing, and outputs a ready-to-paste WhatsApp message.

## Output format

```
📊 *Relatório de Ontem — DD/MM/YYYY*

🏗️ *Para Homologação (Staging)*

*[PORTAL-ITAU]* (2 cards)
• Card title here
  🔗 https://trello.com/c/...

🚀 *Para Produção*

_(nenhum card ontem)_

✅ *Done*

*[MONOREPO]* (1 card)
• Card title here
  🔗 https://trello.com/c/...

📦 *Total: 3 cards entregues ontem*

🔧 *No que estou trabalhando*

• Card currently in Doing
  🔗 https://trello.com/c/...
```

The last section — "No que estou trabalhando" — is auto-filled from the current Doing card. If no card is found in Doing, Claude will ask what to write before generating the report.

## Project prefixes tracked

| Prefix | Project |
|--------|---------|
| `[PORTAL-GENERICO]` | smartcob-monorepo / Portal Genérico |
| `[PORTAL-BRADESCO]` | smartcob-monorepo / Portal Bradesco |
| `[PORTAL-ITAU]` | smartcob-monorepo / Portal Itáu |
| `[PORTAL-EMPRESA]` | smartcob-monorepo / Portal Empresa |
| `[DESIGN-SYSTEM]` | smartcob-monorepo / Design System |
| `[MONOREPO]` | smartcob-monorepo / Infra & pipeline |
| `[WEBCHAT-GENERICO]` | lovabledue-chat |
| `[WEBCHAT-ITAU]` | chat-mm-itau |

## Trello board & lists

| List | ID | Report section |
|------|----|-----------------|
| To Validate (Homologação/Preprod) | `65525b515bd021894e00dcfb` | 🏗️ Homologação |
| To Validate (Produção) | `654be3c561f40a9dc0f49467` | 🚀 Produção |
| Done | `6567333327f2a10ed8369473` | ✅ Done |
| Doing (Apenas 1, Informar Data) | `654526d8e848f7b27e32f3e7` | (current work) |
| Doing (PAUSED/BLOCKED) | `6787e6feba62de1d7fd9ef3c` | (current work fallback) |

> Cards moved directly to **Done** (skipping validation environments) also count as delivered. This applies to cards that don't involve other environments or external reviewers — e.g. configuration tasks, documentation, or guidelines.

Board ID: `65452685593555d57aa6aaf7`

## Usage

```
/trello-report
```

On Mondays, Claude will ask whether you want Sunday's report or Friday's.

## Setup

See [SETUP.md](./SETUP.md).
