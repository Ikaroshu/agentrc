---
name: implement
description: Use to execute a written plan (from .plans/) task by task with test-driven development. Dispatches one fresh subagent per task to run a full RED→GREEN→verify cycle, and reviews the evidence between tasks. Replaces ad-hoc implementation.
---

# Implement

Execute an agreed plan with TDD discipline and per-task context isolation. This is the implement step of the development workflow; run it after the plan exists and (for non-trivial work) inside an isolated worktree.

**Announce at start:** "Using the implement skill to execute the plan task by task."

## Setup

1. Read the plan at `<project-root>/.plans/plans/<title>.md`. Confirm the phase breakdown with the user if anything is stale.
2. Ensure the right workspace: an isolated worktree for non-trivial work, or `main` directly when the scope is small and `main` is clean.
3. Create one todo per plan phase.

## Per-task loop

For **each** task, dispatch **one fresh subagent** (clean context) instructed to run the full cycle and report back:

1. **RED** — write a failing test that captures the task's requirement. Run it; confirm it fails *for the right reason* (not a typo or import error).
2. **GREEN** — write the minimal implementation to make the test pass. No extra scope.
3. **Verify** — run the test and the surrounding suite. Return the **actual command output** as evidence, plus a short summary of the diff.

When a unit test doesn't fit the task — config/infra changes, docs, pure refactors — keep the cycle but generalize "test" to the **verification gate**: the repo's validation script, lint/type-check, or a concrete manual check with expected output. Confirm it's red (failing or unmet), do the work, then show it green. Never fabricate a trivial test just to satisfy the ritual.

The subagent's final message must include the real verification output.

## Between tasks (orchestrator checkpoint)

After each subagent returns:

1. **Verify the evidence.** Confirm from the output that the test actually ran and passed — not a claim. If the output is missing or unconvincing, send it back.
2. **Review the diff.** Check it matches the plan and does not sprawl beyond the task.
3. Mark the todo complete and move to the next task.

## Rules

- **One task per subagent, fresh each time** — context isolation is the point; do not reuse a subagent across tasks.
- **No faking green.** If a test will not pass after a genuine attempt, STOP and surface it to the user — do not skip the test, weaken the assertion, or mark the task done.
- **Evidence over assertion.** Every "done" is backed by command output you have seen.

## After all tasks

Run a cross-agent code review of the full diff (`codex-code-review` for Claude, `claude-code-review` for Codex) before merging. Address each finding or push back with reasoning.
