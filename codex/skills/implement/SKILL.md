---
name: implement
description: Deliver substantive or complex work through one exact xhigh implementer; allow the main agent to complete simple changes, then send the verified candidate through independent code review.
---

# Implement

Keep one persistent owner for the settled design, outcome, and verification. Use the implementer subagent for substantive or complex work; keep simple work with straightforward design and verification with the main agent. A settled design or absence of a spec does not itself make work simple.

**Announce at start:** State whether implementation is direct or delegated, followed by code review.

## Start

1. Collect the approved **design**, **outcome**, and **verification** from the spec or user agreement. Confirm they still match the repository and governing instructions.
2. Use the agreed worktree and record the immutable review base.
3. For direct work, the main agent owns editing, integration, verification, commits, and review repairs. Complete and record the same candidate evidence required below.
4. For delegated work, follow the dispatch instructions below. The implementer owns editing, integration, verification, commits, and review repairs; the orchestrator coordinates its recorded result.

## Delegated implementation

Require the exact native role and dispatch one owner:

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

The prompt supplies the absolute worktree, immutable review base, spec path when present, settled design, outcome, verification, relevant repository context, authorization boundaries, and shared-worktree warning. Give the implementer discretion over implementation approach, sequencing, tools, bounded helpers, tests, and coherent commits. It must not delegate overall ownership or recursively invoke implementation or review workflows.

Block until the requested implementer returns. Handle unrelated events and resume; do not inspect partial Git state while it or its helpers work.

## Design blockers

The implementation owner stops when repository evidence shows that the settled design cannot achieve the outcome or verification, violates a material constraint, or requires a material contract change. It reports the evidence, impact, options worth discussing, and exact worktree state without inventing a replacement design. Take that decision to the user. For delegated work, resume the same owner with `followup_task` after the contract is settled.

## Record the candidate

The owner reports the exact candidate commit and tree, clean status, implementation commits, changed paths and scoped diff summary, exact successful settled and repository-required verification, remaining risks or blockers, collaborator integration, and whether implementation or verification work remains.

For delegated work, record the report and use only read-only candidate identity and status checks for coordination. Return a missing, contradictory, dirty, or failing report to the same implementer with `followup_task`; do not inspect or review its diff, rerun its checks, or do its technical work.

## Review

Invoke `code-review` once on the full immutable review-base-to-candidate diff with the approved contract and recorded candidate evidence. Route review repairs to the same implementation owner. The owner reruns the required verification and reports the repaired clean candidate; for delegated work, resume it with `followup_task`. The `code-review` skill owns review adjudication, pass limits, and the merge-approval gate.
