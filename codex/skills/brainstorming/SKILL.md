---
name: brainstorming
description: Resolve material intent, requirement, scope, assumption, or design uncertainty that needs user discussion before planning or implementation. Do not use for private reasoning, well-scoped work, or uncertainty resolvable from context or safe assumptions.
---

# Brainstorming

Turn a consequential question that needs user input into an approved design. Do not use this skill to structure private thinking.

**Announce at start:** "Using the brainstorming skill to clarify the material uncertainty and settle the design."

## Boundaries

- Explore freely, but edit no implementation files and write no implementation plan.
- Continue only while progress depends on a user preference or tradeoff. If context, established constraints, ordinary reasoning, or safe assumptions settle it, exit and continue normally.
- Keep the user in the reasoning. Ask one consequential question at a time, explain the current view, and invite correction. Stop when decision-ready; if discussion stalls, recommend a resolution and seek approval.
- Understand why before what, separate independent subsystems, and exclude unrelated improvements.

## Workflow

1. Read relevant code, docs, history, and repository rules. Determine whether any code is needed; prefer an existing project primitive, the standard library or platform, or an installed dependency.
2. Confirm a consequential question still needs the user. If independent subsystems are mixed, propose a split and discuss one at a time.
3. Discuss only material intent, requirements, non-goals, constraints, boundaries, and tradeoffs. When genuine alternatives exist, compare 2–3, including no change, documentation, or accepting a limitation where viable. Lead with the simplest reliable recommendation.
4. Present a proportionate design covering relevant interfaces, data flow, failure behavior, and verification. State any non-obvious ceiling and revisit condition. Get explicit approval and resolve contradictions, missing requirements, ambiguity, or scope growth inline.
5. When durability helps, save the approved problem, requirements, design, and non-goals to `<project-root>/.plans/specs/<YYYYMMDD>_<short_title>.md` from main; do not commit it. Skip this for small designs.
6. Invoke `planning` if chosen; otherwise implement a small approved design directly. If planning only now appears useful, recommend it and ask once.
