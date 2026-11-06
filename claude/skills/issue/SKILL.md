---
name: issue
description: Assesses a GitHub issue and, when asked to work on it, carries the fix through closure. Use for explicit invocation, triage, or a request to work on an issue, not a background mention of one.
---

# Issue Workflow

Invoking this skill without asking for a fix, or asking only for triage or investigation, is assessment only: end with an advisory recommendation, and do not write a spec, change the repository, or administer the issue. A request to work on, fix, or resolve the issue, or approval after triage, means owning it through the development workflow, any recovery or reruns, verification, and closure.

## Assess

Read all comments and any linked issues that affect the assessment. Treat the issue's claims, assumptions, and proposed approach as unverified: check them against current code, callers, and history, note stale claims and work already done, and reproduce a reported bug or run whatever helps, including live provider calls and scratch scripts, as long as it leaves tracked files and Git history unchanged and does nothing irreversible. A feature or refactoring request does not imply existing behavior is broken.

## Report

Assume the user has not read the issue. First explain what it reports or proposes, the intended outcome, and why. Then assess the current state against that goal, with compact file, line, and check evidence, in terms that fit the issue: a bug still present, a capability already supported, a refactoring goal partly achieved.

## Close

Carry the issue URL and unresolved outcome through implementation and merge even when branch names and commit messages omit it, and include known follow-ups in any approval request. Once the reported problem is resolved, post the evidence and relevant commit or recovery result, close the issue, and confirm GitHub shows it closed, including when PR closing keywords should have closed it. If a blocker prevents resolution, report it with the next action and leave the issue open.
