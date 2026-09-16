# ai-toolkit

Configuration-as-code for AI coding agents, across Linux, WSL and Windows.

This repository is the single source of truth for my Claude Code setup: global agent instructions,
lifecycle hooks, subagents, shell dotfiles, and the MCP server wiring for both the CLI and the desktop
app. Everything under `~/.claude/` is a symlink back here, so editing in either place stays in sync and
two machines cannot quietly drift apart.

---

## Why this exists

I run Claude Code on one machine across two operating systems: the desktop app on Windows, and the CLI
inside Ubuntu on WSL. Most of my delivery goes through AI agents. That setup has two failure modes, and
both of them are silent.

**The first is drift.** Configuration that lives in a home directory is invisible to version control.
You change something on one machine, forget the other, and then spend a week wondering why the same
prompt produces different behavior in two places. The fix is boring and it works: put the configuration
in a repository and point the home directory at it.

**The second is credentials.** MCP servers need API tokens, and the obvious place to put them is a
config file. That config file then gets synced, backed up, or screenshotted. So no token lives in this
repository at any point. On Windows they go into the Windows Credential Manager through DPAPI, read from
hidden input and never written to disk in plaintext. Rotation is one command.

There is one deliberate exception, and it is documented rather than hidden: on WSL the tokens live in a
`600`-mode file outside any repository. That is a plaintext file, and I know it. The trade was that the
Claude Code desktop harness repeatedly lost access to vault-backed credentials, and an MCP server that
fails to start on a Monday morning costs more than the residual risk of a local file readable only by
me. The reasoning is written down in the repo so the next person to touch it can disagree with the
decision rather than discover it.

---

## What is here

```
ai-toolkit/
├── setup.sh                  # Linux/macOS/WSL: symlinks ~/.claude/ and the shell dotfiles
├── claude-mcp-setup/         # Windows desktop: MCP wiring with Credential Manager (DPAPI)
│   ├── setup.ps1
│   ├── INSTALL.md
│   └── launchers/            # one PowerShell launcher per MCP server
├── claude/
│   ├── CLAUDE.md             # global agent instructions
│   ├── settings.json         # CLI settings (WSL), symlinked
│   ├── settings.windows.json # versioned snapshot of the desktop app's settings
│   └── hooks/                # Claude Code lifecycle hooks
├── dotfiles/                 # zsh and ssh config, symlinked
├── agents/                   # subagent definitions
└── commands/                 # slash commands
```

### Two runtimes, two settings files

`claude/settings.json` belongs to the CLI running inside WSL and is symlinked. `settings.windows.json`
is a manual snapshot of the desktop app's own settings file, which cannot be symlinked, so the snapshot
is the only versioned copy. The distinction is written down because I lost edits to it twice before
writing it down.

### The branch guard

`claude/hooks/git-branch-guard.js` refuses commits to integration and production branches. It is a
guard, not a warning: a warning you can click through is not a guardrail.

---

## Setting up a new machine

### Linux, macOS, WSL

```bash
git clone git@github.com:PettiSan/ai-toolkit.git ~/projects/ai-toolkit
bash ~/projects/ai-toolkit/setup.sh
cp ~/projects/ai-toolkit/dotfiles/zshenv.local.example ~/.zshenv.local
chmod 600 ~/.zshenv.local   # then fill in your own tokens
```

`setup.sh` replaces `~/.zshenv`, `~/.zshrc` and `~/.ssh/config` with symlinks into `dotfiles/`, keeping
whatever was there as a `.bak` alongside. On a machine that already has a configured shell, check the
backup before discarding it.

Step 3 is not optional. Without `~/.zshenv.local` the shell starts normally and the Trello MCP server
fails on its first call, with no message pointing at the cause.

### Windows (Claude Code desktop app)

```powershell
git clone git@github.com:PettiSan/ai-toolkit.git $HOME\projects\ai-toolkit
cd $HOME\projects\ai-toolkit\claude-mcp-setup
.\setup.ps1
```

The script installs the `CredentialManager` module, fetches the MCP packages, reads the secrets from
hidden input, stores them in the Windows Credential Manager, copies per-server launchers into
`%USERPROFILE%\.claude\mcp-launchers\`, and rewrites `claude_desktop_config.json` to point at them. The
tokens never appear in a text file.

---

## Notes for anyone borrowing this

- **Skills and slash commands that encode team process are not here.** They moved to a private
  governance plugin owned by my employer, because that is where rules belonging to a team should live.
  What stays in this repository is personal configuration only. The installers already tolerate their
  absence: `setup.sh` symlinks each skill directory individually and never deletes what it does not
  recognize.
- **The operational configuration is in Portuguese, on purpose.** `claude/CLAUDE.md`, `agents/` and the
  shell dotfiles are working files I read every day in my own language, and translating them would cost
  precision to gain nothing. The documentation you are reading is the part meant to be shared.
- `commands/` keeps a `.gitkeep` deliberately. `setup.sh` symlinks that directory as a whole, so without
  the file git drops the directory and leaves a dangling symlink in the profile.
- The Windows path does not create symlinks. If you run the desktop app on Windows against repositories
  in WSL, either sync the relevant files by hand or run Claude Code from inside WSL.

---

## License

MIT. See [LICENSE](./LICENSE).
