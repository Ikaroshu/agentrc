---
name: brainstorming
description: Use after the user chooses brainstorming to resolve unclear intent, requirements, scope, or design choices before planning or implementation. Explore project context, ask one focused question at a time, compare approaches, and produce an approved design. Do not write an implementation plan.
---

# Brainstorming

Turn an unclear request into an agreed design before planning or implementation. Use this optional step only after the user agrees that brainstorming fits the scope.

**Announce at start:** "Using the brainstorming skill to clarify requirements and settle the design."

## Principles

- **No implementation yet.** Read and explore freely, but do not edit implementation files or write the implementation plan during this skill.
- **One question at a time.** Ask a single focused question, wait for the answer, then ask the next. Never dump a wall of questions.
- **Dig for intent.** Understand *why* before *what*. Surface the real problem, not just the requested solution.
- **Keep scope honest.** Separate independent subsystems before refining details. Avoid unrelated improvements.

## Steps

1. **Explore context.** Read the relevant code, docs, and recent history before proposing a design. Follow established project patterns.
2. **Check scope.** If the request spans independent subsystems, propose a decomposition and brainstorm one focused piece at a time.
3. **Interview the user, one question at a time.** Cover only what the design needs:
   - Intent — what problem are we actually solving, and for whom?
   - Requirements — what must be true when this is done? What is explicitly out of scope?
   - Constraints — existing patterns, dependencies, performance, compatibility.
4. **Compare approaches.** Present 2-3 viable approaches with tradeoffs. Lead with your recommendation and explain why it fits.
5. **Present the design.** Scale the detail to the problem. Cover relevant boundaries, interfaces, data flow, error behavior, and verification strategy. Get explicit user approval; revise if needed.
6. **Self-review.** Check the approved design for missing requirements, contradictions, unresolved ambiguity, and accidental scope growth. Fix issues inline with the user.
7. **Record it when useful.** For a substantial design that needs a durable artifact, write `<project-root>/.plans/specs/<YYYYMMDD>_<short_title>.md` from the main repo cwd on `main`. Keep it to problem, requirements, design, and non-goals. **Do not commit it.** Skip the file for a small design that can be carried directly into implementation.
8. **Hand off appropriately.** If planning was chosen, invoke `planning`. If the approved design is small and planning was not chosen, proceed to implementation. If planning now appears valuable but was not agreed, recommend it and ask once.
