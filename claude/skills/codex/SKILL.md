---
name: codex
description: Hand an approved spec to a Codex session in Herdr for implementation, then to a fresh Codex session for code review. Use for work that needs a spec; do work settled without one directly.
---

# Codex Handoff

Claude owns the user conversation, investigation, design, the spec, and the merge. One Codex session (the implementer) builds and repairs the change; a second, fresh Codex session (the reviewer) reviews it, so the review does not inherit the implementer's assumptions. Both are Herdr terminals that Claude starts as children. They appear under Claude's tab in Herdr's agent list, where the user can open and talk to them; open one in a pane only when the user asks (`herdr-app do agent.focus --terminal <address>`).

Read the `herdr` skill's rules for messages, waiting, and cleanup. Always start Codex with `codex --no-daemon` and no model override; the machine config selects the model.

## Hand off

1. Confirm the user approved the spec at `<project-root>/.plans/specs/<file>.md`. It must state the design, outcome, verification, scope, and the evidence from investigation that Codex needs, so Codex does not have to rediscover or guess intent.
2. From main, create the worktree `<project-root>/.worktrees/<name>` on a new branch and record the review base commit.
3. Write the implementer brief to a scratch file and start the session with it as the first task:

```bash
brief=$(cat "$brief_file")
hc run --bg --name "codex-<name>" --cwd "$worktree" codex --no-daemon "$brief"
```

Check `first_message.sent`; if false, read the screen and resolve readiness before sending the brief.

The implementer brief contains:

- the sender (Claude at `$HC_TERMINAL_ID`), the absolute spec path, the worktree, and the review base;
- the assignment: read the governing instructions, spec, and relevant code first; if the spec is materially ambiguous, wrong, or cannot meet its verification, report questions and stop before editing; otherwise implement, run the spec's and repository-required verification, and leave a clean committed candidate on the branch;
- limits: work only in the worktree, start no agents, and do not merge or push;
- the report route: `hc send <claude address> "<report>"`; for a report longer than a few lines, write `/tmp/codex-<name>-report.md` and send its path. The report gives the candidate commit, clean status, changed paths, exact verification commands and results, deviations from the spec, and remaining risks.

End the turn after the launch. Codex reports arrive as new input tagged `<hc from="...">`; Herdr also notifies Claude if the session is blocked, errors, or exits.

## Questions and blockers

Answer questions within the approved spec directly. Take a material design or scope change to the user, update the spec, and send the decision to the same implementer. If the user says they talked to Codex directly, read its screen (`hc read`) before continuing.

## Review

When the implementer reports a clean candidate with passing verification, start the reviewer in the same worktree:

```bash
hc run --bg --name "codex-<name>-review" --cwd "$worktree" codex --no-daemon "$review_brief"
```

The reviewer brief contains the sender, spec path, review base, candidate commit, and these instructions. Leave out the implementer's report and reasoning, so the reviewer judges the code rather than the implementer's account of it.

- Review `git diff --find-renames <base>...<candidate>` against the spec, read-only. Rerun the spec's verification, and run focused checks or reproductions when useful; do not edit files or start agents.
- Report only defects the change introduces: correctness or interface regressions, security or data-loss risks, unsafe partial failure, important missing verification, and over- or under-engineering that materially affects maintenance. Assume callers follow documented contracts. Skip style preferences and unrelated behavior; do not manufacture findings.
- Give each finding a severity, file and line, evidence, impact, and the smallest fix. Report with sections `Findings`, `Test gaps`, and `Residual risk` (write "None." when empty) through the same route as the implementer.

Claude may read the diff to explain it to the user. Send findings to the implementer for repair. If the implementer disputes a finding with concrete evidence, forward that evidence to the reviewer and accept its revised answer. After repair and re-verification, send the reviewer a second pass covering the repair and its plausible interactions. Stop after two review passes: if a required repair or material uncertainty remains, report it to the user instead of starting a third.

## Finish

When a review pass is clear, ask the user for merge approval as a decision request. A later change or failed check invalidates that approval. After the merge, `hc kill` and `hc rm` both Codex sessions.

## Decision requests

Use this layout for every decision this workflow takes to the user, including spec approval, design blockers, and merge approval, and end the turn after it:

```text
**Found** — the change, verification, and residual risk, or the blocker and its evidence.
**Recommend** — one next action and why; the main alternative, if any.
**Need from you** — what the user needs to decide, phrased as the decision requires; open questions, several questions, and tradeoffs are fine.
```
