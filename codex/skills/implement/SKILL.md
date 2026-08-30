---
name: implement
description: Deliver a settled design and outcome through one exact xhigh implementer, verify it, and send the completed implementation through one code review.
---

# Implement

Give one persistent owner the settled design, outcome, and verification. An approved spec may supply that contract, but direct implementation does not require a spec. The implementer chooses how to deliver it.

**Announce at start:** "Using the implement skill with one xhigh implementer, followed by one code review."

## Start

1. Collect the settled **design**, **outcome**, and **verification** from the approved spec or direct user agreement. Confirm they still match the repository and governing instructions.
2. Use the agreed worktree and record the immutable review base.
3. Require exact native `agent_type="implementer"`; fail loudly rather than substituting a generic agent or harness.
4. Prompt with the absolute worktree, the spec path when present, the settled design, outcome, and verification, relevant repository context, and the shared-worktree warning. Give the implementer discretion over implementation approach, sequencing, tools, delegation, tests, and commit structure. It remains accountable for the integrated result and evidence.
5. Dispatch exactly:

   ```text
   spawn_agent(
     agent_type="implementer",
     fork_turns="none",
     model="gpt-5.6-sol",
     reasoning_effort="xhigh",
     message=<dynamic-contract-prompt>,
     task_name=<clear-outcome-name>,
   )
   ```

Block until the requested implementer returns. Handle unrelated events and resume; do not inspect partial Git state while it or its collaborators work.

## Design flaws

The implementer stops further implementation and reports when repository evidence shows that the settled design cannot achieve the outcome or verification, violates a material constraint, or requires a material contract change. It must not improvise a replacement design. Its report includes the evidence, impact, options worth discussing, and exact worktree state.

Verify the reported flaw, then discuss it with the user. Settle a correction or revise the design and any spec before using `followup_task` to resume the same implementer. Ordinary implementation choices that preserve the settled design, outcome, and verification do not need orchestration.

## Verify the result

When implementation completes, inspect the clean worktree, full review-base-to-candidate diff, commit and tree identities, and returned evidence. Run the settled verification and every repository-required check on the exact candidate. Route missing outcome, implementation defects, or failed verification through the same implementer with `followup_task`, then verify the new candidate. Record the accepted candidate commit, tree, commands, and results.

## Review

Invoke `code-review` once on the full immutable review-base-to-candidate diff, supplying the settled design, outcome, verification, candidate identity, implementation commits, and actual verification evidence. This is one review unit with at most two passes.

Verify every finding. Route confirmed pass-one repairs through the same implementer, then rerun the settled and repository-required verification before pass two. If pass two leaves a confirmed repair or material uncertainty, stop, dispatch no third pass, and explain the blocker in ELI5 terms with the relevant context, evidence, impact, what the two passes tried, what remains unclear, and the user decision or external change needed.

When the review is clear, record its accepted commit and tree and ask for merge approval immediately. Schedule no implementation, repair, or verification work between acceptance and that request. Any later code or configuration change or failed check invalidates acceptance and returns the candidate to implementation; it does not reset an exhausted review budget without a new user decision.
