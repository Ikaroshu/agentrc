---
name: adversarial-doc-review
description: Run a Codex-native adversarial review of a spec and/or implementation plan before implementation. Use the exact doc_reviewer role with GPT-5.6 Sol at xhigh effort for non-hard reviews or max effort for hard reviews, then verify its findings inline.
---

# Adversarial Doc Review

Use the configured `doc_reviewer` native subagent. Never substitute a generic agent or a CLI reviewer.

## Validate input

- Run from the main repository cwd on the main branch, not from a worktree.
- Accept `--spec <path>`, `--plan <path>`, optional `--focus <text>`, and optional `--difficulty <non-hard|hard>`.
- Require at least one of `--spec` or `--plan`. Resolve supplied paths to absolute regular-file paths; never auto-discover substitutes.
- Treat focus as additional emphasis only. Do not use it to narrow scope, require a conclusion, or suppress review dimensions. Prefer at most 80 words unless preserving distinct concerns requires more.

## Select the tier

Honor an explicit difficulty. Otherwise classify the whole review:

- Non-hard: a sufficiently specified, established design with bounded interactions, including routine work involving APIs, schemas, migrations, concurrency, or security.
- Hard: interacting systems or contracts, difficult-to-reverse consequences, novel concurrency or security concerns, broad blast radius, or substantial unresolved ambiguity materially complicate the reasoning.

Use exactly:

- non-hard: `model="gpt-5.6-sol"`, `reasoning_effort="xhigh"`
- hard: `model="gpt-5.6-sol"`, `reasoning_effort="max"`

Tell the user the tier and a one-sentence rationale, then proceed unless the user objects or supplied an override.

## Start the native workflow

1. Create a logical-workflow counter with a three-completed-turn budget.
2. Prove from the active parent permission context that its local sandbox is `read-only`. A role default, reviewer instruction, or unknown permission state is not proof. If the parent is writable or unknown, stop and ask the user to start the review under read-only permissions.
3. Require the callable native spawn schema to accept the exact configured `agent_type="doc_reviewer"`. If it does not, stop and identify a fresh supported Codex runtime with the installed role as the prerequisite. Do not use a generic agent or CLI fallback.
4. Snapshot sibling task names. Choose the smallest positive ordinal unused by `doc_reviewer_workflow_<N>_stage_*` and reserve `doc_reviewer_workflow_<N>_stage_1`.
5. Build only this dynamic task, omitting absent fields:

   ```text
   Review these documents directly and return the completed review.
   Spec: {{ABSOLUTE_SPEC_PATH}}
   Plan: {{ABSOLUTE_PLAN_PATH}}
   Additional emphasis only; it does not narrow the review: {{FOCUS}}
   ```

6. Call `spawn_agent` with the dynamic task as `message`, the exact `agent_type="doc_reviewer"`, the reserved `task_name`, `fork_turns="none"`, `model="gpt-5.6-sol"`, and the selected `reasoning_effort`.
7. Retain the returned canonical target. Accepted exact-role dispatch is the role-selection evidence. Do not require unavailable parent-visible child metadata or treat reviewer self-report as proof of its role, model, effort, or sandbox.

If dispatch is ambiguous, compare the post-dispatch sibling snapshot with the reservation. Adopt only one newly created canonical target for that previously absent name. Retry once with the same reservation only after confirming that no target was created; otherwise stop rather than risk duplicate review work.

## Receive and verify the review

- Wait event-first for the canonical target. Do not narrate unchanged status, inspect partial reasoning, or relay intermediate output.
- Reject every approval or escalation request. If the reviewer attempts delegation, process or runner launch, local or external mutation, a mutating connector or MCP action, browser submission, or Computer Use, terminate the review as failed and report the attempted side effect.
- Treat a terminated or unavailable canonical target as a surfaced failure. Never switch transport.
- Relay only the completed review. Verify every finding against the documents and repository context before editing; classify it as confirmed, rejected with specific evidence, or needing clarification. Never blindly implement or silently skip feedback.
- If the reviewer reports no findings, spot-check the documents before continuing.

## Re-review

- Count each completed substantive final response. Failed dispatches, transport errors without completed output, waits, and partial messages do not consume a turn. Ask the user before a fourth completed turn.
- A materially new scope begins a disclosed new workflow with a fresh smallest-unused ordinal and three-turn budget. Replacements do not reset the current workflow's counter.
- Before every follow-up, again prove that the parent local sandbox is read-only.
- Reuse the canonical target with `followup_task`. Include a unique `[review-workflow: doc_reviewer_workflow_<N>; stage:<S>; turn:<T>]` marker, original finding identifiers, each verified disposition and evidence, exact revised paths and sections, and a request to check fixes and regressions under the original role contract.
- If follow-up acceptance is ambiguous, inspect only the canonical target. Resend the same marked follow-up once only after confirming non-acceptance; otherwise stop.
- Start `doc_reviewer_workflow_<N>_stage_<S+1>` only when the canonical target is confirmed unavailable or terminated, or the user requests a same-workflow tie-breaker. Preserve the remaining turn budget and give the replacement the original dynamic task plus workflow history. Reconcile an already-present next-stage name instead of skipping it.

Fail loudly for missing input, empty files, unsafe parent permissions, unavailable exact-role dispatch, ambiguous native dispatch, unavailable targets, or side-effect attempts.
