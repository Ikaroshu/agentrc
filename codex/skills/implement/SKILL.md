---
name: implement
description: Execute a written plan from .plans one phase at a time with a fresh exact implementer role, deterministic Git guards, scoped orchestration, and evidence review before each orchestrator-owned commit.
---

# Implement

Execute an approved plan phase by phase in its implementation worktree. The main agent is the orchestrator and retains every commit, cross-phase decision, diff/evidence checkpoint, and final code review.

**Announce at start:** "Using the implement skill to execute the plan phase by phase."

## Setup

1. Read the absolute plan path and any approved spec in full. Confirm the phase breakdown if it is stale.
2. Use the agreed implementation worktree and create one todo per plan phase.
3. Locate this skill's `scripts/git_task_guard.py`. Use it directly for every pre-dispatch snapshot and post-return verification; do not ask an implementer to self-police Git state. The guard protects the exact plan/spec inputs, all refs, semantic index state, and sibling-worktree state in addition to the task worktree.
4. Require the callable native spawn schema to accept the exact configured `agent_type="implementer"`. If it does not, stop and identify a fresh supported Codex runtime with the installed role as the prerequisite. Never substitute a generic agent, Codex or Claude CLI process, OMP, a review runner, or another standalone harness.

## Per-phase loop

For each plan phase:

1. Create a temporary snapshot path outside the repository. Run:

   ```bash
   python3 <implement-skill>/scripts/git_task_guard.py snapshot \
     --repository <absolute-worktree-path> \
     --output <absolute-snapshot-path> \
     --protect-path <absolute-plan-path> \
     [--protect-path <absolute-spec-path>]
   ```

   The guard runs `git status --porcelain=v1 --untracked-files=all` and refuses dispatch unless it is completely empty, including staged, unstaged, untracked-file, and untracked-directory content. It then records HEAD, the current branch, the complete ref namespace, semantic index state, `git worktree list --porcelain`, every sibling worktree's Git-visible state, and hashes of the exact ignored or tracked plan/spec inputs.

2. Build a self-contained dynamic prompt containing:

   - the absolute plan path and optional absolute spec path;
   - the absolute implementation worktree cwd;
   - the exact phase number and title;
   - explicit owned files or responsibility and verification expectations;
   - a warning that other agents may edit the shared worktree and their changes must be preserved;
   - the role's complete restrictions: no staging or other index mutations; no plan/spec or sibling-worktree changes; no commits, pushes, merges, commit creation, branch/worktree/ref mutations, external writes or messages, mutating connector/browser/Computer Use actions, standalone Codex/Claude/OMP/review-runner or CLI-agent launches, recursive orchestration/review workflows, or sandbox approval/escalation requests;
   - for every nested helper, the requirement to propagate that complete restriction set, the phase context, disjoint ownership, concurrent-edit warning, and no-escalation rule while inheriting the implementer's model and reasoning effort.

   State that these are instruction-level restrictions, not a capability boundary. Require real focused and surrounding verification output, changed paths, remaining risks, and delegated-work integration details.

3. Dispatch one fresh native task owner with exactly:

   ```text
   spawn_agent(
     agent_type="implementer",
     fork_turns="none",
     model="gpt-5.6-sol",
     reasoning_effort="high",
     message=<dynamic-phase-prompt>,
     task_name=<unique-phase-task-name>,
   )
   ```

   There is no generic-agent or standalone CLI fallback.

4. Wait passively using the platform's longest practical event-driven wait. Do not poll status, inspect partial transcripts or worktree changes, or send progress messages while the owner or its helpers run. Resume only for completion, a blocker or question, a concrete failure/deadline signal, or user interruption.

5. After the task owner returns, run:

   ```bash
   python3 <implement-skill>/scripts/git_task_guard.py verify \
     --repository <absolute-worktree-path> \
     --snapshot <absolute-snapshot-path> \
     --allow-path <owned-path> [--allow-path <owned-path> ...]
   ```

   Use repository-relative exact paths; append `/` only for an explicitly owned directory. Reject the phase if HEAD, current branch, any ref, semantic index state, worktree inventory, sibling-worktree state, or a protected plan/spec changed, or if any staged, unstaged, or untracked return path falls outside the allowlist. Surface the exact violation before accepting or committing anything. These observable repository checks cannot prove the absence of arbitrary external side effects or ignored-file changes outside the protected plan/spec inputs.

6. Verify the returned command output actually shows focused and surrounding checks ran and passed. Inspect the complete owned diff, integrate any delegated work, and reject missing evidence or scope sprawl.
7. The orchestrator alone stages the accepted phase paths and creates one focused commit. Then remove the temporary snapshot, mark the phase complete, and proceed from the newly clean worktree.

## Rules

- Use one fresh exact `implementer` per plan phase; never reuse a task owner across phases.
- Stop for reconciliation instead of dispatching into any dirty worktree.
- Never fake, skip, or weaken verification. Surface a genuine required-check failure.
- Keep failures and residual risk visible. The orchestrator owns decisions that cross phase boundaries.

## After all phases

The orchestrator runs the complete verification gate, inspects the full branch diff, and invokes the `code-review` skill. Never delegate final review or publication to an implementer.
