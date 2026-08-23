---
name: planning
description: Use after the user chooses a written implementation plan for a settled change whose implementation complexity warrants multiple coherent phases. Do not use merely because impact or risk is high; use brainstorming first when material requirements or design uncertainty remains. Explore the repository, map files and interfaces, and save an executable plan under .plans/plans/ before implementation.
---

# Planning

Turn settled requirements into a plan that a fresh task owner can execute without rediscovering decisions or inventing missing interfaces.

**Announce at start:** "Using the planning skill to write an executable implementation plan."

## Principles

- **No implementation yet.** Inspect freely, but do not edit implementation files or create a worktree.
- **Complexity justifies phases.** Use planning only when implementation complexity benefits from multiple coherent phases, such as several dependent interfaces or workstreams. A large blast radius or high consequence alone is not a reason to create a phase-based plan; scale verification and review to impact instead.
- **Resolve design first.** If material requirements or design choices remain open, stop and invoke `brainstorming` rather than guessing, especially when the work is high-impact.
- **Plan outcomes, not ceremony.** Give each phase an independently verifiable deliverable and enough detail to execute it, without forcing artificial micro-steps or test-first sequencing.
- **Reach runnable evidence early.** Center the plan on the smallest implementation that delivers the primary functional outcome and can be exercised in code. Do not try to settle through prose behavior that can only be learned by implementing and running focused checks.
- **Keep scope reviewable.** Keep each plan to one coherent review unit. Split independently landable workstreams or a combined change too large for effective review. Mention deferred or out-of-scope work only enough to define the boundary, dependencies, and consequences; do not design its implementation, phases, interfaces, commands, or verification.
- **Judge edge cases proportionally.** Include an edge case only when it is an active requirement or a plausible material failure whose impact justifies the handling cost. If handling would add disproportionate code, logic, or plan length, record the current limitation and concrete revisit condition briefly in out of scope or, when separately authorized, a follow-up issue. Do not make deferred handling a prerequisite for the primary path.
- **Separate execution failures from misuse.** First determine whether contract-respecting execution can reach the edge case. In Shu's code repositories, assume competent users and callers follow the documented contract. Invalid invocation, contradictory input, manual state tampering, or a bypassed workflow needs no planned handling, limitation, or follow-up when it naturally fails loudly before harmful side effects. Treat genuinely untrusted or public inputs and user-triggered security, data-loss, or irreversible risks as real boundaries.
- **Follow the repository.** Preserve established structure and patterns unless a targeted change is necessary for the agreed goal.
- **Search before designing.** Identify whether an existing project primitive, standard-library or native-platform feature, or already-installed dependency satisfies the contract before planning new code or a new dependency.

## Steps

1. **Read the source of truth.** Read the approved spec when one exists, the user's settled requirements, relevant repository instructions, code, tests, and recent history.
2. **Check scope and proportionality.** If independent subsystems or workstreams can land separately, or their combined diff would be difficult to review effectively, propose separate plans. For each discovered edge case, make the explicit include-or-defer judgment above. Remove detailed deferred work rather than folding it into later phases. Each plan should leave the repository in a working, testable state.
3. **Map the files and interfaces.** Identify files to create or modify, their responsibilities, and the contracts passed between phases. Co-locate files that change together; do not introduce unrelated restructuring.
4. **Define phases and checkpoints.** Keep the plan with one persistent implementation owner. Map one or more ordered phases into each coherent commit checkpoint. Add intermediate review checkpoints only where a foundational contract must be cleared before dependent work begins; the final checkpoint always receives cumulative review. Identify independent verification that may run concurrently. Do not add a review checkpoint to every phase.
5. **Write the plan.** Save it as `<project-root>/.plans/plans/<YYYYMMDD>_<short_title>.md` from the main repo cwd on `main`, not a worktree. **Do not commit it.**
6. **Self-review.** Check requirement coverage, placeholders, interface and naming consistency across phases, scope, and verification completeness. Fix gaps before handoff.
7. **Hand off.** Invoke one complete `adversarial-doc-review` on the plan and any spec, then address confirmed blocking findings before the user approval gate for implementation. A focused follow-up review is warranted only when a repair materially changes the contract or the original reviewer must confirm an unresolved blocker; non-blocking suggestions and documented deferrals do not keep the plan in review.

## Plan structure

Write for a fresh task owner with zero conversation context:

- **Goal** — one sentence describing the completed outcome.
- **Context** — only the repository facts and prior decisions needed to execute correctly.
- **Architecture** — the chosen approach and important boundaries; do not reopen settled design.
- **Global constraints** — exact project-wide requirements that every phase must preserve.
- **Phases** — ordered, independently verifiable deliverables.
- **Out of scope** — brief explicit fences, dependencies, consequences, and concrete revisit conditions only; link an existing follow-up issue when useful, but include no deferred implementation design.
- **Risks** — genuine residual risks, not unresolved design questions.

For each phase include:

- **Outcome** — the observable result.
- **Files** — exact paths to create, modify, and test; name relevant symbols when known.
- **Interfaces** — inputs or contracts consumed from earlier phases and public outputs later phases rely on; when not obvious, state dependencies, the checkpoint phase range, independent verification, and any foundational intermediate review boundary.
- **Work** — concrete implementation steps with enough detail to avoid rediscovery, while preserving task-owner judgment.
- **Verification** — exact commands or manual checks and the expected result. Recommend test-first or implementation-first only when the choice materially helps execution.

Do not leave `TBD`, `TODO`, vague "handle edge cases" instructions, unnamed tests, or references to undefined symbols. Do not duplicate complete implementation code in the plan unless an exact snippet is itself a required contract.
