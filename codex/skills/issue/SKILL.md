---
name: issue
description: Assess a GitHub issue and carry requested resolution work through closure. Use for explicit invocation, triage, or a request to work on an issue, not a background issue mention.
---

# Issue Workflow

Distinguish investigation from resolution. An explicit triage or investigation-only request, including invoking this skill without asking for a fix, stays read-only. When the user asks to work on, fix, or resolve the issue, or approves proceeding after triage, own the issue through the applicable development workflow, necessary operational follow-ups, verification, and closure. A background issue reference does not select this workflow.

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

For investigation-only scope, end with a short recommendation and keep it advisory: do not write a spec, edit code, or administer the issue. For resolution scope, continue the applicable development workflow; the assessment is a progress update, not the end of the task.

## Finish the issue

Carry the issue URL and unresolved outcome through implementation and merge even when branch names or commit messages omit it. Include necessary recovery, reruns, and verification in the work; do not stop at a merged fix when the reported failure still needs follow-up. Respect required approval gates, include known consequential follow-ups in the concrete approval request, and continue the approved sequence without another prompt.

When the reported problem is resolved, post concise resolution evidence and the relevant commit or recovery result, close the issue, and verify GitHub reports it closed. A request to resolve the issue authorizes this follow-up; no separate closure approval is needed. If an actual blocker prevents resolution, report the exact blocker and next action and leave the issue open. Never claim completion while required work remains.
