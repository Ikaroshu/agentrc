---
name: code-review
description: Route one completed implementation diff to the exact native code_reviewer and coordinate its actionable findings without duplicating technical review.
---

# Code Review

Use the configured native `code_reviewer`; never substitute a generic or CLI reviewer. The reviewer owns technical inspection and findings. The implementation owner handles edits and verification; for delegated work, the orchestrator only coordinates recorded evidence and findings.

## Scope and tier

- Review exactly one non-empty completed scope. For implementation, use the full immutable review-base-to-candidate diff after the owner reports a clean committed candidate, successful verification, and no remaining work. For standalone review, use the requested range, commit, or uncommitted tree.
- Select an implementation-review tier from the settled design, outcome, verification, and owner's scoped diff summary without inspecting the diff. For standalone review, use the complete requested scope.
- Use `model="gpt-5.6-sol"` with `reasoning_effort="xhigh"` for bounded established work; use `reasoning_effort="max"` for materially difficult contracts, state, security, irreversibility, blast radius, or unfamiliar architecture. Tell the user the tier and short rationale before dispatch.

## Dispatch

Supply the scope and matching inspection commands:

- range: `git status --short`, `git diff --stat --find-renames <base>...<candidate>`, and `git diff --find-renames <base>...<candidate>`
- commit: `git status --short`, `git show --stat --find-renames <sha>`, and `git show --find-renames <sha>`
- uncommitted: `git status --short`, `git diff --stat HEAD`, `git diff --find-renames HEAD`, and every untracked file named by status

For implementation review, also supply the settled design, outcome, verification, candidate commit and tree, implementation commits, exact successful verification commands and results, and confirmation that no implementation or verification work remains.

Start pass one with a fresh, uniquely named task using `agent_type="code_reviewer"`, `fork_turns="none"`, and the selected exact model and effort. Include a stable review-unit identity and pass number. If the runtime cannot dispatch the exact role, fail loudly; retry transport failures only with that role.

## Resolve

Wait for completion without polling. Do not inspect the implementation diff, reproduce findings, rerun verification, or independently revise the reviewer's technical conclusions. Route definite actionable findings and test gaps to the implementation owner. If the owner disputes a finding with concrete technical evidence, forward that evidence unchanged to the same reviewer with `followup_task` for clarification within pass one. The reviewer may uphold, revise, or withdraw the finding. Route upheld findings for repair; take a material design or contract change to the user.

The scope is one review unit with at most two completed passes. Repairs, replacement reviewers, candidates, and follow-up turns do not reset the count. Clarification remains within pass one. Pass two starts only after a pass-one repair and covers the repair and plausible interactions. Have the owner rerun the required verification and report a new clean candidate before using `followup_task` with the same reviewer for pass two.

When an implementation-review pass is clear, record the accepted commit and tree and ask for merge approval immediately. Do no implementation or verification work between acceptance and that request. A later code or configuration change or failed check invalidates acceptance without resetting the review budget. For a clear standalone review, return the findings without a merge-approval request. If pass two leaves a required repair or material uncertainty, stop without a third review and report the blocker using the global communication guidance.
