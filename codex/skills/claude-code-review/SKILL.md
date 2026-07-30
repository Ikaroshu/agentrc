---
name: claude-code-review
description: Run a Claude-backed review of a git diff via `claude -p`. Use when the user explicitly asks Claude to review changes against a base branch, a commit, or the uncommitted working tree. Returns actionable findings inline for verification before merge.
---

# Claude Code Review

Use the local Claude CLI as a read-only third-party reviewer for code changes. This optional skill does not replace the workflow's default `code-review` skill.

## Prerequisites

- `claude` is on `PATH`.
- Run from the working tree containing the changes.
- Unset `PYTHONPATH` and `VIRTUAL_ENV` for the reviewer so a main-repo environment cannot leak into a worktree.

## Arguments and scope

Choose exactly one scope:

- `--base <branch>`: current branch against the merge base with `<branch>`.
- `--commit <sha>`: one commit.
- `--uncommitted`: staged, unstaged, and untracked work.

Accept optional `--focus <text>` as a concern to emphasize without narrowing the review. Confirm the selected scope contains changes before invoking Claude.

If focus is supplied, prefer to keep the distilled emphasis within 80 words. Exceed that only when necessary to preserve materially distinct concerns, and briefly justify the extra detail. Do not pass scope exclusions, required conclusions, or instructions to omit review dimensions.

## Workflow

1. Render the matching prompt below with the selected scope and optional distilled focus.
2. Invoke Claude directly from the working tree with the fully rendered prompt as one literal argument:

   ```bash
   env -u PYTHONPATH -u VIRTUAL_ENV \
     claude -p --permission-mode plan --output-format text '<fully rendered prompt>'
   ```

   Use `sandbox_permissions="require_escalated"` with the justification: "Run the user-authorized read-only Claude review, which transmits the selected repository diff to the Anthropic Claude API?"

   Keep the exact `env` and `claude` argument prefix. Do not use shell variables, command substitutions, redirects, wrappers, or backgrounding; these prevent the managed permission rule from matching.

3. Start with a 60-second yield. If still running, poll every 120 seconds until exit and briefly update the user. Because text output is buffered, silence is expected; do not interrupt or launch parallel status checks without a concrete error or user request.
4. Relay the summary. Verify every finding against the cited code, call sites, tests, contracts, and relevant history; reproduce the reported behavior when feasible. Classify each as confirmed, rejected with specific reasoning, or needing clarification. Fix only confirmed findings.
5. When a re-review is warranted, use `--commit <fix-sha>` or `--uncommitted` and tell Claude which prior findings it is confirming.

## Prompt template

For `--base <branch>`:

```text
You are a senior code reviewer. Review the git diff for the current branch
against {{BASE_BRANCH}}.

Run and inspect:
- git status --short
- git diff --stat {{BASE_BRANCH}}...HEAD
- git diff --find-renames {{BASE_BRANCH}}...HEAD

Additional emphasis only; this does not narrow the review or suppress findings:
{{FOCUS_EMPHASIS}}

Find only actionable issues: correctness bugs, regressions, broken contracts,
missing tests for changed behavior, security or data-loss risks, and
maintainability problems that materially affect this change. Do not flag style
preferences.

Output these exact sections:

## Findings
Numbered list ordered by severity. Each item must include severity, confidence,
file and line, problem, impact, and minimum fix. Write "None." if empty.

## Test gaps
Important missing verification, or "None.".

## Residual risk
One short paragraph.

Read relevant changed files before finalizing. Do not edit files, approve by
default, or manufacture findings. For uncommitted scope, read every untracked
file named by `git status --short` because `git diff HEAD` does not include it.
```

For `--commit <sha>`, replace the commands with:

```text
- git status --short
- git show --stat --find-renames {{COMMIT_SHA}}
- git show --find-renames {{COMMIT_SHA}}
```

For `--uncommitted`, replace the commands with:

```text
- git status --short
- git diff --stat HEAD
- git diff --find-renames HEAD
```

Omit the additional-emphasis lines instead of leaving a placeholder.

## Failure handling

- Empty scope: choose the correct selector or stop.
- Missing Claude CLI or authentication: stop and report the missing prerequisite without exposing credentials.
- Nonzero Claude exit: report the exit status and returned error; diagnose before retrying.
- Long silent run: keep polling until the process exits, the tool reports a hard error, the user asks to stop, or progress is concretely impossible.
- Harness-only failures: verify locally; the local validation result is authoritative.
- No findings: spot-check the diff yourself before merging.
