# ai-toolkit

Personal AI toolkit — custom slash commands and configurations for AI coding assistants.

Este repo é a fonte de verdade para toda a configuração do Claude Code. Tudo que está em `~/.claude/` é symlink para cá — editar em qualquer lugar sincroniza automaticamente.

---

## Estrutura

```
ai-toolkit/
├── setup.sh              # Script de setup para novo PC (cria todos os symlinks)
├── claude/
│   ├── CLAUDE.md         # Instruções globais do Claude Code (~/.claude/CLAUDE.md)
│   └── settings.json     # Permissões, plugins e configurações (~/.claude/settings.json)
└── commands/             # Slash commands disponíveis no Claude Code (~/.claude/commands/)
    └── trello-report.md
```

> **Credenciais MCP** (tokens de API) nunca ficam neste repo. Configurar manualmente após o setup — ver seção abaixo.

---

## Commands

| Command | Descrição | Docs |
|---------|-----------|------|
| [`/trello-report`](./trello-report/README.md) | Relatório diário de entrega do Trello, formatado para WhatsApp | [Setup](./trello-report/SETUP.md) |

---

## Restaurar em um novo PC

```bash
# 1. Clonar o repo
git clone git@github.com:SmartcobSolutions/ai-toolkit.git ~/projects/ai-toolkit

# 2. Rodar o setup (cria os symlinks em ~/.claude/)
bash ~/projects/ai-toolkit/setup.sh

# 3. Configurar credenciais MCP manualmente
claude mcp add trello \
  -e TRELLO_API_KEY=<key> \
  -e TRELLO_TOKEN=<token> \
  -- npx @delorenj/mcp-server-trello

# 4. Instalar o plugin Superpowers via Claude Code marketplace
```

---

## Adicionar nova skill

1. Criar `commands/<nome>.md` com o conteúdo da skill
2. Commitar — o symlink já faz o arquivo aparecer em `~/.claude/commands/` automaticamente
