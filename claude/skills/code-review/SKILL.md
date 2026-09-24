---
name: code-review
description: Review a completed implementation or requested code scope with the native code-reviewer subagent and coordinate findings.
---

# Code Review

Use the configured native `code-reviewer` subagent; never substitute a generic or CLI reviewer. The reviewer owns technical inspection and findings. The implementation owner handles edits and verification; for delegated work, the orchestrator only coordinates recorded evidence and findings.

## Scope

- Review exactly one non-empty completed scope. For implementation, use the full immutable review-base-to-candidate diff after the owner reports a clean committed candidate, successful verification, and no remaining work. For standalone review, use the requested range, commit, or uncommitted tree.
- Do not inspect the implementation diff before dispatch. The subagent definition sets its model and effort; do not override them per dispatch.

## Dispatch

Supply the scope and matching inspection commands:

- range: `git status --short`, `git diff --stat --find-renames <base>...<candidate>`, and `git diff --find-renames <base>...<candidate>`
- commit: `git status --short`, `git show --stat --find-renames <sha>`, and `git show --find-renames <sha>`
- uncommitted: `git status --short`, `git diff --stat HEAD`, `git diff --find-renames HEAD`, and every untracked file named by status

For implementation review, also supply the settled design, outcome, verification, candidate commit and tree, implementation commits, exact successful verification commands and results, and confirmation that no implementation or verification work remains.

Start pass one with a fresh subagent using the Agent tool with `subagent_type="code-reviewer"` and a short description naming the review unit. Include a stable review-unit identity and pass number. If the runtime cannot dispatch the exact subagent, fail loudly; retry transport failures only with that subagent.

## Resolve

Wait for completion without polling. Do not inspect the implementation diff, reproduce findings, rerun verification, or independently revise the reviewer's technical conclusions. Route definite actionable findings and test gaps to the implementation owner. If the owner disputes a finding with concrete technical evidence, forward that evidence unchanged to the same reviewer with SendMessage for clarification within pass one. The reviewer may uphold, revise, or withdraw the finding. Route upheld findings for repair; take a material design or contract change to the user.

The scope is one review unit with at most two completed passes. Repairs, replacement reviewers, candidates, and follow-up turns do not reset the count. Clarification remains within pass one. Pass two starts only after a pass-one repair and covers the repair and plausible interactions. Have the owner rerun the required verification and report a new clean candidate before using SendMessage with the same reviewer for pass two.

When an implementation-review pass is clear, record the accepted commit and tree and ask for merge approval immediately. Do no implementation or verification work between acceptance and that request. A later code or configuration change or failed check invalidates acceptance without resetting the review budget. For a clear standalone review, return the findings without a merge-approval request. If pass two leaves a required repair or material uncertainty, stop without a third review and report the context, evidence, impact, what both passes tried, unresolved questions, and the user decision or external change needed.
