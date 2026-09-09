#!/bin/bash
set -e

REPO="$(cd "$(dirname "$0")" && pwd)"
CLAUDE="$HOME/.claude"

echo "==> Configurando Claude Code a partir do ai-toolkit..."

mkdir -p "$CLAUDE"
mkdir -p "$CLAUDE/agents"

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
ensure_symlink "$REPO/agents/advisor.md"    "$CLAUDE/agents/advisor.md" "agents/advisor.md"

# Dotfiles de shell. Os segredos NÃO estão aqui: o zshenv sourceia ~/.zshenv.local,
# que fica só na máquina, em 600, e nunca é versionado (dotfiles/zshenv.local.example
# é o template). Sem o .local o shell sobe igual — quem quebra é o MCP do Trello.
ensure_symlink "$REPO/dotfiles/zshenv" "$HOME/.zshenv" ".zshenv"
ensure_symlink "$REPO/dotfiles/zshrc"  "$HOME/.zshrc"  ".zshrc"

# ~/.ssh/config segue o mesmo padrão, com dois cuidados próprios: o diretório
# precisa existir com 700 antes, e um symlink quebrado aqui (repo movido, renomeado
# ou apagado) derruba a autenticação git dos DOIS perfis de uma vez — o git do
# Windows delega para cá via core.sshCommand = wsl ssh. Se isso acontecer, o
# arquivo original está no backup .bak que o ensure_symlink deixa.
mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"
ensure_symlink "$REPO/dotfiles/ssh_config" "$HOME/.ssh/config" ".ssh/config"

# Skills are vendored per-folder (each is a directory: SKILL.md + support files). Symlink
# each one individually rather than the whole skills/ dir, so ~/.claude/skills can still
# hold local-only skills that are not versioned here.
mkdir -p "$CLAUDE/skills"
for skill in "$REPO"/skills/*/; do
    [ -d "$skill" ] || continue
    name=$(basename "$skill")
    ensure_symlink "$REPO/skills/$name" "$CLAUDE/skills/$name" "skills/$name"
done

echo ""
echo "==> Pronto! Claude Code está linkado ao ai-toolkit."
echo ""
echo "Próximos passos manuais:"
echo "  1. Segredos do Trello: cp dotfiles/zshenv.local.example ~/.zshenv.local && chmod 600 ~/.zshenv.local && preencher"
echo "  2. Plugin Superpowers: instalar via Claude Code marketplace"
echo "  3. Credenciais GitHub MCP (se aplicável): configurar separadamente"
echo "  4. Windows (Claude Desktop + CredMan): ver claude-mcp-setup/INSTALL.md"
