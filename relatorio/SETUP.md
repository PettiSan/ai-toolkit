# /relatorio — Setup & Recovery Guide

Complete instructions to get `/relatorio` working from scratch on a fresh Ubuntu (WSL2) machine.

---

## Prerequisites

- Ubuntu on WSL2
- Claude Code installed (`npm install -g @anthropic-ai/claude-code` or via the official installer)
- Node.js installed (recommended: via [asdf](https://asdf-vm.com/))

---

## Step 1 — Get your Trello credentials

You need two values: an API Key and a Token.

1. Go to https://trello.com/app-key
2. Copy the **API Key** shown on the page
3. On the same page, click **"Token"** link to generate a token — authorize it and copy the value

Keep both values handy for the next steps.

---

## Step 2 — Install the Trello MCP server

Install the MCP server package globally via npm:

```bash
npm install -g @delorenj/mcp-server-trello
```

Find the installed path:

```bash
node -e "console.log(require.resolve('@delorenj/mcp-server-trello'))"
```

Note this path — you'll need it in the next step. It will look something like:
`/home/<user>/.asdf/installs/nodejs/<version>/lib/node_modules/@delorenj/mcp-server-trello/dist/index.js`

---

## Step 3 — Configure the MCP server in Claude Code

Edit `~/.claude.json` and add the Trello server inside `mcpServers`:

```json
{
  "mcpServers": {
    "trello": {
      "command": "node",
      "args": ["/path/to/@delorenj/mcp-server-trello/dist/index.js"],
      "env": {
        "TRELLO_API_KEY": "your_api_key_here",
        "TRELLO_TOKEN": "your_token_here"
      }
    }
  }
}
```

Replace `/path/to/...` with the path found in Step 2, and fill in your credentials.

> ⚠️ Do not commit `~/.claude.json` anywhere — it contains your Trello token in plain text.

---

## Step 4 — Set environment variables

Add the credentials to your `~/.zshrc` (or `~/.bashrc`):

```bash
# Trello credentials (used by /relatorio in Claude Code)
export TRELLO_API_KEY="your_api_key_here"
export TRELLO_TOKEN="your_token_here"
```

Reload the shell:

```bash
source ~/.zshrc
```

The `/relatorio` command uses these variables in its `curl` calls. Without them, the API call will fail silently.

---

## Step 5 — Install the slash command

Copy the command file to Claude Code's global commands directory:

```bash
mkdir -p ~/.claude/commands
cp ~/projects/ai-toolkit/commands/relatorio.md ~/.claude/commands/
```

---

## Step 6 — Verify

Open a Claude Code session and run:

```
/relatorio
```

If everything is configured correctly, Claude will call the Trello API and return yesterday's report.

**Common issues:**

| Symptom | Likely cause |
|---------|-------------|
| "No cards found" on a day you know had cards | Check that `TRELLO_API_KEY` and `TRELLO_TOKEN` are exported in the current shell |
| Empty response from curl | Token may have expired — regenerate at https://trello.com/app-key |
| Command not found | Check that `relatorio.md` is in `~/.claude/commands/` |

---

## Updating credentials

If your Trello token expires:
1. Go to https://trello.com/app-key and generate a new token
2. Update `~/.zshrc` with the new value
3. Update `~/.claude.json` with the new value
4. Run `source ~/.zshrc`
