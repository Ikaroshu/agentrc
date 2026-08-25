---
name: implement
description: Execute an approved plan through one persistent exact implementer, checkpoint commits, persistent review, and exact-candidate acceptance evidence.
---

# Implement

Execute an approved plan in its worktree through one persistent owner. The implementer owns code, helper integration, checks, and checkpoint commits; the main agent owns scope, review dispositions, and acceptance.

**Announce at start:** "Using the implement skill with one persistent implementer and reviewer."

## Setup

1. Read the absolute plan and approved spec in full and confirm they still match the repository and agreement.
2. Use the agreed worktree, record the immutable review base, map one or more ordered plan phases into each coherent checkpoint commit, and mark only foundational checkpoints that must clear review before dependent work.
3. Require exact native `agent_type="implementer"`; fail loudly rather than substituting a generic agent or harness.

## Persistent owner

1. Prompt with absolute worktree, plan/spec paths, assigned phase range, dependencies, checkpoint and commit ownership, focused checks, permitted read-only helpers, and shared-worktree warning. Require all helpers and commands to finish, then return phase range, checkpoint commit SHA, changed paths, actual check output, risks, and helper integration.
2. Dispatch exactly:

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

3. Use `followup_task` for every later checkpoint and confirmed repair. Replace the owner only if unavailable, supplying the full plan and accepted history.

## Checkpoint loop

For each checkpoint:

1. The implementer writes the assigned phases and may spawn only independent, non-modifying verification helpers; it remains sole writer and commit owner.
2. It waits for all helpers and commands, integrates evidence, runs focused and required checkpoint checks, inspects the diff, stages only intended paths, and commits.
3. Block until the requested implementer returns. Handle unrelated events and resume; never inspect partial Git state while it or helpers work. Then inspect clean status, exact commit, and evidence.
4. Run `code-review` only on marked foundational intermediate commits. Start the persistent reviewer at the first review and reuse it; add no user approval gate.
5. Track the checkpoint's two-pass review budget. Verify dispositions after pass one; send only confirmed repairs to the same implementer with `followup_task`, require a repair commit, and use pass two to review it. Repairs and replacement reviewers do not reset the budget. Continue when required repairs are gone. If pass two leaves a confirmed repair or material uncertainty, stop the implementation workflow, dispatch no third review, and explain the blocker in ELI5 terms with the relevant context, evidence, impact, what the two passes tried, what remains unclear, and the user decision or external change needed. Keep accepted deferrals brief or in separately authorized issues.

## Rules

- Keep one implementer and one reviewer for the chain. Preserve unrelated work and reconcile overlaps.
- Use focused checks unless repository instructions require more. Treat failures as evidence and keep unresolved risk visible.
- No recursive implementation or review roles/workflows. The implementer owns commits; the orchestrator owns scope and review decisions.

## After all phases

Reuse the reviewer, or start it if none exists, for cumulative integration over the full immutable review-base-to-candidate diff. Supply base, candidate commit and tree, accepted checkpoints, `git diff --stat --find-renames <base>...<candidate>`, `git diff --find-renames <base>...<candidate>`, and `git rev-parse <candidate>^{tree}`; one commit is never sufficient. The cumulative review is one unit with a hard two-pass budget independent of checkpoint budgets. Route confirmed pass-one repairs through the same implementer and repair commit, then use pass two to review the repair and plausible interactions without reopening accepted scope; repairs and reviewer replacement do not reset the count. If pass two leaves a confirmed repair or material uncertainty, stop, dispatch no third review, and explain the blocker in ELI5 terms with the relevant context, evidence, impact, what the two passes tried, what remains unclear, and the user decision or external change needed. When repairs are gone, run complete repository verification once on the exact clean reviewed commit and record commit, tree, command, and result for `merge`. Any later code change requires a new checkpoint commit, applicable review, cumulative acceptance, and verification; it does not reset an exhausted cumulative review budget without a new user decision.
