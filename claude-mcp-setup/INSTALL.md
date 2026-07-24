# Claude MCP setup — Windows

Setup for Claude Desktop on Windows: 3 MCP servers (GitHub × 2, Trello) backed by
**Windows Credential Manager** (DPAPI). Tokens never live in text files.

## Prerequisites

- Windows 10/11
- Node.js (LTS) — install from https://nodejs.org
- Claude Desktop installed

## Quick install

Open PowerShell as your normal user (no admin), `cd` into this folder, and run:

```powershell
.\setup.ps1
```

The script will:
1. Install `CredentialManager` PowerShell module
2. Install MCP packages globally via npm
3. Prompt you for 5 tokens (input hidden) and store them in Windows Credential Manager
4. Copy launchers to `$env:USERPROFILE\.claude\mcp-launchers\`
5. Deploy `commands/*.md` and `agents/*.md` to `$env:USERPROFILE\.claude\` — this is what makes
   slash commands like `/trello-report` and agents like `advisor` show up in Claude Desktop.
   Copies file-by-file and never deletes, so local-only agents in `~/.claude/agents/` survive.
6. Merge MCP entries into `claude_desktop_config.json` (preserving any existing config)
7. Apply `permissions.deny` rules to `~/.claude/settings.json` (defense in depth)

> **Windows vs Linux.** `setup.sh` (Linux/WSL) *symlinks* `commands/` and `agents/advisor.md` into
> `~/.claude/`, so the repo is always the live source there. On Windows this script *copies* —
> symlinks would need Developer Mode or admin. Consequence: after pulling changes to `commands/` or
> `agents/`, re-run `setup.ps1` on Windows, or the Desktop keeps the old copy. Claude Desktop only
> rescans commands and agents **at boot** — quit completely (tray → Quit) and reopen, not just a new
> conversation.

Then **quit Claude Desktop completely** (tray icon → Quit) and reopen.

Flags:
- `-SkipPackages` — skip the `npm install -g` step (use if you already have them)
- `-SkipDenyRules` — skip the `settings.json` deny rules update

## Tokens to have ready before running

| What | Where to generate | CredMan target name |
|---|---|---|
| GitHub fine-grained PAT (personal account) | https://github.com/settings/personal-access-tokens/new — Resource owner: your username | `claude-github-pat-personal` |
| GitHub fine-grained PAT (Smartcob org)\* | Same URL, Resource owner: SmartcobSolutions (org owner must approve if you're not owner) | `claude-github-pat-smartcob` |
| Trello API key | https://trello.com/power-ups/admin → create Power-Up → API Key tab | `claude-trello-api-key` |
| Trello token | Same Power-Up page, click "Token" link next to API key | `claude-trello-token` |
| Figma PAT (optional) | https://www.figma.com/settings → Personal access tokens | `claude-figma-api-key` |

\* Adapt to your context. If you don't have a Smartcob context, either skip the prompt during setup (press Enter on empty value) or edit `setup.ps1` + `launchers/github-smartcob.ps1` to use a different org / remove the entry.

Notes on minimum scopes for the GitHub PATs (fine-grained):
- Contents: Read and write
- Pull requests: Read and write
- Issues: Read and write
- Metadata: Read (auto)
- Workflows: Read and write (optional)

## Manual install (if you don't want to use setup.ps1)

1. PowerShell module:
   ```powershell
   [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
   Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Scope CurrentUser
   Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
   Install-Module -Name CredentialManager -Scope CurrentUser -Force
   ```

2. npm packages:
   ```powershell
   npm install -g @modelcontextprotocol/server-github
   npm install -g @delorenj/mcp-server-trello
   ```

3. Store tokens (repeat for each target name in the table above):
   ```powershell
   Import-Module CredentialManager
   $secure = Read-Host "Paste value" -AsSecureString
   New-StoredCredential -Target "claude-github-pat-personal" `
       -UserName "claude" -SecurePassword $secure -Persist LocalMachine
   ```

4. Copy launchers:
   ```powershell
   $dest = "$env:USERPROFILE\.claude\mcp-launchers"
   New-Item -ItemType Directory -Path $dest -Force | Out-Null
   Copy-Item .\launchers\*.ps1 -Destination $dest -Force
   ```

5. Edit `$env:APPDATA\Claude\claude_desktop_config.json` and add under `mcpServers`:
   ```json
   {
     "mcpServers": {
       "github-personal": {
         "command": "powershell.exe",
         "args": ["-NoProfile", "-ExecutionPolicy", "Bypass", "-File",
                  "C:\\Users\\YOURUSER\\.claude\\mcp-launchers\\github-personal.ps1"]
       },
       "github-smartcob": { "command": "powershell.exe", "args": ["-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "C:\\Users\\YOURUSER\\.claude\\mcp-launchers\\github-smartcob.ps1"] },
       "trello":          { "command": "powershell.exe", "args": ["-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "C:\\Users\\YOURUSER\\.claude\\mcp-launchers\\trello.ps1"] }
     }
   }
   ```
   Replace `YOURUSER` with your Windows username.

6. Restart Claude Desktop (tray → Quit → reopen).

## Rotating a token

```powershell
Import-Module CredentialManager
$secure = Read-Host "New token value" -AsSecureString
New-StoredCredential -Target "claude-github-pat-personal" `
    -UserName "claude" -SecurePassword $secure -Persist LocalMachine
```

(Overwrites the existing entry.) Restart Claude Desktop to pick up the new token.

## How this works

The launchers use specific patterns to avoid Windows GUI-spawn pitfalls:

- **`[System.Diagnostics.Process]::Start` with `CreateNoWindow=$true`** — prevents Windows from allocating a new console for the child process when the parent (PowerShell) was spawned by a GUI app (Claude Desktop) without one. Console allocation breaks stdio inheritance with the MCP protocol.

- **`node.exe` directly on the entry JS** — bypasses `npx` and `cmd.exe`. The `npx -y` flow internally invokes cmd.exe to resolve binaries, which re-introduces the console-allocation problem and fails to find the bin in headless PATH context.

- **`-Persist LocalMachine` on `New-StoredCredential`** — DPAPI-encrypted credential bound to user + machine. Unlocks at logon (no master password). Machine-specific by design — does not roam.

- **Logs in `<name>.log` and `<name>-node-stderr.log`** for diagnosis. Contain no secrets (only timestamps, lengths, exit codes, stderr from node).

## Trello 401 + the MCP process leak

Two **separate** issues were found here — don't conflate them.

### Issue 1 — Trello returns 401 (revoked/expired token in CredMan)

**Symptom:** Trello MCP calls return `401`. May surface after a relaunch or suspend/resume, or as
"it worked yesterday and now it doesn't".

**Root cause:** on Desktop the Trello MCP reads its token from **Windows Credential Manager**
(`trello.ps1` → `Get-StoredCredential claude-trello-api-key` / `claude-trello-token`), **not** from
the repo `.mcp.json` or environment variables. So a `401` almost always means the token stored in
CredMan is **revoked or expired** — not a transport/env problem. (Real case: a token cleanup
revoked the leaked tokens, including the valid one in CredMan; a direct `curl` against the Trello
API went from `200` to `401`.) Restarting Desktop or killing/respawning the node process does
**not** help — they re-read the same revoked token.

**Recovery:** re-store a *valid* token in CredMan, then restart Desktop:
```powershell
Import-Module CredentialManager
$secure = Read-Host "Paste valid Trello token" -AsSecureString
New-StoredCredential -Target "claude-trello-token" `
    -UserName "claude" -SecurePassword $secure -Persist LocalMachine
```
Then **quit Claude Desktop completely** (tray → Quit) and reopen — `trello.ps1` re-reads CredMan on
launch. Verify the token first with a direct call (`200` = good, `401` = still revoked):
```powershell
curl "https://api.trello.com/1/members/me?key=<API_KEY>&token=<TOKEN>"
```

> **WSL CLI is a separate path.** The `claude` CLI under WSL reads `TRELLO_API_KEY` /
> `TRELLO_TOKEN` from `~/.zshenv` (plaintext, by choice to avoid GPG), resolved by the repo
> `.mcp.json`. If you rotate the Trello token, update **both** CredMan (Desktop) and `~/.zshenv`
> (WSL CLI).

### Issue 2 — MCP node processes leak and accumulate

Each suspend/close leaks the MCP `node` child as an orphan instead of killing it; they pile up
(observed: 90 live Trello node processes at once). Amplified by the Windows + Desktop stack (npx →
`cmd.exe` shim tree that doesn't cascade on kill). Rare on native Mac/Linux. The real fix is
upstream (host reaping MCP children on session end / resume).

- `launchers/cleanup-mcp-orphans.ps1` + scheduled task **"Claude MCP orphan cleanup"** (registered
  by `setup.ps1`, every 4h) — kills orphaned MCP node processes (dead parent). Always safe, never
  touches a live session.
  ```powershell
  schtasks /Query /TN "Claude MCP orphan cleanup" /FO LIST   # inspect
  schtasks /Run   /TN "Claude MCP orphan cleanup"            # run now
  ```
  > `Register-ScheduledTask` returns "Access denied" in some contexts (writes to the task library
  > root). Use `schtasks.exe`, which registers in the current-user context.

> Note: the cleanup only catches dead-parent orphans. Ones abandoned on suspend whose parent (the
> session) is still open only become orphans when the session closes; the next run reaps them.

## Known limitations

- **Claude Code CLI** has its own auth config separate from Desktop — `~/.claude/settings.json` and `.mcp.json`. This setup is **Desktop-only**.
- **WSL** can't access Windows CredMan (DPAPI is Win32-only). For `gh` inside WSL, run `gh auth login` — it stores in `~/.config/gh/hosts.yml` mode 0600.
- **Deny rules with absolute Windows paths in `settings.json` don't block** — known Anthropic bug [#34741](https://github.com/anthropics/claude-code/issues/34741). The setup uses glob patterns (`Read(**/foo)`) which work.
- **Deny rules cover only built-in tools, not Bash/PowerShell**. `Read(.env)` denied doesn't block `cat .env`.
- **`@modelcontextprotocol/server-github` is deprecated** (npm shows "Package no longer supported"). Replacement is `ghcr.io/github/github-mcp-server` (Docker container). Migration TBD.
