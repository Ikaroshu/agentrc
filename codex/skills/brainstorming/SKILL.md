---
name: brainstorming
description: Settle an uncertain user goal first, then the design, outcome, and verification, and write an implementation-ready spec when one is needed. Do not use when the request is already settled enough for implementation and no spec is needed.
---

# Brainstorming

Turn material user uncertainty into an approved implementation contract, writing a spec when the contract needs to be durable. Brainstorming owns both how the contract is settled and what any spec contains.

**Announce at start:** "Using the brainstorming skill to settle the goal if needed, then the design, outcome, and verification."

## Boundaries

- Use this skill when the user's goal is materially uncertain or implementation needs a spec. If neither is true, proceed to the `implement` skill, which chooses main-agent or implementer ownership based on the work's complexity.
- Inspect relevant code, docs, history, and repository rules, but edit no implementation files and create no worktree.
- Keep the user in the reasoning. Ask one consequential question at a time, explain the current view, and invite correction. Resolve uncertainty from context or safe assumptions when it does not need a user choice.
- Exclude unrelated improvements. Keep implementation sequencing and commit structure out of the spec.

## Settle the contract

1. Understand the current behavior and why the change may be needed.
2. When the user's intent is materially uncertain, settle the **goal** with the user first: the problem to solve, why it matters, and the desired boundary. If intent is clear, do not reconfirm it.
3. Settle the **design**: responsibilities, interfaces, data flow, constraints, and material failure behavior. Compare genuine alternatives when the choice changes the outcome or cost, leading with the simplest reliable recommendation.
4. Settle the **outcome**: observable success, active requirements, scope, and non-goals.
5. Settle the **verification**: the behavioral evidence and exact checks that will show the outcome and design were delivered. Leave questions that require working code to implementation when focused execution can answer them safely.
6. Present the complete contract proportionately, get explicit approval, and resolve contradictions, missing requirements, ambiguity, or scope growth inline.

## Write the spec

When a durable spec is needed, save the approved contract to `<project-root>/.plans/specs/<YYYYMMDD>_<short_title>.md` from main and do not commit it. Organize it around:

- **Design**
- **Outcome**
- **Verification**

Include only context needed to understand those sections. Describe what must be true without prescribing implementation phases, task choreography, commit boundaries, or code structure that the design does not require.

Invoke `adversarial-doc-review` on a written spec. After confirmed findings are resolved, ask for implementation approval. When no spec is needed, proceed to the `implement` skill after the user approves the settled contract; skipping a spec does not imply main-agent implementation.
