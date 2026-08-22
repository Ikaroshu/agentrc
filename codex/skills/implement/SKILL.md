---
name: implement
description: Execute an approved written plan with one persistent exact implementer that owns implementation and checkpoint commits, helper verification, persistent review, and exact-candidate acceptance evidence.
---

# Implement

Execute an approved plan in its implementation worktree through one persistent implementer. The implementer owns implementation, helper integration, focused verification, and checkpoint commits. The main agent owns scope, review dispositions, and final acceptance.

**Announce at start:** "Using the implement skill with one persistent implementer and reviewer."

## Setup

1. Read the absolute plan path and any approved spec in full. Confirm that they still describe the current repository and agreed work.
2. Use the agreed implementation worktree. Record the immutable review-base commit. Identify the ordered phases, map one or more phases into each coherent commit checkpoint, and mark only foundational intermediate checkpoints whose defects must be cleared before dependent work begins.
3. Require the native collaboration runtime to support the exact configured `agent_type="implementer"`. If it does not, fail loudly; never substitute a generic agent or standalone harness.

## Persistent owner

1. Build a self-contained prompt with the absolute worktree, plan and optional spec paths; the first checkpoint's phase range; checkpoint and commit ownership; dependencies; expected focused verification; permitted read-only helper verification; and the shared-worktree warning. Require every helper and long-running command to finish before a checkpoint, then require the completed phase range, checkpoint commit SHA, changed paths, actual command output, remaining risks, and helper-integration details.
2. Dispatch one persistent owner with exactly:

   ```text
   spawn_agent(
     agent_type="implementer",
     fork_turns="none",
     model="gpt-5.6-sol",
     reasoning_effort="high",
     message=<dynamic-phase-prompt>,
     task_name=<clear-plan-name>,
   )
   ```

3. Reuse that owner for every later checkpoint phase range and confirmed review repair with `followup_task`; do not force it to rediscover the plan. Replace it only if it becomes unavailable, and give the replacement the full plan and accepted checkpoint history.

## Checkpoint loop

For each checkpoint, which may cover one or more ordered plan phases:

1. Let the implementer execute the assigned phase range itself. It may spawn helpers for independent, non-modifying verification that can run concurrently; it remains the only implementation writer and commit owner.
2. The implementer waits for every helper and long-running command, integrates the evidence, runs the applicable focused and repository-required checkpoint checks, inspects the intended diff, stages only the checkpoint paths, and creates the checkpoint commit.
3. Use blocking waits as needed until the requested implementer returns its checkpoint result. Handle unrelated real events, then resume waiting; do not inspect partial Git state while the implementer or its helpers are active. After the implementer returns, inspect the clean status, exact checkpoint commit, and reported evidence.
4. For a marked foundational intermediate checkpoint, invoke `code-review` on the immutable checkpoint commit. Start the persistent reviewer at the first required review and reuse it thereafter. Do not review every phase automatically, and do not add a user approval gate for intermediate review.
5. Verify every finding. Send confirmed repairs to the same implementer with `followup_task`; require a repair commit and send it to the same reviewer. Continue only after a required intermediate checkpoint is cleared.

## Rules

- Keep one accountable implementer for the complete plan and one reviewer for its checkpoint chain.
- Preserve unrelated work and reconcile overlapping edits explicitly.
- Use focused checks during implementation unless repository instructions require a broader checkpoint gate. Treat checks as evidence: report failures accurately, determine whether they affect the checkpoint, and keep unresolved risk visible.
- Do not use an implementer or its helpers to invoke implementation or review roles or workflows recursively.
- The implementer owns checkpoint commits; the orchestrator owns scope and review decisions.

## After all phases

After the final checkpoint, reuse the persistent reviewer when one already exists; otherwise start it with this final review. Ask it to assess cumulative integration across the full immutable review-base-to-candidate diff without rereviewing unchanged accepted commits line by line. Supply the recorded review-base commit, exact candidate commit and tree, accepted checkpoint list, `git diff --stat --find-renames <review-base>...<candidate-sha>`, `git diff --find-renames <review-base>...<candidate-sha>`, and `git rev-parse <candidate-sha>^{tree}`. A single-commit scope is never sufficient for this final review. Resolve confirmed findings through the same implementer; require a repair commit, have the same reviewer check it, and repeat the cumulative review against the new candidate. Then run the complete repository verification once on the exact clean reviewed commit. Record the commit, tree identity, command, and result so `merge` can reuse the evidence while the candidate remains unchanged. Any later code change requires another checkpoint commit, applicable review, cumulative acceptance, and verification.
