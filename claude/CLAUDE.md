# Global — CLAUDE.md

> **Fonte única.** Este arquivo é a fonte da verdade do CLAUDE.md global, nas duas máquinas e nos dois
> perfis. No Linux/WSL o `setup.sh` symlinka; no Windows o `claude-mcp-setup/setup.ps1` copia. **Não
> editar `~/.claude/CLAUDE.md` diretamente** — no Windows a edição sobrevive até o próximo `setup.ps1`
> e depois some, e foi exatamente assim que os dois arquivos divergiram em julho/2026.

## Quem sou eu e onde estou

Desenvolvedor da Smartcob trabalhando em quatro repositórios simultaneamente. Todos os projetos ficam em `~/projects/` no Ubuntu (WSL2).

---

## Meus projetos

| Projeto | Path | Repositório | Identificador Trello |
|---------|------|-------------|----------------------|
| `smartcob-monorepo` | `~/projects/smartcob-monorepo` | `SmartcobSolutions/smartcob-monorepo` | — |
| `lovabledue-chat` | `~/projects/lovabledue-chat` | `SmartcobSolutions/lovabledue-chat` | `[WEBCHAT-GENERICO]` |
| `chat-mm-itau` | `~/projects/chat-mm-itau` | `SmartcobSolutions/chat-mm-itau` | `[WEBCHAT-ITAU]` |
| `custom-simple-sms` | `~/projects/custom-simple-sms` | `jonatasfazenda/custom-simple-sms` (**Bitbucket**) | `[BACKOFFICE]` |

Cada projeto tem seu próprio `CLAUDE.md` com contexto completo. **Sempre leia o CLAUDE.md do projeto antes de qualquer ação.**

---

## Como identificar o projeto ativo

1. Pelo diretório atual (`pwd`)
2. Pelo prefixo do card Trello mencionado pelo usuário
3. Pelo nome do repositório GitHub mencionado

Nunca misture contexto entre projetos. Se a sessão mudar de projeto, releia o CLAUDE.md correspondente.

---

## Como me responder (postura padrão)

A postura de 9 itens é **camada 1** e chega pelo plugin `smartcob-ai`
(`SmartcobSolutions/smartcob-ai-governance`), injetada em toda sessão pelo hook `SessionStart`.
**Não há cópia aqui** — o resumo de 5 itens que morava neste arquivo foi removido na fase 1 do
plano, junto da cópia do monorepo: o resumo existia por limitação de replicação, e o plugin
remove a limitação (**A6**).

Máquina nova, ou postura não chegando: `/plugin marketplace add
SmartcobSolutions/smartcob-ai-governance` + `/plugin install smartcob-ai@smartcob-ai-governance`
em **user scope**, e ligar o auto-update (nasce desligado). Nos dois perfis, não em um.

---

## Regras globais de comportamento

**Nunca agir sem contexto.** Se não estiver claro em qual projeto estamos, perguntar antes de executar qualquer ação.

**Nunca commitar direto nas branches de integração ou produção** de nenhum projeto.

**Sempre mostrar o diff e aguardar aprovação explícita** antes de commitar — em qualquer projeto.

**Mensagens de commit sempre em inglês** — independentemente do idioma da conversa e do que estiver no `git log`. Verificar `git log` apenas para seguir o *formato* do repo (tipo, escopo, estrutura), nunca para inferir idioma.

**Nunca adicionar Co-Authored-By** nas mensagens de commit.

**Nunca adicionar rodapé de atribuição em corpo de PR** — nada de `🤖 Generated with Claude Code` nem equivalente. O harness do Claude Code injeta isso por default no system prompt (*"End PR bodies with…"*); esta linha existe só para sobrescrever esse default, que é o único motivo de aquilo aparecer. Vale para PR novo e para edição de corpo de PR existente. O `plano-economia-de-tokens` do `smartcob-ai-governance` já citava essa regra como vigente antes de ela existir — passou a existir em 2026-09-04.

**Git por SSH é o caminho padrão** desde 2026-08-28 — `git push origin <branch>`, nos dois perfis, **sem pré-requisito nenhum** desde 2026-09-09: a chave de git não tem passphrase e não depende de ssh-agent (ver seção Windows + WSL). **Não** pushar por URL HTTPS com token do `gh`: é workaround de autenticação e reabre o popup do Git Credential Manager.

