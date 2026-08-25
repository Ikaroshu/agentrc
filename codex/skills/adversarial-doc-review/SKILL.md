---
name: adversarial-doc-review
description: Adversarially review a spec or implementation plan before implementation with the exact native doc_reviewer role, then verify its findings.
---

# Adversarial Doc Review

Use the configured native `doc_reviewer`; never substitute a generic or CLI reviewer.

## Prepare

- From the main checkout, require at least one non-empty regular file, `--spec <path>` or `--plan <path>`, and resolve it to an absolute path. Focus text adds emphasis; it never narrows scope.
- Review the declared design plus the safety of out-of-scope boundaries, dependencies, and consequences. Reject detailed deferred implementation as scope leakage.
- Judge concerns by the primary outcome, evidence, reachable valid-use path, likelihood, impact, and handling cost. Competent callers follow documented contracts; misuse that fails loudly before harm needs no fix or deferral. Untrusted inputs and plausible security, data-loss, irreversible, or active-contract failures remain boundaries.
- Block only active requirements or plausible material failures worth handling now. Prefer a brief limitation and revisit condition, or a separately authorized issue, over disproportionate detail. Leave questions requiring working code to implementation and focused checks.
- Use `model="gpt-5.6-sol"` with `reasoning_effort="xhigh"` for an established, sufficiently specified design; use `reasoning_effort="max"` for materially difficult interacting contracts, irreversibility, concurrency, security, blast radius, or ambiguity.
- Tell the user the tier and short rationale before dispatch.

## Dispatch

Dispatch a fresh, uniquely named task containing a stable review-unit identity, pass number, absolute paths, and optional focus with `agent_type="doc_reviewer"`, `fork_turns="none"`, and the selected exact model and effort. Start at pass one; a follow-up is pass two for the same unit even when the reviewer is replaced.

If input is missing or empty, or the runtime cannot dispatch the exact role, fail loudly. Ordinary scheduling or transport failures may be retried with the same exact role; never weaken the role requirement.

## Resolve

Wait for completion, then verify every finding against the documents and repository. Classify it as confirmed blocking, accepted non-blocking deferral, rejected with evidence, or needing clarification before editing.

Treat the supplied spec and plan as one document review unit with a hard budget of two completed review passes, including the initial review. Repairs, replacement reviewers, and follow-up turns do not reset the count. Pass one is the default; advance immediately if it is clear, and use pass two only when a repair materially changes the contract or an unresolved blocker needs confirmation. Reuse the reviewer when practical, otherwise use a fresh exact reviewer. Non-blocking suggestions, documented limitations, and implementation-only questions do not keep review open.

If pass two is clear, move to implementation approval. If a confirmed blocker or material uncertainty remains, stop the review workflow and do not dispatch a third review. Explain the blocker in ELI5 terms with the relevant context, evidence, impact, what the two passes tried, what remains unclear, and the user decision or external change needed. Record revised sections, review counts, dispositions, and residual risk.
