---
name: brainstorming
description: Use before any non-trivial feature, change, or design work — explores intent, requirements, and design through one-question-at-a-time dialogue, then writes a plan (and optional spec) to .plans/. Replaces jumping straight to code.
---

# Brainstorming

Turn a vague request into an agreed, written plan before any code is written. This is the brainstorm + doc step of the development workflow.

**Announce at start:** "Using the brainstorming skill to scope this before we plan."

## Principles

- **No code yet.** Read and explore freely, but do not edit or write implementation files during this skill.
- **One question at a time.** Ask a single focused question, wait for the answer, then ask the next. Never dump a wall of questions.
- **Dig for intent.** Understand *why* before *what*. Surface the real problem, not just the requested solution.

## Steps

1. **Understand the request.** Read the relevant code and docs to ground yourself. Identify what is ambiguous.
2. **Interview the user, one question at a time.** Cover, as needed:
   - Intent — what problem are we actually solving, and for whom?
   - Requirements — what must be true when this is done? What is explicitly out of scope?
   - Constraints — existing patterns, dependencies, performance, compatibility.
   - Design options — present 2-3 approaches with tradeoffs; get a decision.
3. **Reflect understanding back.** Summarize the agreed problem and approach in a few sentences. Get explicit agreement before writing anything.
4. **Write the plan.** Always write `plan.md`; write `spec.md` only when the problem itself is ambiguous (novel feature, unclear requirements).
   - Plan path: `<project-root>/.plans/plans/<short-title>.md`
   - Spec path: `<project-root>/.plans/specs/<short-title>.md`
   - Write from the **main repo cwd on `main`**, NOT a worktree — these paths must stay stable for doc-review. Do not create a worktree yet.
   - **Do NOT commit** plan or spec files.
5. **Hand off.** Tell the user the files are ready and recommend running `adversarial-doc-review` next.

## Plan structure

Write the plan for a **fresh engineer with zero context** — the `implement` skill dispatches a clean-context subagent per task, so the plan must stand on its own.

A good `plan.md`:

- **Goal** — one sentence.
- **Context** — the few facts (files, patterns, constraints) the executor needs but can't infer.
- **Phases** — ordered; each an independently testable task that leaves the system working (green). For each phase, name the **concrete files/functions** to change and state how it's verified (the exact test or command + expected result). Right-size each phase to execute and review in one pass.
- **Out of scope** — what NOT to touch, to fence off scope creep.

Resolve open decisions during brainstorming — the plan should be executable without further choices. Note genuine residual **risks**, but not unresolved questions.

When written, keep the spec to: problem, requirements, non-goals.
