#!/usr/bin/env node
'use strict';

/**
 * /trello-report — script único, sem shell composto.
 * Global: não depende de estar dentro de nenhum repo específico. Caminho de invocação é
 * literal e fixo (ver .claude/commands/trello-report.md), pra que a chamada Bash nunca
 * tenha $()/${}/&&/heredoc/loop e nunca caia no gate de "shell syntax that cannot be
 * statically analyzed" do Claude Code — e possa ser allowlisted como match exato.
 *
 * Não usa GET /members/me/cards (bug conhecido: retorna todos os cards de TODOS os boards
 * que o usuário acessa, sem filtro de data — já visto passar de 180 cards em produção).
 * Em vez disso resolve o member ID primeiro e filtra candidatos (por data+lista) antes de
 * buscar detalhes por card.
 */

const { execSync } = require('child_process');

const BOARD_ID = '65452685593555d57aa6aaf7';
const DOING_LIST_ID = '654526d8e848f7b27e32f3e7';

const TARGET_LISTS = {
  '654be3bfa4f058f3010bdf90': { section: 'Em Revisão (PR)', emoji: '🔍', rank: 1 },
  '65525b515bd021894e00dcfb': { section: 'Para Homologação', emoji: '🏗️', rank: 2 },
  '654be3c561f40a9dc0f49467': { section: 'Para Produção', emoji: '🚀', rank: 3 },
};

// Duplicado deliberadamente de smartcob-monorepo/docs/governanca/trello-refs.md —
// este comando roda de qualquer diretório, não só de dentro do monorepo. Se a tabela
// mudar lá, atualizar aqui também.
const PREFIXES = [
  '[PORTAL-GENERICO]',
  '[PORTAL-ITAU]',
  '[PORTAL-EMPRESA]',
  '[LANDING PAGE]',
  '[DESIGN-SYSTEM]',
  '[MONOREPO]',
  '[WEBCHAT-GENERICO]',
  '[WEBCHAT-ITAU]',
];

const PREFIX_KEYWORDS = [
  { prefix: '[PORTAL-ITAU]', keywords: ['itau', 'itaú'] },
  { prefix: '[PORTAL-GENERICO]', keywords: ['generico', 'genérico'] },
  { prefix: '[PORTAL-EMPRESA]', keywords: ['empresa'] },
  { prefix: '[LANDING PAGE]', keywords: ['landing'] },
  { prefix: '[DESIGN-SYSTEM]', keywords: ['design-system', 'design system'] },
  { prefix: '[WEBCHAT-ITAU]', keywords: ['webchat-itau', 'chat-mm-itau'] },
  { prefix: '[WEBCHAT-GENERICO]', keywords: ['webchat-generico', 'lovabledue'] },
  { prefix: '[MONOREPO]', keywords: ['monorepo', 'pipeline', 'infra'] },
];

function getCredentialFromWindows(target) {
  if (process.platform !== 'win32') return null;
  try {
    const out = execSync(
      `powershell.exe -NoProfile -Command "Import-Module CredentialManager; (Get-StoredCredential -Target '${target}').GetNetworkCredential().Password"`,
      { stdio: ['ignore', 'pipe', 'ignore'] },
    );
    const val = out.toString().trim();
    return val || null;
  } catch {
    return null;
  }
}

function resolveCredentials() {
  const key = process.env.TRELLO_API_KEY || getCredentialFromWindows('claude-trello-api-key');
  const token = process.env.TRELLO_TOKEN || getCredentialFromWindows('claude-trello-token');
  if (!key || !token) {
    console.log(
      'ERRO: TRELLO_API_KEY/TRELLO_TOKEN não encontradas no ambiente nem no Windows Credential Manager.\n' +
        'Configure de uma das formas: (Linux/WSL) export TRELLO_API_KEY=... no ~/.zshrc; ' +
        '(Windows) rode claude-mcp-setup/setup.ps1 do repositório PettiSan/ai-toolkit. Depois rode /trello-report de novo.',
    );
    process.exit(1);
  }
  return { key, token };
}

function pad2(n) {
  return String(n).padStart(2, '0');
}

// Brasília = UTC-3 fixo (sem horário de verão desde 2019).
function brasiliaTodayUTCComponents() {
  const shifted = new Date(Date.now() - 3 * 3600 * 1000);
  return { y: shifted.getUTCFullYear(), m: shifted.getUTCMonth(), d: shifted.getUTCDate(), dow: shifted.getUTCDay() };
}

function utcMidnightBrasilia(y, m, d, daysAgo) {
  return new Date(Date.UTC(y, m, d - daysAgo, 3, 0, 0));
}

function dateLabel(y, m, d, daysAgo, withYear) {
  const dt = new Date(Date.UTC(y, m, d - daysAgo));
  const dd = pad2(dt.getUTCDate());
  const mm = pad2(dt.getUTCMonth() + 1);
  return withYear ? `${dd}/${mm}/${dt.getUTCFullYear()}` : `${dd}/${mm}`;
}

function computeRange() {
  const { y, m, d, dow } = brasiliaTodayUTCComponents();
  const isoDow = dow === 0 ? 7 : dow; // 1=segunda..7=domingo
  const isMonday = isoDow === 1;
  const rangeStart = utcMidnightBrasilia(y, m, d, isMonday ? 3 : 1).toISOString();
  const rangeEnd = utcMidnightBrasilia(y, m, d, 0).toISOString();
  const ontemLabel = isMonday
    ? `${dateLabel(y, m, d, 3, false)} a ${dateLabel(y, m, d, 1, true)}`
    : dateLabel(y, m, d, 1, true);
  return { rangeStart, rangeEnd, ontemLabel };
}

