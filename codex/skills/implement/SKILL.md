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
3. Before implementation starts, select the implementation review tier from the approved plan and the full implementation's overall complexity, including every checkpoint and cumulative integration. Lock that exact model and effort for the persistent reviewer chain; never infer the tier from the first checkpoint or recalculate it per checkpoint.
4. Require exact native `agent_type="implementer"`; fail loudly rather than substituting a generic agent or harness.

## Persistent owner

1. Prompt with absolute worktree, plan/spec paths, assigned phase range, dependencies, checkpoint and commit ownership, focused checks, permitted read-only helpers, and shared-worktree warning. Require all helpers and commands to finish, then return phase range, checkpoint commit SHA, changed paths, actual check output, any accepted temporary failures with their evidence and expected settling phase or rerun, risks, and helper integration.
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
2. It waits for all helpers and commands, integrates evidence, runs focused and required checkpoint checks, inspects the diff, stages only intended paths, and commits. A checkpoint may carry a failing check when evidence shows that the failure comes from work intentionally left to a later phase or a transient tool or environment condition, rather than a product bug, design flaw, or material risk. Record the failing command and output, why it is non-blocking, and the later phase or rerun expected to settle it. Do not add workaround or product code solely to make an intermediate checkpoint green.
3. Block until the requested implementer returns. Handle unrelated events and resume; never inspect partial Git state while it or helpers work. Then inspect clean status, exact commit, and evidence.
4. Run `code-review` only on marked foundational intermediate commits. Start the persistent reviewer at the first review and reuse it; add no user approval gate.
5. Track the checkpoint's two-pass review budget. Verify dispositions after pass one; send only confirmed repairs to the same implementer with `followup_task`, require a repair commit, and use pass two to review it. Repairs and replacement reviewers do not reset the budget. Continue when required repairs are gone. If pass two leaves a confirmed repair or material uncertainty, stop the implementation workflow, dispatch no third review, and explain the blocker in ELI5 terms with the relevant context, evidence, impact, what the two passes tried, what remains unclear, and the user decision or external change needed. Keep accepted deferrals brief or in separately authorized issues.

## Rules

- Keep one implementer and one reviewer for the chain. Preserve unrelated work and reconcile overlaps.
- Use focused checks unless repository instructions require more. Treat failures as evidence and keep unresolved risk visible. Repair product bugs and design flaws before proceeding; carry only evidenced temporary checkpoint failures that later planned work or a clean rerun should settle.
- No recursive implementation or review roles/workflows. The implementer owns commits; the orchestrator owns scope and review decisions.

## After all phases

After every phase and checkpoint repair is complete, run complete repository verification on the exact clean candidate. Every temporary checkpoint failure must now be settled. Resolve product failures before cumulative review; for an unrelated transient tool or environment failure, rerun the same check after the condition clears instead of changing product code. Repeat focused work and complete verification until no implementation, repair, or check-settling work remains. Record the candidate commit, tree, command, and successful result.

Only then reuse the reviewer, or start it if none exists, for cumulative integration over the full immutable review-base-to-candidate diff. Supply base, candidate commit and tree, accepted checkpoints, the recorded complete-verification evidence, `git diff --stat --find-renames <base>...<candidate>`, `git diff --find-renames <base>...<candidate>`, and `git rev-parse <candidate>^{tree}`; one commit is never sufficient. The cumulative review is the last technical gate and has a hard two-pass budget independent of checkpoint budgets.

Route confirmed pass-one repairs through the same implementer and a repair commit. Run the applicable checks and complete repository verification on the repaired clean candidate before using pass two to review the repair and plausible interactions without reopening accepted scope; repairs and reviewer replacement do not reset the count. If pass two leaves a confirmed repair or material uncertainty, stop, dispatch no third review, and explain the blocker in ELI5 terms with the relevant context, evidence, impact, what the two passes tried, what remains unclear, and the user decision or external change needed. When a cumulative pass is clear, record its accepted commit and tree and ask for merge approval immediately. Schedule no implementation, repair, or verification work between acceptance and that request. Any later code or configuration change or failed check invalidates cumulative acceptance and returns the candidate to settlement; it does not reset an exhausted review budget without a new user decision.
