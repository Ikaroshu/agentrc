---
name: implement
description: Execute a written plan from .plans one phase at a time with a fresh exact implementer role, scoped orchestration, and evidence review before each orchestrator-owned commit.
---

# Implement

Execute an approved plan phase by phase in its implementation worktree. The main agent orchestrates the work, reviews the evidence and complete diff, owns cross-phase decisions and commits, and invokes final code review.

**Announce at start:** "Using the implement skill to execute the plan phase by phase."

## Setup

1. Read the absolute plan path and any approved spec in full. Confirm that they still describe the current repository and agreed work.
2. Use the agreed implementation worktree and create one todo per plan phase.
3. Require the native collaboration runtime to support the exact configured `agent_type="implementer"`. If it does not, fail loudly; never substitute a generic agent or standalone harness.

## Per-phase loop

For each plan phase:

1. Build a self-contained prompt with the absolute worktree, plan and optional spec paths; exact phase; owned files or responsibility; expected verification; and the shared-worktree warning. Require changed paths, actual command output, remaining risks, and helper-integration details.
2. Dispatch one fresh task owner with exactly:

   ```text
   spawn_agent(
     agent_type="implementer",
     fork_turns="none",
     model="gpt-5.6-sol",
     reasoning_effort="high",
     message=<dynamic-phase-prompt>,
     task_name=<clear-unique-task-name>,
   )
   ```

3. Wait for completion, a question, a concrete failure, or user interruption. An ordinary scheduling or transport failure may be retried with the same exact role; do not weaken the role requirement.
4. Inspect `git status --short`, the complete phase diff, and the returned verification evidence. Recover or integrate mistakes when doing so is safe and within scope; surface unresolved scope, correctness, or authorization problems.
5. The orchestrator stages only the accepted phase paths and creates the phase commit, then marks the phase complete.

## Rules

- Use one fresh exact `implementer` per phase.
- Preserve unrelated work and reconcile overlapping edits explicitly.
- Treat checks as evidence: report failures accurately, determine whether they affect the phase, and keep unresolved risk visible.
- Do not use an implementer or its helpers to invoke implementation or review roles or workflows recursively.
- The orchestrator owns decisions that cross phase boundaries.

## After all phases

Run the complete repository verification, inspect the full branch diff, and invoke the `code-review` skill. The main agent verifies the review findings and decides what to change.
