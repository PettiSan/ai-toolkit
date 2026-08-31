#!/usr/bin/env node
/**
 * ssh-agent-guard — PreToolUse hook for Claude Code (Windows Desktop).
 *
 * Blocks git commands that talk to a remote when the WSL ssh-agent has no key
 * loaded, and says exactly how to fix it.
 *
 * Why: `id_rsa` is passphrase-protected and only reaches the agent from an
 * INTERACTIVE shell. After a reboot — or whenever an agent is started without a
 * successful `ssh-add` — the agent is alive but empty (`ssh-add -l` prints "The
 * agent has no identities"). Every network git call then hangs on a passphrase
 * prompt that has no terminal to read from, and dies on the tool timeout two
 * minutes later with no output at all. Measured on 2026-08-31: a `git push`
 * burned the full 120s and printed nothing.
 *
 * This turns those two silent minutes into an instant, actionable message.
 * It does NOT remove the need to unlock the key — only a passphrase-less key
 * would do that, which is a security decision, not a tooling one.
 *
 * Applies to the Windows profile too: `core.sshCommand = wsl ssh` means Windows
 * git delegates to the very same agent.
 *
 * Local-only git (status/log/diff/commit/add/...) is never gated — the check
 * only runs for subcommands that actually reach the network.
 *
 * Source of truth: ai-toolkit/claude/hooks/ssh-agent-guard.js  (versioned)
 * Live copy:       C:/Users/filip/.claude/hooks/ssh-agent-guard.js  (what Desktop runs)
 * Keep the two in sync — the Windows ~/.claude is a manual copy, not a symlink.
 */
"use strict";

const { execFileSync } = require("child_process");
const fs = require("fs");

// git subcommands that open a connection to the remote.
const NETWORK_SUBCOMMANDS = new Set([
  "push",
  "fetch",
  "pull",
  "clone",
  "ls-remote",
]);

function emit(decision, reason) {
  process.stdout.write(
    JSON.stringify({
      hookSpecificOutput: {
        hookEventName: "PreToolUse",
        permissionDecision: decision, // "deny" here; "allow"/"ask" unused
        permissionDecisionReason: reason,
      },
    })
  );
  process.exit(0);
}

// Stay silent: no decision, let the normal permission flow (and the other
// hooks, e.g. git-branch-guard) handle it.
function passthrough() {
  process.exit(0);
}

let input;
try {
  input = JSON.parse(fs.readFileSync(0, "utf8"));
} catch {
  passthrough();
}

const cmd = input && input.tool_input && input.tool_input.command;
if (typeof cmd !== "string" || !cmd.trim()) passthrough();

// Resolve the git subcommand, skipping global options (-C <val>, -c <val>, --foo, -x).
// Same parser as git-branch-guard, deliberately.
const subMatch = cmd.match(
  /\bgit\b((?:\s+(?:-C\s+\S+|-c\s+\S+|--[^\s]+|-[A-Za-z]))*)\s+([a-z][a-z-]*)/
);
const sub = subMatch ? subMatch[2] : null;

if (!sub || !NETWORK_SUBCOMMANDS.has(sub)) passthrough();

// A push/fetch over an explicit HTTPS URL does not use the agent at all.
if (/https:\/\//.test(cmd)) passthrough();

// Ask the WSL agent what it holds.
//   exit 0 -> at least one identity
//   exit 1 -> agent reachable, no identities
//   exit 2 -> cannot connect to an agent
let status;
try {
  execFileSync("wsl", ["ssh-add", "-l"], {
    stdio: ["ignore", "ignore", "ignore"],
    timeout: 10000,
  });
  status = 0;
} catch (err) {
  // If WSL itself is unavailable, this is not our problem to report.
  if (err && err.code === "ENOENT") passthrough();
  status = typeof err.status === "number" ? err.status : null;
  if (status === null) passthrough(); // timeout or unknown failure: do not block
}

if (status === 0) passthrough();

const detail =
  status === 2
    ? "não há ssh-agent acessível no WSL"
    : "o ssh-agent do WSL está vazio (nenhuma identidade carregada)";

emit(
  "deny",
  `git ${sub} vai pendurar: ${detail}. ` +
    "A id_rsa tem passphrase e só entra no agent a partir de um shell interativo — " +
    "tipicamente porque a máquina foi reiniciada e nenhum terminal WSL foi aberto ainda. " +
    "Abra um terminal WSL e rode `ssh-add ~/.ssh/id_rsa` (um `git pull` interativo também " +
    "resolve, via AddKeysToAgent), depois peça de novo. " +
    "Não tente destravar pela tool Bash: a passphrase precisa de stdin de terminal e o " +
    "comando vai travar até o timeout."
);