async function fetchJson(url) {
  const res = await fetch(url);
  if (!res.ok) throw new Error(`HTTP ${res.status} em ${url}`);
  return res.json();
}

function matchPrefix(name) {
  for (const p of PREFIXES) {
    if (name.startsWith(p)) return p;
  }
  return null;
}

function guessPrefixByKeyword(text) {
  const lower = text.toLowerCase();
  for (const { prefix, keywords } of PREFIX_KEYWORDS) {
    if (keywords.some((k) => lower.includes(k))) return prefix;
  }
  return null;
}

async function main() {
  const { key, token } = resolveCredentials();
  const { rangeStart, rangeEnd, ontemLabel } = computeRange();

  // 3.1 — member ID (chamada leve, só o id).
  const me = await fetchJson(`https://api.trello.com/1/members/me?fields=id&key=${key}&token=${token}`);
  const myMemberId = me.id;

  // 2.2 — actions do board no período.
  const actions = await fetchJson(
    `https://api.trello.com/1/boards/${BOARD_ID}/actions?since=${rangeStart}&filter=updateCard:idList&limit=1000&key=${key}&token=${token}`,
  );

  // 3.2 — filtra por data+lista, deduplica por card na lista mais avançada. Ainda sem
  // checar dono nem buscar detalhes — mantém o conjunto de candidatos pequeno antes do
  // fetch por card (o mesmo motivo que fez a versão anterior estourar 180+ cards).
  const candidates = {}; // cardId -> { rank, cardName, listId }
  for (const a of actions) {
    if (a.date >= rangeEnd) continue;
    const listAfter = (a.data && a.data.listAfter) || {};
    const target = TARGET_LISTS[listAfter.id];
    if (!target) continue;
    const card = (a.data && a.data.card) || {};
    const prev = candidates[card.id];
    if (!prev || target.rank > prev.rank) {
      candidates[card.id] = { rank: target.rank, cardName: card.name, listId: listAfter.id };
    }
  }

  // 3.3 — só nos candidatos: busca detalhes (inclui desc/labels pro Step 4) e filtra por dono.
  const ambiguous = [];
  const bySection = { 1: [], 2: [], 3: [] };
  for (const cardId of Object.keys(candidates)) {
    const c = candidates[cardId];
    let detail;
    try {
      detail = await fetchJson(
        `https://api.trello.com/1/cards/${cardId}?fields=name,desc,labels,idMembers,shortLink&key=${key}&token=${token}`,
      );
    } catch {
      continue;
    }
    if (!Array.isArray(detail.idMembers) || !detail.idMembers.includes(myMemberId)) continue;

    let prefix = matchPrefix(detail.name);
    if (!prefix) {
      const labelNames = (detail.labels || []).map((l) => l.name).join(' ');
      prefix = guessPrefixByKeyword(`${detail.name} ${detail.desc} ${labelNames}`);
    }
    const entry = { name: detail.name, shortLink: detail.shortLink };
    if (!prefix) {
      ambiguous.push(entry);
      continue;
    }
    bySection[c.rank].push({ ...entry, prefix });
  }

  // Step 5 — Doing.
  const doingCards = await fetchJson(
    `https://api.trello.com/1/lists/${DOING_LIST_ID}/cards?fields=name,shortLink,idMembers&key=${key}&token=${token}`,
  );
  const myDoingCards = doingCards.filter((c) => Array.isArray(c.idMembers) && c.idMembers.includes(myMemberId));

  const lines = [];
  lines.push(`📊 *Relatório de Ontem — ${ontemLabel}*`);
  lines.push('');

  for (const rank of [1, 2, 3]) {
    const items = bySection[rank];
    if (items.length === 0) continue;
    const { section, emoji } = TARGET_LISTS[Object.keys(TARGET_LISTS).find((k) => TARGET_LISTS[k].rank === rank)];
    lines.push(`${emoji} *${section}*`);
    lines.push('');
    const groups = {};
    for (const it of items) {
      (groups[it.prefix] = groups[it.prefix] || []).push(it);
    }
    for (const prefix of Object.keys(groups).sort()) {
      const cards = groups[prefix];
      lines.push(`*${prefix}* (${cards.length} card${cards.length > 1 ? 's' : ''})`);
      for (const c of cards) {
        lines.push(`• ${c.name}`);
        lines.push(`  🔗 https://trello.com/c/${c.shortLink}`);
      }
    }
    lines.push('');
  }

  const total = bySection[1].length + bySection[2].length + bySection[3].length;
  lines.push(`📦 *Total: ${total} cards*`);
  lines.push('');
  lines.push('🔧 *No que estou trabalhando*');
  lines.push('');
  if (myDoingCards.length > 0) {
    for (const c of myDoingCards) {
      lines.push(`• ${c.name}`);
      lines.push(`  🔗 https://trello.com/c/${c.shortLink}`);
    }
  } else {
    lines.push('⚠️ NO_DOING_CARD — não há card em Doing atribuído a você. Pergunte ao usuário antes de gerar o relatório final.');
  }

  if (ambiguous.length > 0) {
    lines.push('');
    lines.push('⚠️ AMBIGUOUS_CARDS — não consegui classificar o(s) card(s) abaixo por nenhum prefixo nem palavra-chave. Pergunte ao usuário qual projeto antes de finalizar:');
    for (const c of ambiguous) {
      lines.push(`• ${c.name} — https://trello.com/c/${c.shortLink}`);
    }
  }

  console.log(lines.join('\n'));
}

main().catch((err) => {
  console.error('ERRO:', err.message);
  process.exit(1);
});
