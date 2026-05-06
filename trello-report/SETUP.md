# trello-report — Installation Guide

Step-by-step instructions to install the `trello-report` skill in Claude Code on any platform.

---

## Prerequisites

Before starting, make sure you have:

- **Claude Code** installed — [claude.ai/code](https://claude.ai/code)
- **Node.js** v18 or higher — recommended via [asdf](https://asdf-vm.com/), [nvm](https://github.com/nvm-sh/nvm), or the official installer
- A **Trello account** with access to the board you want to report on

---

## Step 1 — Get your Trello credentials

You need two values: an **API Key** and a **Token**.

1. Go to [https://trello.com/app-key](https://trello.com/app-key)
2. Copy the **API Key** shown on the page
3. Click the **"Token"** link on the same page, authorize it, and copy the token value

Keep both values handy — you'll use them in Steps 3 and 4.

> Example (all platforms): the values look like `abc123def456...` — long alphanumeric strings.

---

## Step 2 — Install the Trello MCP server

Install the MCP server package globally via npm:

```
npm install -g @delorenj/mcp-server-trello
```

Then find the path to the installed binary — you'll need it in the next step:

```
node -e "console.log(require.resolve('@delorenj/mcp-server-trello'))"
```

> **Example (Linux/WSL2):**
> ```bash
> npm install -g @delorenj/mcp-server-trello
> node -e "console.log(require.resolve('@delorenj/mcp-server-trello'))"
> # Output: /home/pettisan/.asdf/installs/nodejs/22.14.0/lib/node_modules/@delorenj/mcp-server-trello/dist/index.js
> ```

---

## Step 3 — Configure the MCP server in Claude Code

Claude Code reads MCP server configuration from a JSON file. Edit that file and add the Trello server inside `mcpServers`:

| Platform | Config file location |
|----------|---------------------|
| Linux / macOS | `~/.claude.json` |
| Windows | `%USERPROFILE%\.claude.json` |

Add the following block (replace the path and credentials with your own values from Steps 1 and 2):

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

> **Example (Linux/WSL2):** Edit `~/.claude.json` with:
> ```json
> {
>   "mcpServers": {
>     "trello": {
>       "command": "node",
>       "args": ["/home/pettisan/.asdf/installs/nodejs/22.14.0/lib/node_modules/@delorenj/mcp-server-trello/dist/index.js"],
>       "env": {
>         "TRELLO_API_KEY": "abc123...",
>         "TRELLO_TOKEN": "xyz789..."
>       }
>     }
>   }
> }
> ```

> ⚠️ Do not commit this file anywhere — it contains your Trello token in plain text.

---

## Step 4 — Set environment variables

The skill uses `TRELLO_API_KEY` and `TRELLO_TOKEN` in its API calls. Set them as persistent environment variables for your shell:

| Platform | Where to set |
|----------|-------------|
| Linux | `~/.zshrc` or `~/.bashrc` |
| macOS | `~/.zshrc` (Catalina+) or `~/.bash_profile` |
| Windows | System Properties → Environment Variables, or `$PROFILE` in PowerShell |

After editing, reload your shell (Linux/macOS) or open a new terminal (Windows).

> **Example (Linux/WSL2):** Add to `~/.zshrc`:
> ```bash
> export TRELLO_API_KEY="abc123..."
> export TRELLO_TOKEN="xyz789..."
> ```
> Then reload:
> ```bash
> source ~/.zshrc
> ```

---

## Step 5 — Install the skill file

Copy `trello-report.md` from this repo into Claude Code's global commands directory:

| Platform | Commands directory |
|----------|--------------------|
| Linux / macOS | `~/.claude/commands/` |
| Windows | `%USERPROFILE%\.claude\commands\` |

Create the directory if it doesn't exist, then copy the file.

> **Example (Linux/WSL2):**
> ```bash
> mkdir -p ~/.claude/commands
> cp ~/projects/ai-toolkit/commands/trello-report.md ~/.claude/commands/
> ```

---

## Step 6 — Verify

Open a new Claude Code session and run:

```
/trello-report
```

If everything is configured correctly, Claude will query the Trello board and generate yesterday's report.

**Troubleshooting:**

| Symptom | Likely cause |
|---------|--------------|
| "No cards found" on a day you know had activity | `TRELLO_API_KEY` or `TRELLO_TOKEN` not exported in the current shell |
| Empty or error response from Trello API | Token may have expired — regenerate at [https://trello.com/app-key](https://trello.com/app-key) |
| `/trello-report` command not found | `trello-report.md` is not in the commands directory — repeat Step 5 |
| MCP server not responding | Check the path in `~/.claude.json` matches the output from Step 2 |

---

## Updating credentials

If your Trello token expires:

1. Go to [https://trello.com/app-key](https://trello.com/app-key) and generate a new token
2. Update the token in your shell config file (Step 4)
3. Update the token in your Claude Code config file (Step 3)
4. Reload your shell or open a new terminal
