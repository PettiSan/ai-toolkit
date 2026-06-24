# ai-toolkit

Personal AI toolkit — custom slash commands and configurations for AI coding assistants.

Este repo é a fonte de verdade para toda a configuração do Claude Code. Tudo que está em `~/.claude/` é symlink para cá — editar em qualquer lugar sincroniza automaticamente.

---

## Estrutura

```
ai-toolkit/
├── setup.sh                       # Setup para Linux/macOS/WSL (cria symlinks em ~/.claude/)
├── claude-mcp-setup/              # Setup do Claude Desktop no Windows (CredMan + MCPs)
│   ├── INSTALL.md
│   ├── launchers/                 # Launchers .ps1 por MCP server
│   └── setup.ps1
├── claude/
│   ├── CLAUDE.md                  # Instruções globais do Claude Code (~/.claude/CLAUDE.md)
│   ├── settings.json              # Settings do CLI no WSL (symlink p/ ~/.claude/settings.json)
│   ├── settings.windows.json      # Snapshot do settings.json do Claude Desktop (Windows) — backup
│   └── hooks/                     # Hooks do Claude Code (deploy p/ ~/.claude/hooks/)
└── commands/                      # Slash commands disponíveis no Claude Code (~/.claude/commands/)
```

> **Dois settings, dois runtimes.** `claude/settings.json` é o do **CLI no WSL** (symlinkado).
> `claude/settings.windows.json` é um **snapshot manual** do `~/.claude/settings.json` do **Claude
> Desktop no Windows** — esse arquivo do Desktop não é symlink, então o snapshot é a única cópia
> versionada. Re-sincronize à mão quando mudar o settings do Desktop. Restaure num PC novo com
> `claude-mcp-setup/setup.ps1 -RestoreSettings` (faz backup do existente antes).

> **Credenciais MCP** (tokens de API) nunca ficam neste repo. No Linux/WSL ficam em env vars; no Windows ficam no Windows Credential Manager (DPAPI) via o setup em `claude-mcp-setup/`.

---

## Restaurar em um novo PC

### Linux / macOS / WSL

```bash
# 1. Clonar
git clone git@github.com:PettiSan/ai-toolkit.git ~/projects/ai-toolkit

# 2. Rodar o setup (cria os symlinks em ~/.claude/)
bash ~/projects/ai-toolkit/setup.sh

# 3. Configurar credenciais MCP manualmente
claude mcp add trello \
  -e TRELLO_API_KEY=<key> \
  -e TRELLO_TOKEN=<token> \
  -- npx @delorenj/mcp-server-trello

# 4. Instalar o plugin Superpowers via Claude Code marketplace
```

### Windows (Claude Desktop)

O setup do Windows é separado porque o Claude Desktop usa um config diferente (`%APPDATA%\Claude\claude_desktop_config.json`) e porque queremos os segredos no **Windows Credential Manager** em vez de texto plano.

```powershell
# 1. Clonar
git clone git@github.com:PettiSan/ai-toolkit.git $HOME\projects\ai-toolkit

# 2. Rodar o setup do Windows (ver detalhes em claude-mcp-setup/INSTALL.md)
cd $HOME\projects\ai-toolkit\claude-mcp-setup
.\setup.ps1
```

O `setup.ps1` instala o módulo `CredentialManager`, baixa os pacotes MCP via npm, lê 5 segredos do usuário (input oculto) e armazena no CredMan via DPAPI, copia launchers `.ps1` para `%USERPROFILE%\.claude\mcp-launchers\` e atualiza `claude_desktop_config.json` apontando pra eles.

Resultado: tokens nunca aparecem em arquivos texto, rotação é 1 comando, sem precisar editar config.

> **Symlinks do `~/.claude/` no Windows não são feitos por nenhum script** — o `setup.sh` só roda em bash (WSL/Linux/macOS). Se você usa Claude Desktop no Windows, sincronize manualmente os arquivos relevantes (CLAUDE.md, settings.json, commands) ou rode o Claude Code Desktop a partir do WSL.

---

## Adicionar nova skill

1. Criar `commands/<nome>.md` com o conteúdo da skill
2. Commitar — o symlink já faz o arquivo aparecer em `~/.claude/commands/` automaticamente

---

## Relação com o smartcob-monorepo

A versão canônica do `/trello-report` vive em `smartcob-monorepo/.claude/commands/trello-report.md`. O toolkit não mantém mais uma cópia local desse comando.
