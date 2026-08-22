---
name: adversarial-doc-review
description: Run a Codex-native adversarial review of a spec and/or implementation plan before implementation. Use the exact doc_reviewer role with GPT-5.6 Sol at xhigh effort for non-hard reviews or max effort for hard reviews, then verify its findings inline.
---

# Adversarial Doc Review

Use the configured `doc_reviewer` native subagent. Never substitute a generic agent or a CLI reviewer.

## Scope and tier

- Run from the main repository checkout and supply at least one explicit regular-file path: `--spec <path>` or `--plan <path>`.
- Resolve supplied paths to absolute paths. Treat any focus text as additional emphasis, not a narrowing of the review.
- Review the declared in-scope design and verify that out-of-scope boundaries, dependencies, and consequences are safe and complete. Do not expand or perfect deferred work; report detailed deferred implementation as scope leakage that should be removed or split before review continues.
- Judge every proposed edge-case fix against the primary functional outcome, evidence, likelihood, impact, and implementation cost. Treat it as blocking only when an active requirement or plausible material failure requires handling now. When the handling would add disproportionate code, logic, or plan detail, prefer a brief documented limitation and revisit condition or, when separately authorized, a follow-up issue.
- Document review cannot prove behavior that requires working code or execution. When the primary path is sufficiently specified, preserve the relevant assumption or residual risk and let implementation plus focused checks produce the evidence instead of demanding more speculative plan detail.
- Use `model="gpt-5.6-sol"` with `reasoning_effort="xhigh"` for a sufficiently specified established design and `reasoning_effort="max"` when interacting contracts, irreversibility, novel concurrency or security concerns, broad blast radius, or unresolved ambiguity materially complicate the review.
- Tell the user the tier and short rationale before dispatch.

## Dispatch

Build a concise task containing the absolute document paths and optional focus, then dispatch a fresh task with `agent_type="doc_reviewer"`, `fork_turns="none"`, the selected exact model and effort, and a clear unique task name.

If input is missing or empty, or the runtime cannot dispatch the exact role, fail loudly. Ordinary scheduling or transport failures may be retried with the same exact role; never weaken the role requirement.

## Verify and follow up

Wait for the completed review. Verify every finding against the documents and repository context before editing. Classify findings as confirmed blocking, accepted non-blocking deferral, rejected with evidence, or needing clarification.

One complete review is the default. Use focused follow-up review only when a repair materially changes the contract or an unresolved blocking finding requires confirmation. Reuse the reviewer when practical or dispatch a fresh exact reviewer when the original task is unavailable. Non-blocking suggestions, documented limitations, and questions answerable only by implementation do not keep the plan in review. Keep the revised paths, relevant sections, and verified dispositions explicit; once confirmed blocking findings are resolved, report residual risk and move to the implementation approval gate.
