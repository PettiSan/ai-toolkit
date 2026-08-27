---
name: encerrar-sessao
description: Encerra a sessão de trabalho — verifica o estado do repositório, carimba o estado no título da sessão e escreve um resumo final. Use quando o usuário sinalizar fim do trabalho da sessão, tipicamente com o radical "encerr" — "encerre aqui", "encerre essa sessão", "podemos encerrar?", "pode encerrar". Costuma vir grudado no fim de uma instrução maior ("faz X e encerre aqui"): executar o resto primeiro, encerrar por último. NÃO disparar com "encerre o turno", que significa fim do turno de resposta dentro de um workflow, não fim da sessão; nem com fim de tarefa isolada ("termina esse arquivo").
---

# Encerrar sessão

Fecha uma sessão de trabalho de duas formas, nesta ordem de importância:

1. **Carimba o estado no título da sessão** — para o estado ser legível na lista, sem abrir nada.
2. **Escreve um resumo** no último output — para quem abrir a sessão semanas depois recuperar o
   contexto batendo o olho.

O carimbo é o entregável principal. O resumo é o complemento.

**"Encerrar" aqui significa carimbar e resumir — não matar o processo nem arquivar.** A sessão segue
viva até o usuário fechá-la na interface. Isso é deliberado (ver *Fora do escopo*), mas não é óbvio
para quem olha a lista e vê a sessão ainda ativa: por isso o Passo 4 diz isso em uma linha.

## Princípios

**Ancorar em artefato verificável, não na lembrança do transcript.** PR, commit, card, `git log`,
arquivo. Uma sessão longa já foi compactada e o modelo não viu o começo dela — resumo feito de
memória mente com confiança. Onde não houver artefato para citar, dizer que não houve.

**Não redeclarar regra que já tem dono.** Esta skill declara *o que verificar* e *o que produzir*.
As regras em si — de git, de commit, de push — moram no `CLAUDE.md` que a sessão já carregou.

**Não duplicar o que já está em ADR, PR, card ou commit.** Referenciar por link ou path.

## Passo 0 — terminar o que foi pedido antes

O pedido de encerramento quase sempre vem grudado no fim de outra instrução ("faz X e encerre aqui").
Executar X primeiro. O encerramento é o último passo, nunca o primeiro.

**Se houver ambiguidade sobre se o usuário pediu de fato o encerramento da sessão, perguntar antes de
agir.** Só em caso de dúvida — quando o pedido for claro, executar direto, sem pedir confirmação.

## Passo 1 — verificar antes de concluir

Não confie na conversa; verifique.

1. **Estado do clone.** Há trabalho não commitado? Não pushado? A branch está atrás do remoto?
   Resolver a mecânica no ambiente da própria sessão — não assumir shell, host nem formato de path.
   **Se a sessão não estiver num repositório git, pular este item** e dizer que pulou. Não inventar.
   **Se a sessão roda num worktree**, verificar o worktree *e* o clone principal — são estados
   separados, e o trabalho da sessão costuma estar no worktree.
   ⚠️ **`fatal: not a git repository` num worktree não significa "não é repositório".** É falha de
   acesso ao path, comum quando o worktree é alcançado por caminho de rede. Nesse caso, tentar de
   outra forma (a partir do path interno do próprio worktree, ou `worktree list` a partir do clone
   principal). Se ainda assim não der, **a verificação é parcial** — nunca tratar como "verificado e
   limpo", porque é exatamente onde o trabalho da sessão estaria.
2. **Alinhamento depois de escrita remota.** Se a sessão escreveu no remoto por API (`push_files` ou
   equivalente), o clone local não aprende que o commit existe. Verificar o alinhamento.
3. **O que ficou aberto.** PR não mergeado, card não movido, TODO registrado, teste não rodado,
   pergunta feita ao usuário e nunca respondida.

## Passo 2 — decidir o estado

| Prefixo | Significado | Quem carimba |
|---|---|---|
| `✅` | encerrada, nada pendente | esta skill |
| `❗` | pendência conhecida, registrada no resumo | esta skill |
| `❓` | sessão varrida, sem conseguir determinar o estado | skill de varredura (ainda não existe) |
| *(nada)* | nunca passou por encerramento — estado desconhecido | — |

**O pedido do usuário não decide o estado.** Se o passo 1 achou pendência, o estado é `❗` mesmo que
ele tenha dito "encerre". Dizer qual é a pendência e por que ela não fecha.

**`✅` exige verificação completa.** Ele afirma "nada pendente", e essa afirmação só se sustenta se o
passo 1 conseguiu olhar tudo o que se propôs a olhar. Se qualquer parte não pôde rodar, `✅` está
proibido: o estado vira `❗`, e a pendência é a própria verificação que faltou. Não existe `✅` com
ressalva escondida no corpo do resumo — "achei tudo limpo no que consegui ver" não é `✅`.

## Passo 3 — carimbar

Dois movimentos, nesta ordem:

1. **Ler o título atual** — com a tool que devolve os metadados da *própria* sessão (`get_session`
   com `session_id: "self"`, no ambiente de desktop). **Nunca usar a tool de listar sessões para
   isso: ela exclui a sessão corrente.** Foi assim que execuções passadas carimbaram o slug do
   worktree achando que era o título (`✅ portal-itau-contract-guarantees-3582f4-71`) e depois
   "consertaram" reescrevendo — dois títulos inventados, nenhum deles o do usuário.
2. **Renomear** prefixando o texto lido: `✅ <título atual>` ou `❗ <título atual>`.

