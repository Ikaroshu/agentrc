---
name: adversarial-doc-review
description: Review an implementation-ready spec before implementation with the exact native doc_reviewer role and coordinate its findings.
---

# Adversarial Doc Review

Use the configured native `doc_reviewer`; never substitute a generic or CLI reviewer. The main agent owns the spec and review coordination; the reviewer owns technical inspection and findings.

## Prepare

- From the main checkout, require one non-empty regular file with `--spec <path>` and resolve it to an absolute path.
- Review the outcome, design, and verification as the complete contract. Focus text adds emphasis without narrowing scope.
- Use `model="gpt-5.6-sol"` with `reasoning_effort="xhigh"` for an established, sufficiently specified design; use `reasoning_effort="max"` for materially difficult interacting contracts, irreversibility, concurrency, security, blast radius, or ambiguity.
- Tell the user the tier and short rationale before dispatch.

## Dispatch

Dispatch a fresh, uniquely named task containing a stable review-unit identity, pass number, absolute paths, the complete contract, relevant repository context, and optional focus with `agent_type="doc_reviewer"`, `fork_turns="none"`, and the selected exact model and effort. Start at pass one; a follow-up is pass two for the same unit even when the reviewer is replaced.

If input is missing or empty, or the runtime cannot dispatch the exact role, fail loudly. Ordinary scheduling or transport failures may be retried with the same exact role.

## Resolve

Wait for completion without polling. Route definite blocking findings to the spec owner. If the owner disputes a finding with concrete evidence, send that evidence unchanged to the same reviewer for clarification within the current pass. The reviewer remains the technical adjudicator and may uphold, revise, or withdraw the finding. Resolve upheld findings in the spec; take a material goal or contract change to the user.

Treat the supplied spec as one review unit with at most two completed passes. Repairs, replacement reviewers, and follow-up turns do not reset the count. Clarification stays within the current pass. Use pass two only when a repair materially changes the contract or an unresolved blocker needs confirmation. Reuse the reviewer when practical. Non-blocking suggestions, documented limitations, and implementation-only questions do not keep review open.

When review is clear, ask for implementation approval. If pass two leaves a blocker or material uncertainty, stop without a third review and report it using the global communication guidance. Record review counts, dispositions, and residual risk.
