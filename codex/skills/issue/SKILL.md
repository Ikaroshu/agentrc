---
name: issue
description: Triage a GitHub issue against current code and recommend a next step. Use for explicit invocation or a triage request, not an issue mention.
---

# Issue Triage

Use this read-only workflow only when the user explicitly invokes it or asks to triage an issue. An issue reference within another request does not select it.

## Read

Fetch the issue and all comments with `gh issue view <number> --comments`. Accept a URL, `owner/repo#number`, or bare number; use `--repo` when needed. Read relevant linked issues and references that affect the assessment, noting duplicates, closures, sequencing, and later changes. Identify whether the issue reports a bug, requests a feature, proposes refactoring, or combines these.

## Verify

Verify the issue's factual claims and assumptions against current code while preserving the user's stated goal. A feature or refactoring request does not imply existing behavior is broken, and a proposed approach is not automatically an implementation specification.

- Read every cited location and the relevant current implementation, callers, consumers, tests, and history.
- Check each material claim and identify contradictions, stale assumptions, work already completed, and affected behavior or structure.
- Reproduce reported bugs or run a focused non-mutating check when useful to assess current behavior, capabilities, or structure.
- Use helpers only for broad, separable read-only searches.

## Report

Start by explaining the issue's reported behavior or proposed change, intended outcome, and motivation, assuming the user has not read it. Use plain language or a visualization when it makes the issue clearer; distinguish the issue's claims and goals from verified facts.

Then present an evidence-based assessment of the current state relative to the issue's goal. For a bug, explain the expected and actual behavior, any verified cause, and practical effect. For a feature or refactoring request, explain the relevant existing capabilities or structure, what would change, and material gaps, constraints, or tradeoffs. Support the conclusion with compact file, line, issue, history, and focused-check evidence. Distinguish confirmed facts, inferences, and unresolved questions; describe status in terms appropriate to the issue, such as a bug still present, a capability already supported, or a refactoring goal partly achieved.

End with a short recommendation for the next step and why it follows from the assessment. Keep it advisory: do not write a spec, edit code, or perform issue administration as part of triage.
