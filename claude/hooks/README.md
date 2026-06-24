# Claude Code hooks

Fonte da verdade dos hooks do Claude Code. O runtime lê de `~/.claude/`, então a
cópia viva tem que ser deployada lá manualmente (no Windows Desktop o `~/.claude`
**não** é symlink — é cópia manual).

## git-branch-guard.js

Hook `PreToolUse` (matcher `Bash`) que faz microgerenciamento do guardrail de
commit/push por **branch**.

### Regra

Tudo é **liberado**, menos estas 5 branches protegidas (match exato, case-insensitive),
que disparam **`ask`** (pedem tua aprovação):

```
main · master · develop · homolog · trunk
```

`git commit` não nomeia a branch no texto do comando (commita na que está com
checkout), então **regra estática de whitelist não consegue** distinguir por branch.
O hook resolve a branch atual em tempo de chamada (`rev-parse --abbrev-ref HEAD`) e
decide. Para `push`, um ref protegido explícito no comando (`push origin develop`)
já basta para gatear.

- Branch de trabalho (feature, fix, `hotfix/*`, `claude/*`, etc.) → `allow` (sem prompt).
- `main`/`master`/`develop`/`homolog`/`trunk` → `ask`.
- Branch indeterminada (rev-parse falhou, detached HEAD) → `ask` (fail-safe).

### Limitação conhecida

Dentro de **worktree criado pelo Desktop**, o `.git` aponta para um path UNC
(`//wsl.localhost/...`) que o `wsl git` não resolve — `rev-parse` falha e o hook cai
no fail-safe `ask`. Commits nesses worktrees vão por MCP `push_files` de qualquer
forma. No clone principal o hook funciona normalmente.

## Deploy (Windows Desktop)

```powershell
Copy-Item "$HOME\projects\ai-toolkit\claude\hooks\git-branch-guard.js" `
  -Destination "$env:USERPROFILE\.claude\hooks\git-branch-guard.js" -Force
```

E garantir no `~/.claude/settings.json` (Desktop) o fragmento abaixo. **Esse
settings.json do Desktop não é versionado** — é cópia manual local; mantenha este
fragmento sincronizado à mão.

```jsonc
{
  "permissions": {
    "allow": [
      // ... (git add — staging é inofensivo, liberado incondicionalmente)
      "Bash(wsl git -C * add *)",
      "Bash(MSYS_NO_PATHCONV=1 wsl git -C * add *)",
      "Bash(git -C * add *)"
      // commit/push NÃO entram na whitelist — quem decide é o hook abaixo.
    ]
  },
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "node \"C:/Users/filip/.claude/hooks/git-branch-guard.js\"",
            "if": "Bash(*git *)",
            "timeout": 15,
            "statusMessage": "Checando branch (git-branch-guard)…"
          }
        ]
      }
    ]
  }
}
```

Depois reabra o Claude Desktop (ou abra `/hooks` uma vez) para o watcher recarregar.
