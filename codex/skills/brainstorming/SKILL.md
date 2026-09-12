---
name: brainstorming
description: Settle material goal or design uncertainty and write a durable implementation spec when needed. Skip requests already settled enough to implement without a spec.
---

# Brainstorming

Turn material uncertainty into an approved implementation contract. If the request is already settled and needs no spec, proceed to `implement`.

Inspect relevant code, docs, history, and repository rules without editing implementation files or creating a worktree. Keep the user in consequential decisions; resolve other uncertainty from context or safe assumptions. Exclude unrelated improvements.

## Settle the contract

Establish the current behavior and problem before choosing a design. When intent is materially uncertain, settle the goal and boundary with the user first; do not reconfirm clear intent. Ask one consequential question at a time, explain the current view, and invite correction.

The approved contract must define:

- **Design:** responsibilities, interfaces, data flow, constraints, and material failure behavior. Compare genuine alternatives when the choice changes the outcome or cost, recommending the simplest reliable option.
- **Outcome:** observable success, active requirements, scope, and non-goals.
- **Verification:** behavioral evidence and exact checks that demonstrate delivery. Leave questions that working code can safely settle to implementation.

Present the contract proportionately and get explicit approval, resolving contradictions, missing requirements, ambiguity, or scope growth inline. Existing approval of the same contract suffices.

## Write the spec

When a durable spec is needed, save the approved contract to `<project-root>/.plans/specs/<YYYYMMDD>_<short_title>.md` from main and do not commit it. Organize it around **Design**, **Outcome**, and **Verification**, with only the context needed to understand them. Describe what must be true without prescribing implementation phases, task choreography, commit boundaries, or code structure that the design does not require.

Invoke `adversarial-doc-review` on a written spec. After confirmed findings are resolved, ask for implementation approval. When no spec is needed, proceed to the `implement` skill after the user approves the settled contract; skipping a spec does not imply main-agent implementation.
