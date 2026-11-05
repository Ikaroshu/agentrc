---
name: brainstorming
description: Settle material goal or design uncertainty and write the implementation spec that Codex builds from. Skip requests already settled enough to do without a spec.
---

# Brainstorming

Turn material uncertainty into an approved spec for the `codex` handoff. If the request is already settled and needs no spec, do it directly.

Inspect relevant code, docs, history, and repository rules without editing implementation files or creating a worktree. Keep the user in consequential decisions; resolve other uncertainty from context or safe assumptions. Exclude unrelated improvements.

## Settle the contract

Establish the current behavior and problem before choosing a design. When intent is materially uncertain, settle the goal and boundary with the user first; do not reconfirm clear intent. Ask one consequential question at a time, explain the current view, and invite correction.

The approved contract must define:

- **Design:** responsibilities, interfaces, data flow, constraints, and material failure behavior. Compare genuine alternatives when the choice changes the outcome or cost, recommending the simplest reliable option.
- **Outcome:** observable success, active requirements, scope, and non-goals.
- **Verification:** behavioral evidence and exact checks that demonstrate delivery. Leave questions that working code can safely settle to implementation.

Present the contract proportionately and get explicit approval, resolving contradictions, missing requirements, ambiguity, or scope growth inline. Existing approval of the same contract suffices.

## Write the spec

Save the approved contract to `<project-root>/.plans/specs/<YYYYMMDD>_<short_title>.md` from main and do not commit it. Organize it around **Design**, **Outcome**, and **Verification**, with only the context needed to understand them. Describe what must be true without prescribing implementation phases, task choreography, commit boundaries, or code structure that the design does not require. Codex has not seen this conversation: include the investigation evidence, file paths, and constraints it needs to implement without guessing intent.

Ask the user to approve the written spec as a decision request in the `codex` skill's layout, then proceed to the `codex` skill. Codex checks the spec against the repository before editing and reports material gaps.
