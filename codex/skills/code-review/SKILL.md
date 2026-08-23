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
- First distinguish a failure reachable during contract-respecting execution from invalid user or caller behavior. In Shu's code repositories, assume competent users and callers follow the documented contract. When invalid invocation, contradictory input, manual state tampering, or a bypassed workflow naturally fails loudly before harmful side effects, it is not a finding, residual risk, or follow-up issue. Untrusted or public inputs and user-triggered security, data-loss, or irreversible risks remain real boundaries.
- Judge each proposed edge-case fix against the primary functional outcome, active contracts, a plausible execution path, likelihood, impact, and implementation cost. Require a current repair only when its benefit justifies that cost. If correct handling would add disproportionate code or logic and no active requirement or plausible material failure requires it now, preserve it as a residual limitation with a concrete revisit condition or, when separately authorized, a follow-up issue; do not send it to implementation as a required repair. This proportionality rule never downgrades a plausible security, data-loss, irreversible, or active-contract failure merely because its repair is large.
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

Use blocking waits as needed until the requested reviewer completes. Handle unrelated real events, then resume waiting; do not poll unchanged state or emit time-based heartbeats. Verify every finding against the cited code, callers, tests, contracts, and relevant history; reproduce it when useful. Classify findings as confirmed required repairs, accepted non-blocking deferrals, rejected with evidence, or needing clarification. Change code only for confirmed required repairs; record an accepted deferral briefly in residual risk or, when separately authorized, a follow-up issue without designing its implementation.

One complete review of each requested immutable checkpoint or final candidate is the default. Use focused follow-up review only for a code-changing confirmed repair or an unresolved blocking concern. A repair review checks the repair and its plausible interactions; it is not a new opportunity to reopen unchanged accepted scope or add hypothetical cases. Reuse the persistent reviewer for the implementation's entire checkpoint chain. Keep the scope, accepted checkpoint identities, and verified dispositions explicit. Once no confirmed required repairs remain, report residual risk and move to the appropriate implementation or merge approval gate.
