---
name: code-review
description: Review a bounded checkpoint or final Git diff with the exact native code_reviewer role, then verify actionable findings before changing code.
---

# Code Review

Use the configured native `code_reviewer`; never substitute a generic or CLI reviewer.

## Scope and tier

- From the changed worktree, review exactly one non-empty scope: an immutable base-to-candidate range, one commit, or the uncommitted tree. State whether it is an intermediate checkpoint or final cumulative candidate. Intermediate review creates no merge approval gate.
- Use one immutable commit for checkpoint or repair review. Final review must cover the full recorded immutable review-base-to-candidate range, never only the last checkpoint. Report an oversized multi-workstream scope instead of narrowing it. Focus text adds emphasis only.
- Dispatch final cumulative review only after all implementation and repair work is complete, the worktree is clean, complete verification has passed for the exact candidate commit and tree, and no unresolved work remains. It is the last technical gate before requesting merge approval.
- Findings require a plausible contract-respecting path and a current repair worth its cost. Competent callers follow documented contracts; misuse that fails loudly before harm is neither a finding nor residual risk. Preserve disproportionate non-required handling only as a concise residual limitation or separately authorized issue. Never downgrade plausible security, data-loss, irreversible, or active-contract failures because repair is large.
- For an implementation review chain, use the tier selected before implementation from the approved plan and the full implementation's overall complexity, including every checkpoint and cumulative integration. Keep that tier for the persistent reviewer; never choose it from the first checkpoint or recalculate it per review unit. For a standalone review, select the tier from the complete requested scope.
- Use `model="gpt-5.6-sol"` with `reasoning_effort="xhigh"` for bounded established overall work; use `reasoning_effort="max"` for overall work with materially difficult contracts, state, security, irreversibility, blast radius, or unfamiliar architecture.
- Tell the user the tier and short rationale before dispatch.

## Dispatch

Supply the exact scope and matching inspection commands:

- base-to-candidate range: `git status --short`, `git diff --stat --find-renames <base>...<candidate>`, and `git diff --find-renames <base>...<candidate>`
- commit: `git status --short`, `git show --stat --find-renames <sha>`, and `git show --find-renames <sha>`
- uncommitted: `git status --short`, `git diff --stat HEAD`, `git diff --find-renames HEAD`, and every untracked file named by status
- final: immutable base-to-candidate commands, accepted checkpoints, `git rev-parse <candidate-sha>^{tree}`, the exact successful complete-verification command and result for that commit and tree, and an explicit statement that no implementation, repair, or check-settling work remains

Start each implementation or standalone review with a fresh, uniquely named task using `agent_type="code_reviewer"`, `fork_turns="none"`, and the selected exact model and effort. Supply a stable review-unit identity and pass number. Retain the implementation reviewer and use `followup_task` for later checkpoints, repairs, and final review; each new checkpoint or cumulative final unit starts at pass one, while a repair or blocker follow-up is pass two for its existing unit. If replaced, give the fresh exact reviewer all accepted scopes, dispositions, unit identities, and pass counts. Fail loudly if the exact role is unavailable; retry transport failures only with that role.

## Verify and follow up

Wait until the reviewer completes; handle unrelated events and resume without polling or heartbeats. Verify findings against code, callers, tests, contracts, and history, reproducing when useful. Classify each as confirmed required repair, accepted deferral, rejected with evidence, or needing clarification. Change code only for confirmed repairs; keep deferrals brief or open a separately authorized issue without designing it.

Treat each requested standalone scope, incremental checkpoint, and cumulative final candidate as its own review unit with a hard budget of two completed review passes, including the initial review. Repairs, replacement reviewers, new candidate commits, and follow-up turns do not reset that unit's count. Pass one is the default; advance immediately if it is clear, and use pass two only for a code-changing repair or unresolved blocker, checking the repair and plausible interactions without reopening unchanged scope.

For a cumulative pass-one repair, return to implementation and complete verification on the repaired clean candidate before pass two. A clear cumulative pass leads immediately to the merge-approval request; schedule no implementation, repair, or verification work between acceptance and that request. A later code or configuration change or failed check invalidates acceptance and returns the candidate to settlement without resetting the review budget.

If pass two is clear, advance to implementation or merge approval as applicable. If a confirmed required repair or material uncertainty remains, stop the review workflow and do not dispatch a third review or continue the repair loop. Explain the blocker in ELI5 terms with the relevant context, evidence, impact, what the two passes tried, what remains unclear, and the user decision or external change needed. Keep review counts, identities, and dispositions explicit, and report residual risk.
