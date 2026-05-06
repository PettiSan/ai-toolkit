# ai-toolkit

Personal AI toolkit — custom slash commands and configurations for AI coding assistants.

This repo stores all custom commands and integrations built on top of AI tools (Claude Code and others). The goal is to make the setup fully reproducible: clone this repo, follow the setup guide of each command, and everything works again.

---

## Commands

| Command | Description | Setup Guide |
|---------|-------------|-------------|
| [`/trello-report`](./trello-report/README.md) | Daily delivery report from Trello, formatted for WhatsApp | [Setup](./trello-report/SETUP.md) |

---

## How to restore after a reformat

1. Clone this repo to `~/projects/ai-toolkit`
2. Copy the commands to the Claude Code global directory:
   ```bash
   cp ~/projects/ai-toolkit/commands/*.md ~/.claude/commands/
   ```
3. Follow the individual setup guide for each command (linked in the table above)
