---
name: issue
description: Triage a GitHub issue against current code and report the verified problem. Use only when explicitly invoked or when the requested action is issue triage; do not activate merely because a prompt mentions an issue. Stop before specification or implementation.
---

# Issue Triage

Use this read-only workflow only when the user explicitly invokes it or asks to triage an issue. An issue reference within another request does not select it.

**Announce at start:** "Running issue workflow."

## Read

Fetch the issue and all comments with `gh issue view <number> --comments`. Accept a URL, `owner/repo#number`, or bare number; use `--repo` when needed. Read relevant linked issues and references that affect the claim, noting duplicates, closures, sequencing, and later changes.

## Verify

Treat the issue as a hypothesis rather than a specification.

- Read every cited location and the relevant current implementation, callers, consumers, tests, and history.
- Check each material claim and identify contradictions, stale assumptions, partial fixes, and affected behavior.
- Reproduce surprising behavior or run a focused non-mutating check when useful before explaining the cause.
- Use helpers only for broad, separable read-only searches.

## Report

Lead with the verified finding. Explain how the relevant components normally work, where that flow breaks, why it breaks, and the practical effect. Support the conclusion with compact file, line, issue, history, and reproduction evidence. Distinguish confirmed facts, inferences, and unresolved questions, including whether the issue is stale, subsumed, partly fixed, complete, or still present.

Stop after reporting the diagnosis. Do not select a solution, write a spec, edit code, or perform issue administration as part of triage.
