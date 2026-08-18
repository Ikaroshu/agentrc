---
name: adversarial-doc-review
description: Run a Codex-native adversarial review of a spec and/or implementation plan before implementation. Use the exact doc_reviewer role with GPT-5.6 Sol at xhigh effort for non-hard reviews or max effort for hard reviews, then verify its findings inline.
---

# Adversarial Doc Review

Use the configured `doc_reviewer` native subagent. Never substitute a generic agent or a CLI reviewer.

## Scope and tier

- Run from the main repository checkout and supply at least one explicit regular-file path: `--spec <path>` or `--plan <path>`.
- Resolve supplied paths to absolute paths. Treat any focus text as additional emphasis, not a narrowing of the review.
- Use `model="gpt-5.6-sol"` with `reasoning_effort="xhigh"` for a sufficiently specified established design and `reasoning_effort="max"` when interacting contracts, irreversibility, novel concurrency or security concerns, broad blast radius, or unresolved ambiguity materially complicate the review.
- Tell the user the tier and short rationale before dispatch.

## Dispatch

Build a concise task containing the absolute document paths and optional focus, then dispatch a fresh task with `agent_type="doc_reviewer"`, `fork_turns="none"`, the selected exact model and effort, and a clear unique task name.

If input is missing or empty, or the runtime cannot dispatch the exact role, fail loudly. Ordinary scheduling or transport failures may be retried with the same exact role; never weaken the role requirement.

## Verify and follow up

Wait for the completed review. Verify every finding against the documents and repository context before editing. Classify findings as confirmed, rejected with evidence, or needing clarification.

Use focused follow-up review when it materially improves confidence. Reuse the reviewer when practical or dispatch a fresh exact reviewer when the original task is unavailable. Keep the revised paths, relevant sections, and verified dispositions explicit. The main agent decides when the evidence is sufficient and reports residual risk.
