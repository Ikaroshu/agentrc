---
name: planning
description: Use after the user chooses a written implementation plan for a multi-step, cross-cutting, or high-risk change whose requirements and design decisions are settled. May follow brainstorming or start directly from clear requirements. Explore the repository, map files and interfaces, split work into independently verifiable phases, and save an executable plan under .plans/plans/ before implementation.
---

# Planning

Turn settled requirements into a plan that a fresh task owner can execute without rediscovering decisions or inventing missing interfaces.

**Announce at start:** "Using the planning skill to write an executable implementation plan."

## Principles

- **No implementation yet.** Inspect freely, but do not edit implementation files or create a worktree.
- **Resolve design first.** If material requirements or design choices remain open, stop and recommend `brainstorming` rather than guessing.
- **Plan outcomes, not ceremony.** Give each phase an independently verifiable deliverable and enough detail to execute it, without forcing artificial micro-steps or test-first sequencing.
- **Follow the repository.** Preserve established structure and patterns unless a targeted change is necessary for the agreed goal.

## Steps

1. **Read the source of truth.** Read the approved spec when one exists, the user's settled requirements, relevant repository instructions, code, tests, and recent history.
2. **Check scope.** If the work spans independent subsystems, propose separate plans. Each plan should leave the repository in a working, testable state.
3. **Map the files and interfaces.** Identify files to create or modify, their responsibilities, and the contracts passed between phases. Co-locate files that change together; do not introduce unrelated restructuring.
4. **Define phases.** Make each phase a coherent deliverable worth a fresh task owner's implementation and review. Fold setup, scaffolding, documentation, and configuration into the phase that needs them.
5. **Write the plan.** Save it as `<project-root>/.plans/plans/<YYYYMMDD>_<short_title>.md` from the main repo cwd on `main`, not a worktree. **Do not commit it.**
6. **Self-review.** Check requirement coverage, placeholders, interface and naming consistency across phases, scope, and verification completeness. Fix gaps before handoff.
7. **Hand off.** Invoke `adversarial-doc-review` on the plan and any spec, then address verified findings before the user approval gate for implementation.

## Plan structure

Write for a fresh task owner with zero conversation context:

- **Goal** — one sentence describing the completed outcome.
- **Context** — only the repository facts and prior decisions needed to execute correctly.
- **Architecture** — the chosen approach and important boundaries; do not reopen settled design.
- **Global constraints** — exact project-wide requirements that every phase must preserve.
- **Phases** — ordered, independently verifiable deliverables.
- **Out of scope** — explicit fences against nearby work.
- **Risks** — genuine residual risks, not unresolved design questions.

For each phase include:

- **Outcome** — the observable result.
- **Files** — exact paths to create, modify, and test; name relevant symbols when known.
- **Interfaces** — inputs or contracts consumed from earlier phases and public outputs later phases rely on, when applicable.
- **Work** — concrete implementation steps with enough detail to avoid rediscovery, while preserving task-owner judgment.
- **Verification** — exact commands or manual checks and the expected result. Recommend test-first or implementation-first only when the choice materially helps execution.

Do not leave `TBD`, `TODO`, vague "handle edge cases" instructions, unnamed tests, or references to undefined symbols. Do not duplicate complete implementation code in the plan unless an exact snippet is itself a required contract.
