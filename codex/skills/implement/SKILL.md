---
name: implement
description: Deliver a settled change directly in the main agent or through one exact xhigh implementer for delegated work, then send the verified candidate through independent code review.
---

# Implement

Keep one persistent owner for the settled design, outcome, and verification. For direct implementation, the main agent is the owner; do not spawn an implementer subagent. For delegated work, the implementer subagent is the owner. An approved spec may supply the contract, but direct implementation does not require a spec.

**Announce at start:** State whether implementation is direct or delegated, followed by code review.

## Start

1. Collect the settled **design**, **outcome**, and **verification** from the approved spec or direct user agreement. Confirm they still match the repository and governing instructions.
2. Use the agreed worktree and record the immutable review base.
3. For direct implementation, make the edits, run the settled and repository-required verification, and commit the candidate yourself. Record the candidate commit and tree, clean status, implementation commits, changed paths and scoped diff summary, exact verification commands and successful results, and any remaining work. Resolve remaining implementation or verification work before proceeding to Review. Handle review repairs as the implementation owner.
4. For delegated work, use the dispatch and reporting instructions below.

## Delegated implementation

1. Require exact native `agent_type="implementer"`; fail loudly rather than substituting a generic agent or harness.
2. Prompt with the absolute worktree, the spec path when present, the settled design, outcome, and verification, relevant repository context, and the shared-worktree warning. Give the implementer discretion over implementation approach, sequencing, tools, bounded helper delegation, tests, and commit structure. It remains accountable for the integrated result and evidence and does not delegate overall ownership or recursively invoke implementation or review workflows.
3. Dispatch exactly:

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

The implementation owner stops further implementation and reports when repository evidence shows that the settled design cannot achieve the outcome or verification, violates a material constraint, or requires a material contract change. It must not improvise a replacement design. Its report includes the evidence, impact, options worth discussing, and exact worktree state.

Take the reported material design, spec, or contract ambiguity to the user instead of trying to settle it through orchestrator technical review. Settle a correction or revise the design and any spec before resuming implementation; for delegated work, use `followup_task` with the same implementer. Ordinary implementation choices that preserve the settled design, outcome, and verification do not need orchestration.

## Record the result

For delegated work, when implementation completes, require its report to include the exact candidate commit and tree, clean status, implementation commits, changed paths and scoped diff summary, exact settled and repository-required verification commands and successful results, and explicit confirmation that no implementation or verification work remains. Record that evidence. Read-only candidate identity and status checks are allowed for coordination and review routing, but do not inspect or review the implementation diff, rerun its verification, or independently assess the implementation. Return a missing, contradictory, dirty, or failing report to the same implementer with `followup_task` rather than doing its technical work.

## Review

Invoke `code-review` once on the full immutable review-base-to-candidate diff, supplying the settled design, outcome, verification, candidate identity, implementation commits, and actual verification evidence. This is one review unit with at most two passes.

The exact reviewer owns independent technical inspection and the quality and actionability of its findings. For delegated work, the orchestrator does not reproduce or independently verify them. Route definite pass-one findings to the same implementation owner. If the owner disputes an actionable reviewer finding with concrete technical evidence, forward that evidence unchanged to the same reviewer with `followup_task` for clarification and reconsideration within pass one before any repair. This follow-up does not consume or become pass two; the reviewer remains the technical adjudicator and may uphold, revise, or withdraw the finding. Route an upheld finding to the same implementation owner for repair. If the reviewer concludes that resolution requires a material design, spec, or contract change, take that ambiguity to the user. After an actual repair, have the implementation owner rerun and report the settled and repository-required verification for the repaired clean candidate, record the new identity and evidence, and use the same reviewer for repair-only pass two. If pass two leaves a required repair or material uncertainty, stop, dispatch no third pass, and explain the blocker in ELI5 terms with the relevant context, evidence, impact, what the two passes tried, what remains unclear, and the user decision or external change needed.

When the review is clear, record its accepted commit and tree and ask for merge approval immediately. Schedule no implementation, repair, or verification work between acceptance and that request. Any later code or configuration change or failed check invalidates acceptance and returns the candidate to implementation; it does not reset an exhausted review budget without a new user decision.
