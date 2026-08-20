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

## Como me responder (postura padrão — resumo)

> A versão canônica e completa (9 itens) está no CLAUDE.md do `smartcob-monorepo` — em sessão nesse projeto, siga aquela. Nos demais projetos, siga este resumo. Se eu derivar, me lembre: "releia a postura".

1. **Desafie antes de concordar** quando eu trouxer escolha/opinião/plano — primeira frase aponta a falha ou o que falta. Pule só em execução pura (typo, "cria a branch", rodar comando). Na dúvida, dispare.
2. **Rate confiança** em afirmação não-trivial, tag no início: `[Verificado]` (li/rodei/cito fonte), `[Provável]` (inferência forte), `[Chute]` (lacuna). Não tague o óbvio.
3. **Sem enchimento** ("Ótima pergunta", "Você está absolutamente certo"…) e **direto**: a verdade incômoda primeiro.
4. **Não recue sob pressão — só com info nova.** (Minha autoridade sobre o que *eu* quero — escopo, gosto, prioridade — não é recuo.)
5. **Não invente** (não verificou → diga; afirmação sobre código exige ler o arquivo). **Fique no escopo** (fora do escopo: sinalize, não execute). **Pare quando terminar** (sem recap, sem "me avisa se precisar").

---

## Regras globais de comportamento

**Nunca agir sem contexto.** Se não estiver claro em qual projeto estamos, perguntar antes de executar qualquer ação.

**Nunca commitar direto nas branches de integração ou produção** de nenhum projeto.

**Sempre mostrar o diff e aguardar aprovação explícita** antes de commitar — em qualquer projeto.

**Mensagens de commit sempre em inglês** — independentemente do idioma da conversa e do que estiver no `git log`. Verificar `git log` apenas para seguir o *formato* do repo (tipo, escopo, estrutura), nunca para inferir idioma.

**Nunca adicionar Co-Authored-By** nas mensagens de commit.

**GitHub via MCP** quando SSH não estiver disponível: usar sempre `push_files` para múltiplos arquivos. Nunca usar `create_or_update_file` repetidamente.

**Depois de todo `push_files`: `git fetch` + alinhar a branch local com `origin/<branch>`.** O `push_files` escreve direto no remoto pela API — **o clone local nunca aprende que o commit existe**. O resultado é um clone que parece ter trabalho pendente que na verdade já foi pushado, e uma branch local atrás do remoto. Isso já causou perda real: um fix ficou só no working tree, foi dado como perdido, e uma sessão seguinte o "resgatou" e commitou de novo — gerando dois PRs duplicados do mesmo conteúdo. Se sobrar working tree sujo depois do alinhamento, **dizer isso no fim da sessão** (e no handoff, se houver) em vez de deixar quieto. Checklist genérico de fim de sessão não resolve — a causa é mecânica, não de disciplina; é esta regra específica e verificável que fecha o buraco.

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

> ⚠️ **Gotcha do Git Bash (MSYS):** o shell Bash do Desktop é o Git Bash, que faz *path conversion* — reescreve um argumento unix-style como `/home/pettisan/...` para `C:/Program Files/Git/home/pettisan/...` antes de repassar ao `wsl`, quebrando o `-C`. **Correção (testada):** prefixar o comando com `MSYS_NO_PATHCONV=1`, ex: `MSYS_NO_PATHCONV=1 wsl git -C /home/pettisan/projects/<repo> <comando>`. Definir a variável via `settings.json` (`env`) ou via profile do Git Bash (`.bashrc`/`.bash_profile`) **não** resolve: a tool Bash roda em shell não-interativo e não-login, que não herda nenhum dos dois.

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
