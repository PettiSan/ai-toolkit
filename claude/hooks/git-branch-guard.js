#!/usr/bin/env node
/**
 * git-branch-guard — PreToolUse hook for Claude Code (Windows Desktop).
 *
 * Auto-allows `git commit` / `git push` on normal working branches, but forces a
 * permission prompt ("ask") when the target branch is a protected integration /
 * production branch. Everything that is NOT protected passes through allowed.
 *
 * Protected set (exact match, case-insensitive):
 *   main · master · develop · homolog · trunk
 *
 * Why a hook instead of a whitelist rule: `git commit` never names the branch in
 * the command text (it commits to whatever is checked out), so a static allow/deny
 * rule cannot distinguish "commit on develop" from "commit on a feature branch".
 * This hook resolves the current branch at call time and decides accordingly.
 *
 * Source of truth: ai-toolkit/claude/hooks/git-branch-guard.js  (versioned)
 * Live copy:       C:/Users/filip/.claude/hooks/git-branch-guard.js  (what Desktop runs)
 * Keep the two in sync — the Windows ~/.claude is a manual copy, not a symlink.
 */
"use strict";

const { execSync } = require("child_process");
const fs = require("fs");

const PROTECTED = new Set(["main", "master", "develop", "homolog", "trunk"]);

function emit(decision, reason) {
  process.stdout.write(
    JSON.stringify({
      hookSpecificOutput: {
        hookEventName: "PreToolUse",
        permissionDecision: decision, // "allow" | "ask"
        permissionDecisionReason: reason,
      },
    })
  );
  process.exit(0);
}

// Stay silent: no decision, let the normal permission flow handle it.
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
const subMatch = cmd.match(
  /\bgit\b((?:\s+(?:-C\s+\S+|-c\s+\S+|--[^\s]+|-[A-Za-z]))*)\s+([a-z][a-z-]*)/
);
const sub = subMatch ? subMatch[2] : null;

// Only commit/push are gated. Anything else is none of this hook's business.
if (sub !== "commit" && sub !== "push") passthrough();

// Extract the repo path from -C <path> (paths in this setup have no spaces).
const cdir = (cmd.match(/-C\s+("([^"]+)"|'([^']+)'|(\S+))/) || [])
  .slice(2)
  .find(Boolean);

const usesWsl = /\bwsl(\.exe)?\b/.test(cmd);
const gitPrefix = usesWsl ? "wsl git" : "git";
const cArg = cdir ? ` -C "${cdir}"` : "";

// For push, an explicit protected ref in the command is enough to gate immediately.
if (sub === "push") {
  const tokens = cmd.split(/\s+/);
  if (tokens.some((t) => PROTECTED.has(t.toLowerCase()))) {
    emit("ask", 'Push nomeia uma branch protegida — requer tua aprovação.');
  }
}

// Resolve the current branch of the target repo.
let branch;
try {
  branch = execSync(`${gitPrefix}${cArg} rev-parse --abbrev-ref HEAD`, {
    encoding: "utf8",
    stdio: ["ignore", "pipe", "ignore"],
    timeout: 10000,
  }).trim();
} catch {
  emit("ask", "Não consegui determinar a branch atual — aprovação requerida por segurança.");
}

if (!branch || branch === "HEAD") {
  emit("ask", "Branch indeterminada (detached HEAD?) — aprovação requerida por segurança.");
}

if (PROTECTED.has(branch.toLowerCase())) {
  emit("ask", `${sub} na branch protegida "${branch}" — requer tua aprovação.`);
}

emit("allow", `${sub} na branch "${branch}" (não protegida) — liberado.`);