**Mecanismo de commit no worktree do Desktop — depende do repo.**

- **`smartcob-monorepo`: `git commit --no-verify` com o git do Windows, dentro do próprio worktree.** Default desde a [ADR-0039](https://github.com/SmartcobSolutions/smartcob-monorepo/blob/develop/docs/adr/0039-revisa-a-adr-0004-e-adota-git-nativo-como-mecanismo-de-commit.md), que revogou o default `push_files` da ADR-0004. A flag é necessária porque ali o hook roda com o PATH do **Windows**, que não tem `yarn`; ela não desliga defesa real — `nx affected --target=lint` bloqueia todo PR pela CI. Escopos e detalhe no `CLAUDE.md` raiz do repo.
- **Nos outros três repos, `push_files` continua o default.** A ADR-0039 **não** se estende a eles: a premissa de line-endings só cai por causa do `.gitattributes` (`* text=auto eol=lf`) **do monorepo**, e `lovabledue-chat`, `chat-mm-itau` e `custom-simple-sms` não têm `.gitattributes` nenhum (verificado em 2026-09-09). Sem medir, git nativo do Windows ali pode reabrir o churn CRLF que a ADR-0004 descreveu.

**`push_files`** — residual no monorepo, default nos demais. Para múltiplos arquivos, sempre `push_files`, nunca `create_or_update_file` repetidamente. **Limite da tool:** não deleta arquivos (a API só escreve blobs) e exige conteúdo integral — commit com deleção ou atômico vai por `git commit` + `git push`. Como transcreve o arquivo inteiro, montar sobre `get_file_contents` da branch do PR, **nunca** sobre a cópia do worktree: foi essa transcrição que causou o clobber do PR #316 do monorepo.

**Depois de todo `push_files`: `git fetch` + alinhar a branch local com `origin/<branch>`.** O `push_files` escreve direto no remoto pela API — **o clone local nunca aprende que o commit existe**. O resultado é um clone que parece ter trabalho pendente que na verdade já foi pushado, e uma branch local atrás do remoto. Isso já causou perda real: um fix ficou só no working tree, foi dado como perdido, e uma sessão seguinte o "resgatou" e commitou de novo — gerando dois PRs duplicados do mesmo conteúdo. Se sobrar working tree sujo depois do alinhamento, **dizer isso no fim da sessão** (e no handoff, se houver) em vez de deixar quieto. Checklist genérico de fim de sessão não resolve — a causa é mecânica, não de disciplina; é esta regra específica e verificável que fecha o buraco. **O caminho de git nativo não precisa disto** — lá o clone aprende o commit sozinho.

**Exploração de arquivos: preferir as tools dedicadas `Glob` (encontrar arquivos por padrão) e `Read` (ler conteúdo) em vez de `cd`/`ls`/`find`/`cat` no Bash.** São read-only, mais rápidas e não disparam prompt de permissão. Só usar Bash para navegação/listagem quando não houver tool equivalente.

**Explicar regra de governança = ler a fonte, não a memória.** Ao explicar ou tirar dúvida sobre uma regra de governança já documentada, ler o arquivo real da doc antes de responder (nunca responder de memória), citar a seção/arquivo de origem, e sinalizar se o conteúdo pode estar desatualizado em relação à branch `develop`.

**Edição de doc pessoal de decisão/planejamento = sessão Opus.** Editar um doc pessoal de decisão ou planejamento (plano de melhoria, auditoria, análise que envolve raciocínio) roda em **sessão Opus**, cravado. Só formatação/registro mecânico — mover seção, corrigir link, colar decisão já tomada — pode cair em modelo menor. Se o pensamento é o conteúdo, quem pensa tem que ser Opus.

---

## Windows + WSL (Claude Desktop)

> Só se aplica ao perfil **Windows/Desktop**. Em sessão Linux/WSL CLI, pule esta seção inteira.
>
> **Modo de permissão: `auto` (automático). Atualizado em 2026-08-17.** De 2026-07-23 a 2026-08-17 o
> perfil rodou em `bypassPermissions`, ligado para parar os prompts dos comandos `wsl`. Migrado para
> auto mode e o toggle "Permitir modo de bypass de permissões" foi **desligado** nas configurações do
> Desktop — enquanto ligado, ele é a saída de menor resistência na primeira fricção, e a migração
> nunca se completa. Para reverter, é esse toggle (vale só para sessões novas).
>
> **Consequência para as duas primeiras regras: o motivo original delas voltou a valer.** Elas
> nasceram para casar com a allowlist de permissões; sob bypass isso tinha caducado, porque bypass
> aprova tudo e allow rule vira letra morta. No auto mode, allow rule estreita — como as ~150
> `Bash(wsl git -C * ...)` do `settings.windows.json` — **resolve antes do classificador**, sem
> latência e sem chamada de modelo. Escrever o comando na forma que a allowlist reconhece deixou de
> ser cosmético e voltou a ser o que evita o gate. As regras valem agora pelos dois motivos, o
> funcional e o de permissão.
>
> **O que o auto mode muda na prática:** um segundo modelo (classificador) avalia cada ação antes de
> executar. Não pergunta — aprova em silêncio ou **nega**. Negação aparece em `/permissions` → aba
> *Recently denied*, com retry pela tecla `r`. Escrita em protected path (`.git`, `.claude`, `.vscode`,
> `.idea`, `.husky`, `.mvn`, `.gitconfig`, …) **nunca** é pré-aprovada por allow rule, em modo nenhum —
> no auto ela vai ao classificador. É onde a fricção aparece, tipicamente em sessão que mexe em
> `.claude/`. Config do que o classificador considera confiável: bloco `autoMode` em
> `~/.claude/settings.json` (só perfil de usuário; ele não lê settings de projeto). Inspecionar com
> `claude auto-mode config`, rodado no shell do **Windows** para auditar o perfil do Desktop.
>
> O gotcha do MSYS nunca teve relação com permissão e é obrigatório em qualquer modo.

**Git em repo do WSL a partir do Desktop:** rodar `wsl git -C /home/pettisan/projects/<repo> <comando>`, **um comando por vez**, sem `2>&1`, pipes ou encadeamento (`&&`, `;`). **Nunca** usar `wsl bash -c "cd <path> && git ..."` — é execução arbitrária, e a forma com `-C` é mais legível e mais fácil de auditar no transcript.

**Não anexar `; echo $?` (nem outras capturas de exit code) aos comandos.** O exit code já é reportado pela tool Bash — é ruído puro.

**Rodar o runner do projeto (`yarn`, `nx`) a partir do Desktop:** desde 2026-09-09 o shell não-interativo **tem** `yarn`/`nx` no PATH — os shims do asdf saíram do `~/.zshrc` (que não roda em shell não-interativo) para o `~/.zshenv`. Então `wsl yarn ...` e `wsl npx nx ...` funcionam direto; conferir com `wsl which yarn` antes de concluir que está quebrado. Se um dia voltar a faltar, é a linha do `~/.zshenv` que saiu — versionada em `dotfiles/zshenv`. ⚠️ Nenhuma dessas formas casa com a allowlist, que só cobre `wsl git -C ...` → vai ao classificador.

> ⚠️ **Gotcha do Git Bash (MSYS):** o shell Bash do Desktop é o Git Bash, que faz *path conversion* — reescreve um argumento unix-style como `/home/pettisan/...` para `C:/Program Files/Git/home/pettisan/...` antes de repassar ao `wsl`, quebrando o `-C`. **Correção (testada):** prefixar o comando com `MSYS_NO_PATHCONV=1`, ex: `MSYS_NO_PATHCONV=1 wsl git -C /home/pettisan/projects/<repo> <comando>`. Definir a variável via `settings.json` (`env`) ou via profile do Git Bash (`.bashrc`/`.bash_profile`) **não** resolve: a tool Bash roda em shell não-interativo e não-login, que não herda nenhum dos dois.

**Autenticação git do lado Windows: `core.sshCommand = wsl ssh`.** O git do Windows não tem chave SSH própria (`~/.ssh` só com `known_hosts`); sem essa config ele cai em HTTPS e abre o **Git Credential Manager**, que trava a sessão num popup de seleção de conta. Configurado e verificado em 2026-08-28 (GitHub e Bitbucket). Se o popup voltar: conferir `git config --global core.sshCommand` e conferir se o `origin` do repo é SSH, não HTTPS.

> ✅ **Git não usa ssh-agent.** A chave é a `~/.ssh/id_ed25519`, **sem passphrase**, lida do disco direto — chamada não-interativa autentica sem nenhum preparo. **`Permission denied (publickey)` não é agent frio:** conferir, nesta ordem, se o `origin` é SSH e não HTTPS, se a chave existe com `600`, e se está registrada na conta daquele host. Chave sem passphrase é decisão do usuário, tomada com o trade-off na mesa (quem lê `~/.ssh/` pode pushar como ele) — **não sugerir "voltar a proteger a chave" como melhoria.** Por que duas tentativas com agent falharam: PR #30 e os comentários do `~/.zshrc`.

**Mecânica dos worktrees do Desktop** (`.claude/worktrees/<id>`):

- O `.git` do worktree aponta caminho **Windows** (`//wsl.localhost/...`): `wsl git -C <worktree>` devolve `not a git repository`, e é o git do Windows que opera lá dentro — é ele, e não uma limitação, que a ADR-0039 elegeu como mecanismo de commit no monorepo. **Não** "consertar" com `git worktree repair` — conserta o WSL e quebra o Desktop (ADR-0004 do monorepo).
- **Commit no worktree exige `--no-verify`.** O hook do husky roda com o PATH do **Windows**, que não tem `yarn`; sem a flag, todo `git commit` morre com `yarn: command not found` (exit 127). No `smartcob-monorepo` isso não abre mão de gate nenhum — o `nx affected --target=lint` bloqueia todo PR pela CI (ADR-0017). **Não** "consertar" o PATH nem instalar `node_modules` ali para ligar o hook: religa o `prettier` do `lint-staged` em `.md` legado, que a ADR-0019 removeu de propósito. Os artefatos do monorepo enunciam a regra em vocabulário neutro e **não** repetem esta mecânica — ela é camada 3, e mora aqui.
- **Conferir a base antes de editar.** O Desktop deriva o worktree da branch em que o clone principal estava, não da branch de integração do projeto.
- **O `.env` (gitignored) não acompanha troca de branch.** Sintoma: chamadas viram `/undefined/...` e dão 404. Copiar do worktree de origem e **reiniciar o vite** (lê `.env` só no boot). O `.claude/launch.json` também é por-worktree.
- **Conferir estado do repo sempre com `wsl git -C <path> status`**, nunca com o git do Windows: ele aplica `core.autocrlf` do perfil Windows e reescreve com CRLF os arquivos que toca, mostrando o repo limpo enquanto o WSL vê dezenas de modificados.

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

> IDs de lista **não moram aqui**. Cada consumidor carrega os seus: o `/pegar-card` (monorepo) e o
> `/trello-report` (este repo) embutem as listas que usam. Duplicar a tabela aqui era contexto pago
> em toda sessão — inclusive nas dos webchats, que não usam o board dessa forma.

Ao receber "pega próximo card", identificar o projeto ativo pelo prefixo e executar o workflow definido no CLAUDE.md do projeto correspondente.

**Formato de referência a card do Trello.** Sempre `Card: [**<shortLink>**](https://trello.com/c/<shortLink>)` — ex.: `Card: [**nt321mc7**](https://trello.com/c/nt321mc7)`. O shortLink fica **em negrito dentro do link** (markdown aceita `**` dentro do texto do link); o Desktop renderiza como "Card: **nt321mc7** (→ trello.com)". Nunca `#<número>` nem URL crua. Exceção: saídas para WhatsApp (`/trello-report`) mantêm URL crua em linha própria — WhatsApp não renderiza markdown.

**Defaults de criação de card.** Ao criar card no Trello (via `/criar-card` ou pedido informal), assumir por padrão: lista **Backlog**, atribuído a **mim**, contexto rico da sessão. Override só quando dito explicitamente ("na lista X", "atribui pra Y").
