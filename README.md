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
├── dotfiles/                      # Shell e ssh do WSL (symlink p/ ~/.zshenv, ~/.zshrc, ~/.ssh/config)
│   └── zshenv.local.example       # Template dos segredos — o .local real nunca é versionado
├── commands/                      # Slash commands disponíveis no Claude Code (~/.claude/commands/)
├── agents/                        # Subagentes (~/.claude/agents/) — ex.: advisor
└── skills/                        # Skills (~/.claude/skills/) — ex.: handoff (vendorizada, ver abaixo)
```

> **Dois settings, dois runtimes.** `claude/settings.json` é o do **CLI no WSL** (symlinkado).
> `claude/settings.windows.json` é um **snapshot manual** do `~/.claude/settings.json` do **Claude
> Desktop no Windows** — esse arquivo do Desktop não é symlink, então o snapshot é a única cópia
> versionada. Re-sincronize à mão quando mudar o settings do Desktop. Restaure num PC novo com
> `claude-mcp-setup/setup.ps1 -RestoreSettings` (faz backup do existente antes).

> **Credenciais MCP** (tokens de API) nunca ficam neste repo. No Windows ficam no Windows
> Credential Manager (DPAPI) via o setup em `claude-mcp-setup/`. No Linux/WSL ficam em env vars
> exportadas de `~/.zshenv.local` — **texto plano, modo 600, fora de qualquer repo**.
>
> Texto plano no WSL é decisão explícita, não descuido: o harness do Claude Code Desktop já perdeu
> acesso a esses tokens vindos de cofre mais de uma vez, e o risco de vazamento foi aceito em troca
> de o MCP subir sempre. O `FIGMA_API_KEY` é a exceção — vem do `pass`, no `~/.zshrc`, e por isso só
> existe em shell interativo. Não migrar o Trello para o `pass` sem falar com o dono do repo.

---

## Restaurar em um novo PC

### Linux / macOS / WSL

```bash
# 1. Clonar
git clone git@github.com:PettiSan/ai-toolkit.git ~/projects/ai-toolkit

# 2. Rodar o setup (symlinks em ~/.claude/ e os dotfiles de shell/ssh)
bash ~/projects/ai-toolkit/setup.sh

# 3. Criar o arquivo de segredos (não versionado) e preencher
cp ~/projects/ai-toolkit/dotfiles/zshenv.local.example ~/.zshenv.local
chmod 600 ~/.zshenv.local

# 4. Instalar o plugin Superpowers via Claude Code marketplace
```

> O passo 2 **substitui** `~/.zshenv`, `~/.zshrc` e `~/.ssh/config` por symlinks para `dotfiles/`,
> guardando o que existia como `.bak` ao lado. Numa máquina que já tem shell configurado, confira o
> `.bak` antes de descartar. O passo 3 não é opcional: sem `~/.zshenv.local` o shell sobe normal e é
> o MCP do Trello que falha, na primeira chamada, sem mensagem que aponte a causa.

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

## Skills vendorizadas de upstream

Skills em `skills/` que vieram de um repo de terceiro (hoje só `handoff`, do
[`mattpocock/skills`](https://github.com/mattpocock/skills), MIT) são **cópias congeladas**, não
consumidas do upstream. Motivo: o upstream é ativo e já refatorou skills de forma incompatível sem
aviso; e a `handoff` daqui carrega uma adaptação local (a linha de "next-session model", governança
Opus/Sonnet) que uma sincronização automática atropelaria. O cabeçalho de proveniência dentro do
`SKILL.md` marca o quê é upstream e o quê é local. Para conferir drift do upstream é leitura manual —
não rode nenhuma CLI que seja dona da pasta e a sobrescreva.

Os dois instaladores instalam `skills/`: o `setup.sh` symlinka cada pasta de skill (Linux/WSL) e o
`claude-mcp-setup/setup.ps1` copia cada uma (Windows), ambos preservando skills local-only não
versionadas aqui.

---

## Relação com o smartcob-monorepo

A versão canônica do `/trello-report` vive aqui em `commands/trello-report.md` — é um comando global (roda de qualquer projeto), então a tabela de prefixos de card fica embutida no próprio arquivo em vez de referenciar `smartcob-monorepo/docs/governanca/trello-refs.md` por path relativo. Se um prefixo mudar lá, atualize a tabela embutida aqui manualmente (duplicação assumida deliberadamente).
