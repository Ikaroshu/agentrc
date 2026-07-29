---
name: brainstorming
description: Use automatically when a discussion or request has material uncertainty about intent, requirements, scope, assumptions, or design choices that could change the outcome. Explore project context, discuss meaningful design tensions with the user, compare approaches, and produce an approved design before planning or implementation. Do not use for clear factual questions, well-scoped tasks, or details discoverable from project context. Do not write an implementation plan.
---

# Brainstorming

Turn material uncertainty into an agreed design before planning or implementation. Trigger automatically when necessary, then converge as soon as the design is decision-ready.

**Announce at start:** "Using the brainstorming skill to clarify the material uncertainty and settle the design."

## Principles

- **No implementation yet.** Read and explore freely, but do not edit implementation files or write the implementation plan during this skill.
- **Keep the user inside the reasoning.** Surface the working view and any genuinely relevant alternative or concern, then give the user room to challenge, extend, or redirect the thinking before settling the design. Never complete a meaningful design debate entirely with yourself and present only the conclusion.
- **One question at a time.** Ask a single focused question, wait for the answer, then ask the next. Never dump a wall of questions.
- **Keep dialogue bounded.** Ask only questions whose answers could materially change the design. Stop when it is decision-ready. If discussion stops producing new information, state the remaining tension, recommend a resolution, and seek approval.
- **Dig for intent.** Understand *why* before *what*. Surface the real problem, not just the requested solution.
- **Keep scope honest.** Separate independent subsystems before refining details. Avoid unrelated improvements.

## Steps

1. **Explore context.** Read the relevant code, docs, and recent history before proposing a design. Follow established project patterns.
2. **Confirm brainstorming is necessary.** If exploration resolves the uncertainty, exit the skill and continue normally. Do not manufacture design choices.
3. **Check scope.** If the request spans independent subsystems, propose a decomposition and brainstorm one focused piece at a time.
4. **Discuss the design, one question at a time.** Surface the current view and any genuinely relevant challenge, then invite the user to challenge, extend, or redirect the thinking before settling it. Cover only what the design needs:
   - Intent — what problem are we actually solving, and for whom?
   - Requirements — what must be true when this is done? What is explicitly out of scope?
   - Constraints — existing patterns, dependencies, performance, compatibility.
5. **Compare approaches.** Present 2-3 viable approaches with tradeoffs when genuine alternatives exist. Lead with your recommendation and explain why it fits.
6. **Present the design.** Scale the detail to the problem. Cover relevant boundaries, interfaces, data flow, error behavior, and verification strategy. Get explicit user approval; revise if needed.
7. **Self-review.** Check the approved design for missing requirements, contradictions, unresolved ambiguity, and accidental scope growth. Fix issues inline with the user.
8. **Record it when useful.** For a substantial design that needs a durable artifact, write `<project-root>/.plans/specs/<YYYYMMDD>_<short_title>.md` from the main repo cwd on `main`. Keep it to problem, requirements, design, and non-goals. **Do not commit it.** Skip the file for a small design that can be carried directly into implementation.
9. **Hand off appropriately.** If planning was chosen, invoke `planning`. If the approved design is small and planning was not chosen, proceed to implementation. If planning now appears valuable but was not agreed, recommend it and ask once.
