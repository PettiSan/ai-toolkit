---
name: handoff
description: Compact the current conversation into a handoff document for another agent to pick up.
argument-hint: "What will the next session be used for?"
---

<!--
Vendored from mattpocock/skills (MIT) — skills/productivity/handoff.
Frozen copy: not synced from upstream. Local adaptation = the "next-session model"
paragraph below; everything else is the upstream text as of the June 2026 import.
-->

Write a handoff document summarising the current conversation so a fresh agent can continue the work. Save to the temporary directory of the user's OS - not the current workspace.

Include a "suggested skills" section in the document, which suggests skills that the agent should invoke.

End the document with a **next-session model** line: state which model the next session should run in and why — Opus when the next step is decision or planning work, Sonnet when it is execution. Match the model to the task, not to convenience.

Do not duplicate content already captured in other artifacts (PRDs, plans, ADRs, issues, commits, diffs). Reference them by path or URL instead.

Redact any sensitive information, such as API keys, passwords, or personally identifiable information.

If the user passed arguments, treat them as a description of what the next session will focus on and tailor the doc accordingly.
