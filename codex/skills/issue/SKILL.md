---
name: issue
description: Triage a GitHub issue against current code and discuss the verified problem and options. Use only when explicitly invoked or when the requested action is issue triage; do not activate merely because a prompt mentions an issue. Stop before writing a spec, plan, or code.
---

# Issue Triage Workflow

Verify an issue against current code, then discuss only genuine open decisions.

Use this workflow only when the user explicitly invokes it or asks to triage an issue. An issue reference within another request does not select this workflow.

**Announce at start:** "Running issue workflow."

This workflow is read-only and stops at discussion.

## Read

Fetch the issue with `gh`:

```bash
gh issue view <number> --comments
```

Accept a URL, `owner/repo#number`, or bare number; use `--repo` when needed. Read all comments, referenced issues, and relevant siblings, noting duplicates, closures, and sequencing.

## Verify

Treat the issue as a hypothesis, not a specification.

Ground everything in code you actually read:

- Open every cited location and test each material claim. Flag contradictions, incompatible proposals, and already-existing behavior.
- Read recent relevant history for stale or partial fixes.
- Map importers, callers, consumers, tests, and persisted-state risk; report source/test counts.
- Reproduce surprising claims before theorizing. Use subagents only for broad, clearly separable read-only searches.

## Report

Lead with a concise, beginner-friendly explanation of what happened, how the relevant components normally work together, and where and why that flow breaks. Do not make the user reconstruct the conclusion from jargon, file references, or an evidence dump. Then support it with compact `file:line` evidence covering:

- real symptom versus root cause, including conflated axes;
- enabling construct and blast radius with counts;
- current status: stale, subsumed, partly fixed, done, or remaining; and
- settled facts versus decisions that change the outcome.

State code/issue contradictions directly.

## Discuss

Discuss only outcome-changing decisions, one fork at a time.

- Give short labeled options with costs and a one-line recommendation.
- Make each proposed method, parameter, dependency, or abstraction an explicit decision; prefer the smallest root-cause fix and existing project conventions.
- Include valid non-code outcomes: document a limitation, rescope the issue, or close it when current code subsumes it.
- Offer separate deferred issues for out-of-scope findings. Unless asked otherwise, their bodies contain only problem, context, and `file:line` evidence.

Once aligned, stop and let the user choose specification, planning, or direct implementation.
