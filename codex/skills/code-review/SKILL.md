---
name: code-review
description: Run a Codex-native review of a bounded implementation checkpoint or final git diff. Use the exact code_reviewer role with GPT-5.6 Sol at xhigh effort for non-hard reviews or max effort for hard reviews, then verify actionable findings before changing code.
---

# Code Review

Use the configured `code_reviewer` native subagent. Never substitute a generic agent or a CLI reviewer.

## Scope and tier

- Run from the working tree containing the changes.
- Review exactly one scope: an immutable base-to-candidate range, one commit, or the uncommitted working tree. Confirm that it contains changes.
- State whether the review is an intermediate checkpoint or the final cumulative candidate. Intermediate review prevents defects from propagating and creates no merge approval gate; the final review checks integration across the accepted checkpoint chain.
- In an implementation checkpoint chain, use one immutable commit only for intermediate checkpoint or repair review. The final cumulative review must cover the full recorded immutable review-base-to-candidate range; never use only the last checkpoint commit.
- If the supplied scope combines independently reviewable workstreams and is too large for effective review, report the scope problem rather than silently narrowing it.
- Treat any focus text as additional emphasis, not a narrowing of the review.
- Use `model="gpt-5.6-sol"` with `reasoning_effort="xhigh"` for a bounded established change and `reasoning_effort="max"` when interacting contracts, subtle state, security, irreversibility, broad blast radius, or unfamiliar architecture materially complicate the review.
- Tell the user the tier and short rationale before dispatch.

## Dispatch

Build a concise dynamic task that tells the reviewer what to review and supplies the inspection commands:

- base-to-candidate range: `git status --short`, `git diff --stat --find-renames <base>...<candidate>`, and `git diff --find-renames <base>...<candidate>`
- commit: `git status --short`, `git show --stat --find-renames <sha>`, and `git show --find-renames <sha>`
- uncommitted: `git status --short`, `git diff --stat HEAD`, `git diff --find-renames HEAD`, and every untracked file named by status
- final cumulative candidate: the base-to-candidate commands above using immutable commit IDs, plus `git rev-parse <candidate-sha>^{tree}` and the accepted checkpoint list

For the first review in an implementation, whether intermediate or final, dispatch a fresh task with `agent_type="code_reviewer"`, `fork_turns="none"`, the selected exact model and effort, and a clear unique task name. Retain that task and use `followup_task` for later checkpoint, repair, and final reviews in the same implementation. A standalone review uses a fresh reviewer. If a persistent reviewer becomes unavailable, give its replacement the accepted checkpoint scopes and verified dispositions. If the runtime cannot dispatch the exact role, fail loudly. Ordinary scheduling or transport failures may be retried with the same exact role.

## Verify and follow up

Use blocking waits as needed until the requested reviewer completes. Handle unrelated real events, then resume waiting; do not poll unchanged state or emit time-based heartbeats. Verify every finding against the cited code, callers, tests, contracts, and relevant history; reproduce it when useful. Classify findings as confirmed, rejected with evidence, or needing clarification, and change code only for confirmed findings.

Use focused follow-up review when it materially improves confidence. Reuse the persistent reviewer for the implementation's entire checkpoint chain. Keep the scope, accepted checkpoint identities, and verified dispositions explicit. The main agent decides when the evidence is sufficient and reports residual risk.
