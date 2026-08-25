---
name: planning
description: After the user chooses planning, write an executable implementation plan for a settled change whose complexity warrants coherent phases. Do not use for impact alone or while material design uncertainty remains.
---

# Planning

Turn settled requirements into a plan a fresh owner can execute without rediscovery or invented interfaces.

**Announce at start:** "Using the planning skill to write an executable implementation plan."

## Boundaries

- Inspect freely, but edit no implementation files and create no worktree.
- Plan only when implementation complexity benefits from coherent phases; impact alone calls for stronger verification, not a plan. If material design remains open, use `brainstorming`.
- Plan independently verifiable outcomes, not ceremony or artificial micro-steps. Reach runnable primary-path evidence early and leave execution-only questions to focused implementation checks.
- Keep one coherent review unit. Split independently landable work; describe deferred scope only by boundary, dependency, consequence, and concrete revisit condition, never its implementation.
- Include an edge case only for an active requirement or plausible material valid-use failure worth its cost. Misuse that fails loudly before harm needs no handling. Untrusted inputs and plausible security, data-loss, irreversible, or active-contract failures remain boundaries.
- Follow repository patterns and prefer an existing primitive, standard library or platform, or installed dependency before new code or dependencies.

## Steps

1. Read settled requirements, any approved spec, repository instructions, code, tests, and relevant history.
2. Split independent or unreviewably large workstreams. Make explicit include-or-defer judgments and keep every plan working and testable.
3. Map exact files, responsibilities, interfaces, and phase dependencies without unrelated restructuring.
4. Define ordered outcome phases under one persistent owner. Group coherent phases into commit checkpoints; add intermediate review only where a foundational contract must clear before dependent work, then cumulative final review. Note independent verification that may run concurrently.
5. Save `<project-root>/.plans/plans/<YYYYMMDD>_<short_title>.md` from main, not a worktree, and do not commit it.
6. Remove placeholders and fix requirement, interface, naming, scope, and verification gaps.
7. Invoke `adversarial-doc-review` on the plan and spec as one review unit with at most two completed passes. Address confirmed pass-one blockers; use pass two only for a contract-changing repair or unresolved blocker. After pass two, advance if clear or stop and give the required ELI5 blocker explanation; never dispatch pass three.

## Plan structure

Write for a fresh owner with no conversation context:

- **Goal:** one-sentence outcome.
- **Context:** only necessary facts and decisions.
- **Architecture:** chosen approach and boundaries.
- **Global constraints:** requirements every phase preserves.
- **Phases:** ordered, independently verifiable deliverables.
- **Out of scope:** fences, dependencies, consequences, and revisit conditions only.
- **Risks:** genuine residual risk, not open design.

For each phase include:

- observable outcome;
- exact files and relevant symbols;
- consumed and produced interfaces, dependencies, checkpoint range, independent checks, and any foundational review boundary;
- concrete work sufficient to avoid rediscovery while preserving owner judgment; and
- exact verification commands or manual checks with expected results.

Leave no `TBD`, `TODO`, vague edge-case work, unnamed tests, or undefined symbols. Include full code only when an exact snippet is itself a contract.
