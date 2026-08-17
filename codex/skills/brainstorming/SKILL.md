---
name: brainstorming
description: Use only when a material uncertainty about intent, requirements, scope, assumptions, or design choices requires meaningful discussion with the user before planning or implementation can proceed. This is a user-interaction workflow, not a private reasoning technique. Do not use when Codex can resolve the uncertainty through project context, ordinary reasoning, or safe in-scope assumptions, or for clear factual questions and well-scoped tasks. Explore context, discuss consequential design tensions, and produce an approved design. Do not write an implementation plan.
---

# Brainstorming

Turn a material design question that requires user input into an agreed design before planning or implementation. Do not invoke this skill merely to structure private thinking.

**Announce at start:** "Using the brainstorming skill to clarify the material uncertainty and settle the design."

## Principles

- **No implementation yet.** Read and explore freely, but do not edit implementation files or write the implementation plan during this skill.
- **Require meaningful user input.** Invoke only when progress depends on the user's intent, preference, or tradeoff decision. The existence of uncertainty or alternatives is not enough. If context, ordinary reasoning, established constraints, or safe in-scope assumptions resolve the question, continue normally without invoking or announcing this skill.
- **Keep the user inside the reasoning.** Surface the working view and any genuinely relevant alternative or concern, then give the user room to challenge, extend, or redirect the thinking before settling the design. Never complete a meaningful design debate entirely with yourself and present only the conclusion.
- **One question at a time.** Ask a single focused question, wait for the answer, then ask the next. Never dump a wall of questions.
- **Keep dialogue bounded.** Ask only questions whose answers could materially change the design. Stop when it is decision-ready. If discussion stops producing new information, state the remaining tension, recommend a resolution, and seek approval.
- **Dig for intent.** Understand *why* before *what*. Surface the real problem, not just the requested solution.
- **Search before designing.** After understanding the problem, determine whether it needs a code change; inspect existing project primitives or patterns, the standard library or native platform, and already-installed dependencies before proposing new code or a new dependency.
- **Keep scope honest.** Separate independent subsystems before refining details. Avoid unrelated improvements.

## Steps

1. **Explore context.** Read the relevant code, docs, and recent history before proposing a design. Follow established project patterns.
2. **Confirm discussion is necessary.** Continue only if at least one consequential question requires the user's answer. If exploration or private reasoning resolves the uncertainty, or established constraints and safe in-scope assumptions provide a clear path, exit the skill and continue normally. Do not manufacture design choices or use this skill as a self-review checklist.
3. **Check scope.** If the request spans independent subsystems, propose a decomposition and brainstorm one focused piece at a time.
4. **Discuss the design, one question at a time.** Surface the current view and any genuinely relevant challenge, then invite the user to challenge, extend, or redirect the thinking before settling it. Cover only what the design needs:
   - Intent — what problem are we actually solving, and for whom?
   - Requirements — what must be true when this is done? What is explicitly out of scope?
   - Constraints — existing patterns, dependencies, performance, compatibility.
5. **Compare approaches.** Present 2-3 viable approaches with tradeoffs when genuine alternatives exist. Treat no change, documentation, accepting a limitation, or an operational workaround as viable approaches when they satisfy the intent. Prefer the approach with the least total machinery and ownership cost, not merely the fewest lines or files. Lead with your recommendation and explain why it fits.
6. **Present the design.** Scale the detail to the problem. Cover relevant boundaries, interfaces, data flow, error behavior, and verification strategy. When the chosen simplification has a real, non-obvious ceiling, state that ceiling and the concrete condition for revisiting it. Get explicit user approval; revise if needed.
7. **Self-review.** Check the approved design for missing requirements, contradictions, unresolved ambiguity, and accidental scope growth. Fix issues inline with the user.
8. **Record it when useful.** For a substantial design that needs a durable artifact, write `<project-root>/.plans/specs/<YYYYMMDD>_<short_title>.md` from the main repo cwd on `main`. Keep it to problem, requirements, design, and non-goals. **Do not commit it.** Skip the file for a small design that can be carried directly into implementation.
9. **Hand off appropriately.** If planning was chosen, invoke `planning`. If the approved design is small and planning was not chosen, proceed to implementation. If planning now appears valuable but was not agreed, recommend it and ask once.
