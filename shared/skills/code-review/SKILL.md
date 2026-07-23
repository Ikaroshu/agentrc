---
name: code-review
description: Run a Codex-backed review of a git diff before merge. Routes non-hard reviews to GPT-5.6 Sol at high effort and hard reviews to GPT-5.6 Sol at max effort, then returns actionable findings for verification.
---

# Code Review

Use a nested, read-only Codex CLI session as a neutral third-party code reviewer. Keep the reviewer's normal Codex tools, MCP servers, plugins, and repository context available; disable only the two workflow review skills in the nested session to prevent recursive review invocation.

## Prerequisites

- Require `codex` on `PATH` with working authentication.
- Run from the working tree containing the changes.
- Unset `PYTHONPATH` and `VIRTUAL_ENV` for the reviewer so a main-repo environment cannot leak into a worktree.

## Arguments and scope

Choose exactly one scope:

- `--base <branch>`: current branch against the merge base with `<branch>`.
- `--commit <sha>`: one commit.
- `--uncommitted`: staged, unstaged, and untracked work.

Accept optional `--focus <text>` and `--difficulty <non-hard|hard>`. Confirm the selected scope contains changes before invoking Codex.

## Select the review tier

Honor an explicit `--difficulty`. Otherwise classify the diff and affected contracts:

- **Non-hard / high effort**: localized or familiar work whose contracts and blast radius remain bounded, including ordinary multi-file changes.
- **Hard / max effort**: architecture or cross-system work; public APIs or schemas; migrations; concurrency; security; data-loss risk; high blast radius; or substantial ambiguity.

Classify as hard when any hard signal materially affects the change. Tell the user the selected tier and one-sentence rationale, then proceed immediately unless the user objects or supplied an override.

Use this exact mapping:

- non-hard: `gpt-5.6-sol`, `high`
- hard: `gpt-5.6-sol`, `max`

## Workflow

1. Render the matching prompt below with the selected scope, optional focus, and tier.
2. Resolve the absolute paths of this skill and the sibling `adversarial-doc-review/SKILL.md`. Render them into the `skills.config` override so the nested Codex session cannot invoke either workflow review skill recursively.
3. Invoke Codex directly from the working tree with the fully rendered prompt as one literal argument, substituting only the effort, the two skill paths, and the prompt:

   ```bash
   env -u PYTHONPATH -u VIRTUAL_ENV \
     codex exec \
     --ephemeral \
     --model gpt-5.6-sol \
     --config 'model_reasoning_effort="{{EFFORT}}"' \
     --sandbox read-only \
     --color never \
     --config 'skills.config=[{path="{{DOC_SKILL_PATH}}",enabled=false},{path="{{CODE_SKILL_PATH}}",enabled=false}]' \
     '<fully rendered prompt>'
   ```

   Keep this argument order. Do not add `--ignore-user-config`, `--ignore-rules`, tool restrictions, MCP restrictions, shell wrappers, redirects, or backgrounding. The nested reviewer should inherit the normal Codex tool surface and local configuration while remaining filesystem read-only.

   When the caller is Codex, run with `sandbox_permissions="require_escalated"` and the justification: "Run the user-authorized nested read-only Codex code review?" The managed `codex-review.rules` rule records this exact read-only command prefix. Other callers should use their normal mechanism for running the command.

4. Start with a 30-second yield. If the process remains active, poll every 60 seconds until it exits. Do not treat elapsed time or a quiet interval as a hang, impose an arbitrary timeout, interrupt it, inspect its PID, or launch parallel status checks. Give the user brief progress updates while waiting.
5. Relay the review summary. Verify each finding against the cited code, call sites, tests, contracts, and relevant history; reproduce the reported behavior when feasible. Classify it as confirmed, rejected with specific reasoning, or needing clarification. Fix only confirmed findings.
6. When a re-review is warranted, use `--commit <fix-sha>` or `--uncommitted` and tell the reviewer which prior findings it is confirming.

## Prompt template

For `--base <branch>`:

```text
You are the inner reviewer process for a code review. Review tier: {{TIER}}.
Perform the review directly. Do not invoke any review skill or launch another
Codex, Claude, or OMP process.

Review the current branch against {{BASE_BRANCH}}. Run and inspect:
- git status --short
- git diff --stat {{BASE_BRANCH}}...HEAD
- git diff --find-renames {{BASE_BRANCH}}...HEAD

Use your available read-only tools to inspect changed files, call sites, tests,
contracts, and relevant history. Do not edit files.

{{FOCUS_BLOCK}}

Find only actionable issues: correctness bugs, regressions, broken contracts,
missing tests for changed behavior, security or data-loss risks, and
maintainability problems that materially affect this change. Do not flag style
preferences or claim tests passed unless you actually ran them successfully.

Output these exact sections:

## Findings
Numbered list ordered by severity. Each item must include severity, confidence,
file and line, problem, impact, and minimum fix. Write "None." if empty.

## Test gaps
Important missing verification, or "None.".

## Residual risk
One short paragraph.

Read relevant changed files before finalizing. Do not approve by default or
manufacture findings.
```

For `--commit <sha>`, replace the scope and commands with:

```text
Review commit {{COMMIT_SHA}}. Run and inspect:
- git status --short
- git show --stat --find-renames {{COMMIT_SHA}}
- git show --find-renames {{COMMIT_SHA}}
```

For `--uncommitted`, replace the scope and commands with:

```text
Review staged, unstaged, and untracked work. Run and inspect:
- git status --short
- git diff --stat HEAD
- git diff --find-renames HEAD

Read every untracked file named by `git status --short`; `git diff HEAD` does not include them.
```

Omit the focus block instead of leaving a placeholder.

## Failure handling

- Empty scope: choose the correct selector or stop.
- Missing Codex CLI or authentication: stop and report the missing prerequisite without exposing credentials.
- Nonzero Codex exit: report the exit status and returned error; diagnose before retrying.
- Long run: keep polling until exit, a concrete hard error, impossible progress, or a user request to stop.
- Harness-only failures: verify locally; local validation remains authoritative.
- No findings: spot-check the diff yourself before merging.
