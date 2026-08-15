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
2. Require the callable native spawn schema to accept the exact configured `agent_type="doc_reviewer"`. If it does not, stop and identify a fresh supported Codex runtime with the installed role as the prerequisite. Do not use a generic agent or CLI fallback.
3. Generate one task name as `doc_reviewer_review_<yyyymmddthhmmssz>_<six lowercase hex characters>`, using the current UTC time and a random hexadecimal suffix. Use only lowercase letters, digits, and underscores. Do not list sibling tasks before or after dispatch.
4. Build only this dynamic task, omitting absent fields:

   ```text
   Review these documents directly and return the completed review.
   Spec: {{ABSOLUTE_SPEC_PATH}}
   Plan: {{ABSOLUTE_PLAN_PATH}}
   Additional emphasis only; it does not narrow the review: {{FOCUS}}
   ```

5. Call `spawn_agent` once with the dynamic task as `message`, the exact `agent_type="doc_reviewer"`, the generated `task_name`, `fork_turns="none"`, `model="gpt-5.6-sol"`, and the selected `reasoning_effort`.
6. Retain the canonical target returned by the successful call. Accepted exact-role dispatch is the role-selection evidence. Do not require unavailable parent-visible child metadata or treat reviewer self-report as proof of its role, model, or effort. If the platform rejects the task name, dispatch fails, or no canonical target is returned, report the failure directly and make no second spawn call.

## Receive and verify the review

- Wait passively and event-first for the canonical target's completed response. Do not poll task status, narrate unchanged status, inspect partial reasoning, or relay intermediate output.
- Reject every sandbox approval or escalation request. If the reviewer attempts delegation, process or runner launch, or a local or external mutation that the main agent did not explicitly authorize in a follow-up, terminate the review as failed and report the attempted side effect.
- Treat a terminated or unavailable canonical target as a surfaced failure.
- Relay only the completed review. Verify every finding against the documents and repository context before editing; classify it as confirmed, rejected with specific evidence, or needing clarification. Never blindly implement or silently skip feedback.
- If the reviewer reports no findings, spot-check the documents before continuing.

## Re-review

- Count each completed substantive final response. Failed dispatches, transport errors without completed output, waits, and partial messages do not consume a turn. Ask the user before a fourth completed turn.
- A materially new scope begins a disclosed new workflow with its own three-turn budget. A user-authorized fresh start for unchanged scope keeps the original workflow's completed-turn count.
- Reuse only the original canonical target with one `followup_task` call per re-review. Keep the follow-up concise and include the original finding identifiers, each verified disposition and evidence, the exact revised paths and sections, and a request to check fixes and regressions under the original role contract.
- If the canonical target or follow-up is unavailable, report the failure directly. Do not resend the follow-up or start another reviewer unless the user explicitly authorizes a fresh start.

Fail loudly for missing input, empty files, unavailable exact-role dispatch, rejected task names, unavailable canonical targets or follow-ups, or unauthorized side-effect attempts.