**Não carimbar sem ter lido.** Se a leitura falhar, cair no fallback de agente remoto abaixo —
chutar o título é pior do que não carimbar.

- **Prefixo no início** — a lista de sessões trunca pela direita.
- **Nunca reescrever o título — só prefixar.** O texto que vem depois do prefixo tem que sair
  idêntico ao que já estava lá, caractere por caractere. Não melhorar, não encurtar, não acrescentar
  número de card, não corrigir o que parece errado. O usuário reconhece a sessão por esse texto: um
  título "melhor" é uma sessão que ele não acha mais. Se o título estiver de fato ruim, **sugerir um
  novo no resumo** e deixar a decisão com ele. A única substituição permitida é trocar o prefixo de
  uma execução anterior, para não empilhar.
- **Se as tools de sessão não existirem — sessão com agente remoto.** O sinal é o `cwd`: quando ele
  é um path nativo do host remoto (`/home/<user>/...`) em vez do path pelo qual o app alcança aquele
  host, o processo do agente nasceu **dentro** da máquina remota, e as tools que o aplicativo injeta
  não atravessam essa fronteira. Não falhar: incluir o `✅`/`❗` na linha de estado do resumo e dizer
  que o carimbo no título não existe em sessão com agente remoto.

  ⚠️ **Não inventar explicação para a ausência.** Especificamente: não chamar isso de "sessão de
  linha de comando" nem de "outro aplicativo" — pode ser o mesmo app e a mesma conta; o que muda é
  onde o processo do agente roda. Errar o diagnóstico do próprio ambiente é pior que a falha em si,
  porque manda o usuário procurar o problema no lugar errado.

## Passo 4 — escrever o resumo

Curto. Só o que um leitor precisa para retomar daqui a duas semanas:

1. **Estado** — a primeira linha do output, com o marcador de origem na frente:

   `[encerramento] SESSÃO ENCERRADA`
   `[encerramento] SESSÃO EM ABERTO — falta <X>`

   O marcador serve para o leitor distinguir um encerramento de verdade de um resumo qualquer
   escrito no fim de uma sessão, e para a busca em transcript achar sessões que passaram por aqui
   mesmo que o título tenha perdido o prefixo.

   **Ele é uma afirmação, então só pode sair limpo se os passos 1 a 3 rodaram inteiros.** Quando
   alguma parte não pôde rodar, a ressalva vai **na própria linha de estado**, não enterrada no
   corpo — a linha de estado é o que o leitor bate o olho, e é ela que precisa ser honesta:

   `[encerramento] SESSÃO EM ABERTO — verificação parcial: <o que não pôde ser verificado>`

   Explicar por que não deu, e o que precisaria para conseguir, fica no item 5. Mas a linha de
   estado nunca esconde a lacuna.
2. **Pergunta de abertura** — o que abriu a sessão, e a resposta que ela produziu.
3. **Entregue** — o que foi concluído, com link (PR, commit, card).
4. **Aberto com desenho pronto** — o que virou card ou issue para depois, com link.
5. **Estado do clone** — o resultado do passo 1. Se estiver sujo ou desalinhado, dizer, mesmo que
   seja incômodo depois de uma sessão que pareceu terminada.
6. **Pendência e próximo passo** — só se o estado for `❗`. Incluir qual modelo a próxima sessão
   deveria usar e por quê.
7. **Como fechar de fato** — uma linha, sempre, mesmo em `✅`: o encerramento carimbou e resumiu, e
   o **processo da sessão segue vivo** até o usuário fechá-la na interface. Arquivar é decisão dele
   e não é feita por esta skill. Sem essa linha, uma sessão "encerrada" que continua ativa na lista
   parece falha da skill.

Sem recap de processo e sem oferecer ajuda no fim. Este resumo é o último output da sessão.

## Se a sessão ficou em aberto

Oferecer o `handoff`. Os dois não se substituem: o resumo é para o usuário se relembrar, dentro da
própria sessão; o handoff é o documento para outro agente continuar o trabalho.

## Fora do escopo

**Não arquivar a sessão.** Arquivar encerra o processo e, por padrão, apaga o worktree — havendo
trabalho não commitado ali, é perda de dado. Só se o usuário pedir explicitamente, e só depois de o
passo 1 confirmar que está tudo limpo e pushado.

**Não apagar, podar nem desregistrar worktree por iniciativa própria — e não sugerir que se faça
isso.** A verificação do passo 1 é **somente leitura**. Worktree órfão, marcado `prunable`, ou com
registro apontando para caminho inacessível: tudo isso se **relata como fato**, nunca como pendência
a resolver. "Pode ser removido quando quiser" numa lista de pendências não é observação, é ordem de
serviço — e o resumo é exatamente o documento que o usuário lê para decidir o que fazer em seguida.

O motivo não é risco de perder código: é que **o worktree é o diretório de trabalho da própria
sessão**. Removê-lo deixa a sessão sem casa e **inacessível**, mesmo com tudo commitado, pushado e
mergeado. Confirmar "não há trabalho perdido" **não** cobre esse dano — então nenhuma verificação,
por mais completa, torna a remoção uma boa ideia para *sugerir*.

**Isto não restringe o usuário.** Se ele pedir explicitamente para remover o worktree ou arquivar a
sessão, execute normalmente, sem fricção e sem sermão. A proibição é sobre a skill agir ou
recomendar por conta própria — a decisão é dele, e ele não precisa da opinião dela para tomá-la.
