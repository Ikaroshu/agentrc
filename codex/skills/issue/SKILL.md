---
name: issue
description: Triage a GitHub issue against current code and recommend a next step. Use for explicit invocation or a triage request, not an issue mention.
---

# Issue Triage

Use this read-only workflow only when the user explicitly invokes it or asks to triage an issue. An issue reference within another request does not select it.

## Read

Fetch the issue and all comments with `gh issue view <number> --comments`. Accept a URL, `owner/repo#number`, or bare number; use `--repo` when needed. Read relevant linked issues and references that affect the claim, noting duplicates, closures, sequencing, and later changes.

## Verify

Treat the issue as a hypothesis rather than a specification.

- Read every cited location and the relevant current implementation, callers, consumers, tests, and history.
- Check each material claim and identify contradictions, stale assumptions, partial fixes, and affected behavior.
- Reproduce surprising behavior or run a focused non-mutating check when useful before explaining the cause.
- Use helpers only for broad, separable read-only searches.

## Report

Start by explaining the issue's reported problem or request and why it matters, assuming the user has not read it. Use plain language or a visualization when it makes the problem clearer; distinguish the issue's claims from verified facts.

Then present the verified diagnosis. Explain how the relevant components normally work, where that flow breaks, why it breaks, and the practical effect. Support the conclusion with compact file, line, issue, history, and reproduction evidence. Distinguish confirmed facts, inferences, and unresolved questions, including whether the issue is stale, subsumed, partly fixed, complete, or still present.

End with a short recommendation for the next step and why it follows from the diagnosis. Keep it advisory: do not write a spec, edit code, or perform issue administration as part of triage.
