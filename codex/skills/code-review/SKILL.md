---
name: code-review
description: Run a Codex-native review of a git diff before merge. Use the exact code_reviewer role with GPT-5.6 Sol at xhigh effort for non-hard reviews or max effort for hard reviews, then verify actionable findings before changing code.
---

# Code Review

Use the configured `code_reviewer` native subagent. Never substitute a generic agent or a CLI reviewer.

## Scope and tier

- Run from the working tree containing the changes.
- Review exactly one scope: a base branch, one commit, or the uncommitted working tree. Confirm that it contains changes.
- Treat any focus text as additional emphasis, not a narrowing of the review.
- Use `model="gpt-5.6-sol"` with `reasoning_effort="xhigh"` for a bounded established change and `reasoning_effort="max"` when interacting contracts, subtle state, security, irreversibility, broad blast radius, or unfamiliar architecture materially complicate the review.
- Tell the user the tier and short rationale before dispatch.

## Dispatch

Build a concise dynamic task that tells the reviewer what to review and supplies the inspection commands:

- base branch: `git status --short`, `git diff --stat <base>...HEAD`, and `git diff --find-renames <base>...HEAD`
- commit: `git status --short`, `git show --stat --find-renames <sha>`, and `git show --find-renames <sha>`
- uncommitted: `git status --short`, `git diff --stat HEAD`, `git diff --find-renames HEAD`, and every untracked file named by status

Dispatch a fresh task with `agent_type="code_reviewer"`, `fork_turns="none"`, the selected exact model and effort, and a clear unique task name. If the runtime cannot dispatch the exact role, fail loudly. Ordinary scheduling or transport failures may be retried with the same exact role.

## Verify and follow up

Wait for the completed review. Verify every finding against the cited code, callers, tests, contracts, and relevant history; reproduce it when useful. Classify findings as confirmed, rejected with evidence, or needing clarification, and change code only for confirmed findings.

Use focused follow-up review when it materially improves confidence. Reuse the reviewer when practical or dispatch a fresh exact reviewer when the original task is unavailable. Keep the scope and verified dispositions explicit. The main agent decides when the evidence is sufficient and reports residual risk.
