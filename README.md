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
│   └── settings.json              # Permissões, plugins e configurações (~/.claude/settings.json)
├── commands/                      # Slash commands disponíveis no Claude Code (~/.claude/commands/)
│   └── trello-report-legacy.md    # versão legacy — só pra webchats
└── trello-report/                 # Docs do command legacy (README + SETUP)
```

> **Credenciais MCP** (tokens de API) nunca ficam neste repo. No Linux/WSL ficam em env vars; no Windows ficam no Windows Credential Manager (DPAPI) via o setup em `claude-mcp-setup/`.

---

## Commands

| Command | Descrição | Docs |
|---------|-----------|------|
| [`/trello-report-legacy`](./trello-report/README.md) | Relatório diário de entrega do Trello, formatado para WhatsApp. ⚠️ Versão legacy — só pra webchats. Canônica `/trello-report` vive no `smartcob-monorepo` (ver seção [Relação com o smartcob-monorepo](#relação-com-o-smartcob-monorepo) no final). | [Setup](./trello-report/SETUP.md) |

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

Em maio/2026, o time decidiu versionar skills compartilhadas dentro do próprio repo do projeto. O `smartcob-monorepo` agora tem:

- `.claude/commands/brainstorming.md` — skill nova, criada do zero pro fluxo de Card Complexo (não existe neste toolkit)
- `.claude/commands/trello-report.md` — versão atualizada do `/trello-report` deste toolkit, com:
  - Inclusão da lista `Done` como destino válido (cards de doc que pulam validação)
  - Agregação automática de **sexta + sábado + domingo** no relatório de segunda-feira (sem perguntar)
  - Leitura de `TRELLO_MEMBER_ID` via env var (permite o skill funcionar pra qualquer dev, não só pra um membro hardcoded)
  - Nova seção `✅ Finalizados` separada de `🚀 Para Produção` na saída do WhatsApp
- `.mcp.json` na raiz — configuração compartilhada dos MCP servers (Trello via `@delorenj/mcp-server-trello`, Figma)

**Daqui pra frente, a versão canônica do `/trello-report` é a do monorepo.** Esta cópia (`/trello-report-legacy`) continua aqui por dois motivos:

1. **Cobrir os webchats** (`lovabledue-chat`, `chat-mm-itau`) até a migração deles pro monorepo
2. **Histórico pessoal** — registro do que foi feito antes do trabalho descer pro projeto compartilhado

Esta cópia não recebe mais atualizações regulares. Quando precisar do `/trello-report` no contexto do `smartcob-monorepo`, use o do monorepo.
