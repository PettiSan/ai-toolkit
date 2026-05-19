#!/bin/bash
set -e

REPO="$(cd "$(dirname "$0")" && pwd)"
CLAUDE="$HOME/.claude"

echo "==> Configurando Claude Code a partir do ai-toolkit..."

mkdir -p "$CLAUDE"

ensure_symlink() {
    local target="$1"
    local link="$2"
    local label="$3"

    if [ -L "$link" ]; then
        local current
        current=$(readlink "$link")
        if [ "$current" = "$target" ]; then
            echo "  [ok] $label já é symlink correto"
            return
        fi
        echo "  [fix] $label era symlink pra $current, refazendo"
        rm "$link"
    elif [ -e "$link" ]; then
        echo "  [bak] Backup de $label existente → ${label}.bak"
        mv "$link" "${link}.bak"
    fi

    ln -sf "$target" "$link"
    echo "  [ok] $label → $target"
}

ensure_symlink "$REPO/commands"             "$CLAUDE/commands"      "commands/"
ensure_symlink "$REPO/claude/CLAUDE.md"     "$CLAUDE/CLAUDE.md"     "CLAUDE.md"
ensure_symlink "$REPO/claude/settings.json" "$CLAUDE/settings.json" "settings.json"

echo ""
echo "==> Pronto! Claude Code está linkado ao ai-toolkit."
echo ""
echo "Próximos passos manuais:"
echo "  1. MCP Trello: claude mcp add trello -e TRELLO_API_KEY=<key> -e TRELLO_TOKEN=<token> -- npx @delorenj/mcp-server-trello"
echo "  2. Plugin Superpowers: instalar via Claude Code marketplace"
echo "  3. Credenciais GitHub MCP (se aplicável): configurar separadamente"
echo "  4. Windows (Claude Desktop + CredMan): ver claude-mcp-setup/INSTALL.md"
