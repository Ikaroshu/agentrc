---
name: implement
description: Use to execute a written plan (from .plans/) task by task with an implementation and testing sequence suited to each task. Dispatches one fresh task-owner subagent per task, permits nested delegation, and reviews verification evidence between tasks.
---

# Implement

Execute an agreed plan with per-task context isolation and evidence-backed verification. This is the implement step of the development workflow; run it after the plan exists and (for non-trivial work) inside an isolated worktree.

**Announce at start:** "Using the implement skill to execute the plan task by task."

## Setup

1. Read the plan at `<project-root>/.plans/plans/<title>.md`. Confirm the phase breakdown with the user if anything is stale.
2. Ensure the right workspace: an isolated worktree for non-trivial work, or `main` directly when the scope is small and `main` is clean.
3. Create one todo per plan phase.

## Per-task loop

When the main model is Fable, dispatch every task subagent with `model: "opus"`. For any other main model, omit the model override and use the default.

For **each** task, dispatch **one fresh task-owner subagent** (clean context) accountable for choosing a suitable implementation and testing sequence and reporting back:

1. **Choose the sequence** — prefer test-first for bugs, behavior changes, and logic with a clear executable contract. Implementation-first is acceptable for refactors, configuration, infrastructure, exploratory integration work, or whenever it produces a clearer and more useful test. Briefly explain the choice when not using test-first.
2. **Implement and test** — make the smallest change that completes the task, using the chosen sequence. No extra scope.
3. **Verify** — run the focused tests or checks and the appropriate surrounding suite. Return the **actual command output** as evidence, plus a short summary of the diff.

When a unit test does not fit the task, use an appropriate **verification gate**: the repo's validation script, lint/type-check, or a concrete manual check with expected output. Never fabricate a trivial test just to satisfy a process.

The subagent's final message must include the real verification output.

### Nested helpers

The task owner may delegate work to nested helpers, and those helpers may
delegate further, when useful. Keep the agent tree scoped to the current plan
task.

The task owner coordinates shared-worktree changes, reviews and integrates
delegated work, and remains accountable for the task's final diff and complete
verification evidence.

## Between tasks (orchestrator checkpoint)

After each subagent returns:

1. **Verify the evidence.** Confirm from the output that the test actually ran and passed — not a claim. If the output is missing or unconvincing, send it back.
2. **Review the diff.** Check it matches the plan and does not sprawl beyond the task.
3. **Commit the task.** Stage only the current task's changes and create a focused commit before dispatching the next subagent.
4. Mark the todo complete and move to the next task.

## Rules

- **One fresh task owner per task** — context isolation is the point; do not
  reuse a task owner across plan tasks.
- **No faking verification.** If a required test or check will not pass after a genuine attempt, STOP and surface it to the user — do not skip it, weaken the assertion, or mark the task done.
- **Evidence over assertion.** Every "done" is backed by command output you have seen.

## After all tasks

Run the shared `code-review` skill on the full diff before merging. Address each finding or push back with reasoning.
