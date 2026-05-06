# Global — CLAUDE.md

## Quem sou eu e onde estou

Desenvolvedor da Smartcob trabalhando em três repositórios simultaneamente. Todos os projetos ficam em `~/projects/` no Ubuntu (WSL2).

---

## Meus projetos

| Projeto | Path | Repositório | Identificador Trello |
|---------|------|-------------|----------------------|
| `smartcob-monorepo` | `~/projects/smartcob-monorepo` | `SmartcobSolutions/smartcob-monorepo` | — |
| `lovabledue-chat` | `~/projects/lovabledue-chat` | `SmartcobSolutions/lovabledue-chat` | `[WEBCHAT-GENERICO]` |
| `chat-mm-itau` | `~/projects/chat-mm-itau` | `SmartcobSolutions/chat-mm-itau` | `[WEBCHAT-ITAU]` |

Cada projeto tem seu próprio `CLAUDE.md` com contexto completo. **Sempre leia o CLAUDE.md do projeto antes de qualquer ação.**

---

## Como identificar o projeto ativo

1. Pelo diretório atual (`pwd`)
2. Pelo prefixo do card Trello mencionado pelo usuário
3. Pelo nome do repositório GitHub mencionado

Nunca misture contexto entre projetos. Se a sessão mudar de projeto, releia o CLAUDE.md correspondente.

---

## Regras globais de comportamento

**Nunca agir sem contexto.** Se não estiver claro em qual projeto estamos, perguntar antes de executar qualquer ação.

**Nunca commitar direto nas branches de integração ou produção** de nenhum projeto.

**Sempre mostrar o diff e aguardar aprovação explícita** antes de commitar — em qualquer projeto.

**GitHub via MCP** quando SSH não estiver disponível: usar sempre `push_files` para múltiplos arquivos. Nunca usar `create_or_update_file` repetidamente.

---

## MCPs disponíveis

| MCP | Uso |
|-----|-----|
| `mcp_github_*` | PRs, branches, issues, push de arquivos |
| `mcp_trello_*` | Cards, listas, boards, comentários |
| `mcp__ide__*` | Diagnósticos e execução de código no IDE |

---

## Trello — Board principal

**Board ID:** `65452685593555d57aa6aaf7`

| Lista | ID |
|-------|----|
| Ready To Do | `654526c77d7d64270e41ce8b` |
| Doing (Apenas 1, Informar Data) | `654526d8e848f7b27e32f3e7` |
| Doing (PAUSED/BLOCKED) | `6787e6feba62de1d7fd9ef3c` |
| To Review (PR) | `654be3bfa4f058f3010bdf90` |
| To Validate (Homologacao/Preprod) | `65525b515bd021894e00dcfb` |
| Validated | `65525b58e7ce587d568ec7e2` |
| To Validate (Producao) | `654be3c561f40a9dc0f49467` |
| Done | `6567333327f2a10ed8369473` |

Ao receber "pega próximo card", identificar o projeto ativo pelo prefixo e executar o workflow definido no CLAUDE.md do projeto correspondente.
