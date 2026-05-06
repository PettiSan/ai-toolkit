# ai-toolkit

Personal AI toolkit — custom slash commands and configurations for AI coding assistants.

## Setup

After cloning, copy the commands to your Claude Code global commands directory:

```bash
cp commands/* ~/.claude/commands/
```

Then add the required credentials to your `~/.zshrc`:

```bash
# Trello credentials (used by /relatorio)
export TRELLO_API_KEY="your_api_key_here"
export TRELLO_TOKEN="your_token_here"
```

Reload your shell:

```bash
source ~/.zshrc
```

## Commands

| Command | Description |
|---------|-------------|
| `/relatorio` | Generates yesterday's delivery report from Trello, formatted for WhatsApp. Shows cards moved to "To Validate (Staging)" and "To Validate (Production)", grouped by project prefix. |

## Getting Trello credentials

1. API Key: https://trello.com/app-key
2. Token: generate from the same page using your API key
