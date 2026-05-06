#!/bin/bash
set -e

REPO="$(cd "$(dirname "$0")" && pwd)"
CLAUDE="$HOME/.claude"

echo "==> Configurando Claude Code a partir do ai-toolkit..."
mkdir -p "$CLAUDE/commands"

# commands/ — symlink do diretório inteiro
if [ -L "$CLAUDE/commands" ]; then
    echo "  [ok] commands/ já é symlink"
elif [ -d "$CLAUDE/commands" ]; then
    echo "  [bak] Backup de commands/ existente → commands.bak/"
    mv "$CLAUDE/commands" "$CLAUDE/commands.bak"
    ln -sf "$REPO/commands" "$CLAUDE/commands"
    echo "  [ok] commands/ → ai-toolkit/commands/"
else
    ln -sf "$REPO/commands" "$CLAUDE/commands"
    echo "  [ok] commands/ → ai-toolkit/commands/"
fi

# CLAUDE.md
if [ -L "$CLAUDE/CLAUDE.md" ]; then
    echo "  [ok] CLAUDE.md já é symlink"
elif [ -f "$CLAUDE/CLAUDE.md" ]; then
    echo "  [bak] Backup de CLAUDE.md existente → CLAUDE.md.bak"
    cp "$CLAUDE/CLAUDE.md" "$CLAUDE/CLAUDE.md.bak"
    ln -sf "$REPO/claude/CLAUDE.md" "$CLAUDE/CLAUDE.md"
    echo "  [ok] CLAUDE.md → ai-toolkit/claude/CLAUDE.md"
else
    ln -sf "$REPO/claude/CLAUDE.md" "$CLAUDE/CLAUDE.md"
    echo "  [ok] CLAUDE.md → ai-toolkit/claude/CLAUDE.md"
fi

# settings.json
if [ -L "$CLAUDE/settings.json" ]; then
    echo "  [ok] settings.json já é symlink"
elif [ -f "$CLAUDE/settings.json" ]; then
    echo "  [bak] Backup de settings.json existente → settings.json.bak"
    cp "$CLAUDE/settings.json" "$CLAUDE/settings.json.bak"
    ln -sf "$REPO/claude/settings.json" "$CLAUDE/settings.json"
    echo "  [ok] settings.json → ai-toolkit/claude/settings.json"
else
    ln -sf "$REPO/claude/settings.json" "$CLAUDE/settings.json"
    echo "  [ok] settings.json → ai-toolkit/claude/settings.json"
fi

echo ""
echo "==> Pronto! Claude Code está linkado ao ai-toolkit."
echo ""
echo "Próximos passos manuais:"
echo "  1. MCP Trello: claude mcp add trello -e TRELLO_API_KEY=<key> -e TRELLO_TOKEN=<token> -- npx @delorenj/mcp-server-trello"
echo "  2. Plugin Superpowers: instalar via Claude Code marketplace"
echo "  3. Credenciais GitHub MCP (se aplicável): configurar separadamente"
