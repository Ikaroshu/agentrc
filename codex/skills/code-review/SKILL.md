---
name: code-review
description: Run a Codex-native review of a git diff before merge. Use the exact code_reviewer role with GPT-5.6 Sol at xhigh effort for non-hard reviews or max effort for hard reviews, then verify actionable findings before changing code.
---

# Code Review

Use the configured `code_reviewer` native subagent. Never substitute a generic agent or a CLI reviewer.

## Validate input and scope

- Run from the working tree containing the changes.
- Choose exactly one scope: `--base <branch>`, `--commit <sha>`, or `--uncommitted`.
- Accept optional `--focus <text>` and `--difficulty <non-hard|hard>`.
- Confirm the selected scope contains changes. Treat focus as additional emphasis only; do not use it to narrow scope, require a conclusion, or suppress review dimensions. Prefer at most 80 words unless preserving distinct concerns requires more.

## Select the tier

Honor an explicit difficulty. Otherwise classify the whole review:

- Non-hard: a bounded change that follows established patterns, including routine multi-file work or ordinary API, schema, migration, concurrency, or security changes.
- Hard: interacting systems or contracts, subtle state or concurrency behavior, security-critical logic, irreversible data changes, broad blast radius, or unfamiliar architecture materially complicate the reasoning.

Use exactly:

- non-hard: `model="gpt-5.6-sol"`, `reasoning_effort="xhigh"`
- hard: `model="gpt-5.6-sol"`, `reasoning_effort="max"`

Tell the user the tier and a one-sentence rationale, then proceed unless the user objects or supplied an override.

## Build the dynamic task

Use the matching scope block and append the optional focus line. Do not duplicate the role-owned rubric or output contract.

For `--base <branch>`:

```text
Review the current branch against {{BASE_BRANCH}}. Run and inspect:
- git status --short
- git diff --stat {{BASE_BRANCH}}...HEAD
- git diff --find-renames {{BASE_BRANCH}}...HEAD
Additional emphasis only; it does not narrow the review: {{FOCUS}}
```

For `--commit <sha>`:

```text
Review commit {{COMMIT_SHA}}. Run and inspect:
- git status --short
- git show --stat --find-renames {{COMMIT_SHA}}
- git show --find-renames {{COMMIT_SHA}}
Additional emphasis only; it does not narrow the review: {{FOCUS}}
```

For `--uncommitted`:

```text
Review staged, unstaged, and untracked work. Run and inspect:
- git status --short
- git diff --stat HEAD
- git diff --find-renames HEAD
Read every untracked file named by `git status --short`; `git diff HEAD` does not include them.
Additional emphasis only; it does not narrow the review: {{FOCUS}}
```

Omit the focus line when absent.

## Start the native workflow

1. Create a logical-workflow counter with a three-completed-turn budget.
2. Prove from the active parent permission context that its local sandbox is `read-only`. A role default, reviewer instruction, or unknown permission state is not proof. If the parent is writable or unknown, stop and ask the user to start the review under read-only permissions.
3. Require the callable native spawn schema to accept the exact configured `agent_type="code_reviewer"`. If it does not, stop and identify a fresh supported Codex runtime with the installed role as the prerequisite. Do not use a generic agent or CLI fallback.
4. Snapshot sibling task names. Choose the smallest positive ordinal unused by `code_reviewer_workflow_<N>_stage_*` and reserve `code_reviewer_workflow_<N>_stage_1`.
5. Call `spawn_agent` with the dynamic task as `message`, the exact `agent_type="code_reviewer"`, the reserved `task_name`, `fork_turns="none"`, `model="gpt-5.6-sol"`, and the selected `reasoning_effort`.
6. Retain the returned canonical target. Accepted exact-role dispatch is the role-selection evidence. Do not require unavailable parent-visible child metadata or treat reviewer self-report as proof of its role, model, effort, or sandbox.

If dispatch is ambiguous, compare the post-dispatch sibling snapshot with the reservation. Adopt only one newly created canonical target for that previously absent name. Retry once with the same reservation only after confirming that no target was created; otherwise stop rather than risk duplicate review work.

## Receive and verify the review

- Wait event-first for the canonical target. Do not narrate unchanged status, inspect partial reasoning, or relay intermediate output.
- Reject every approval or escalation request. If the reviewer attempts delegation, process or runner launch, local or external mutation, a mutating connector or MCP action, browser submission, or Computer Use, terminate the review as failed and report the attempted side effect.
- Treat a terminated or unavailable canonical target as a surfaced failure. Never switch transport.
- Relay only the completed review. Verify every finding against the cited code, call sites, tests, contracts, and relevant history; reproduce reported behavior when feasible. Classify it as confirmed, rejected with specific evidence, or needing clarification. Fix only confirmed findings.
- If the reviewer reports no findings, spot-check the diff before merging.

## Re-review

- Count each completed substantive final response. Failed dispatches, transport errors without completed output, waits, and partial messages do not consume a turn. Ask the user before a fourth completed turn.
- A materially new scope begins a disclosed new workflow with a fresh smallest-unused ordinal and three-turn budget. Replacements do not reset the current workflow's counter.
- Before every follow-up, again prove that the parent local sandbox is read-only.
- Reuse the canonical target with `followup_task`. Include a unique `[review-workflow: code_reviewer_workflow_<N>; stage:<S>; turn:<T>]` marker, original finding identifiers, each verified disposition and evidence, exact revised scope and changed files, and a request to check fixes and regressions under the original role contract.
- If follow-up acceptance is ambiguous, inspect only the canonical target. Resend the same marked follow-up once only after confirming non-acceptance; otherwise stop.
- Start `code_reviewer_workflow_<N>_stage_<S+1>` only when the canonical target is confirmed unavailable or terminated, or the user requests a same-workflow tie-breaker. Preserve the remaining turn budget and give the replacement the original dynamic task plus workflow history. Reconcile an already-present next-stage name instead of skipping it.

Fail loudly for an empty scope, unsafe parent permissions, unavailable exact-role dispatch, ambiguous native dispatch, unavailable targets, or side-effect attempts. Harness-only failures still require local verification.
