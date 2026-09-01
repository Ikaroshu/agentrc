---
name: code-review
description: Route one completed implementation diff to the exact native code_reviewer and coordinate its actionable findings without duplicating technical review.
---

# Code Review

Use the configured native `code_reviewer`; never substitute a generic or CLI reviewer.

## Scope and tier

- Review exactly one non-empty completed scope. For the implementation workflow, use the full immutable review-base-to-candidate diff after the implementer reports that implementation is complete, the worktree is clean, and the settled and repository-required verification has passed on that candidate. For a standalone review, use the requested immutable range, commit, or uncommitted tree.
- Findings require a plausible contract-respecting path and a current repair worth its cost. Competent callers follow documented contracts; misuse that fails loudly before harm is neither a finding nor residual risk. Preserve disproportionate non-required handling only as a concise residual limitation or separately authorized issue. Never downgrade plausible security, data-loss, irreversible, or active-contract failures because repair is large.
- For an implementation review, select the tier from the settled design, outcome, verification, and implementer's scoped diff summary without inspecting the implementation diff. For a standalone review, select it from the complete requested scope. Use `model="gpt-5.6-sol"` with `reasoning_effort="xhigh"` for bounded established work; use `reasoning_effort="max"` for materially difficult contracts, state, security, irreversibility, blast radius, or unfamiliar architecture.
- Tell the user the tier and short rationale before dispatch.

## Dispatch

Supply the exact scope and matching inspection commands:

- range: `git status --short`, `git diff --stat --find-renames <base>...<candidate>`, and `git diff --find-renames <base>...<candidate>`
- commit: `git status --short`, `git show --stat --find-renames <sha>`, and `git show --find-renames <sha>`
- uncommitted: `git status --short`, `git diff --stat HEAD`, `git diff --find-renames HEAD`, and every untracked file named by status

For an implementation review, also supply the settled design, outcome, verification, candidate commit and tree, implementation commits, exact successful verification commands and results, and an explicit statement that no implementation or verification work remains.

Start pass one with a fresh, uniquely named task using `agent_type="code_reviewer"`, `fork_turns="none"`, and the selected exact model and effort. Supply a stable review-unit identity and pass number. If the runtime cannot dispatch the exact role, fail loudly; retry transport failures only with that role.

## Resolve

Wait for completion without polling. The reviewer owns independent inspection of code, callers, tests, contracts, and history, any useful focused checks or reproductions, and the technical correctness and actionability of its findings. The orchestrator does not inspect the implementation diff, reproduce reviewer findings, rerun verification, or independently accept, reject, or refine the technical conclusions. Route each definite actionable finding or test gap to the implementation owner. If the owner disputes it with concrete technical evidence, forward that evidence unchanged to the same reviewer with `followup_task` for clarification and reconsideration within pass one before any repair. The reviewer remains the technical adjudicator and may uphold, revise, or withdraw the finding. Route an upheld finding to the owner for repair. If the reviewer concludes that resolution requires a material design, spec, or contract change, take that ambiguity to the user.

The requested scope is one review unit with a hard budget of two completed passes, including the initial pass. Repairs, replacement reviewers, new candidate commits, and follow-up turns do not reset the count. A clarification or reconsideration follow-up remains within pass one and does not consume or become pass two. Pass two starts only after an actual pass-one repair and is repair-only. Require the implementer to rerun and report the settled and repository-required verification on the repaired clean candidate, record that candidate and evidence, then use `followup_task` with the same reviewer for pass two over the repair and plausible interactions. Do not reopen unchanged scope merely to seek new hypothetical cases.

If a pass is clear, advance immediately. For the implementation workflow, record the accepted commit and tree and ask for merge approval immediately; schedule no implementation, repair, or verification work between acceptance and that request. Any later code or configuration change or failed check invalidates acceptance and requires a new settled candidate without resetting the review budget.

If pass two leaves a confirmed required repair or material uncertainty, stop, dispatch no third pass, and explain the blocker in ELI5 terms with the relevant context, evidence, impact, what the two passes tried, what remains unclear, and the user decision or external change needed. Keep review count, identity, dispositions, and residual risk explicit.
