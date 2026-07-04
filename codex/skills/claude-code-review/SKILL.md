---
name: claude-code-review
description: Run a Claude-backed code review of a git diff during implementation via `claude -p`. Use after implementing a feature or phase, or before merging, to get an independent reviewer on changes against a base branch, a commit, or the uncommitted working tree. Returns the review summary inline so findings can be addressed in the same turn.
---

# Claude Code Review

Drives the local Claude CLI in non-interactive mode (`claude -p`) to review a git diff and return findings inline. This is the Codex-side counterpart to Claude's `codex-code-review` skill.

## When to use

- After finishing a phase or chunk of implementation, to get an independent reviewer before moving on.
- Before merging a branch, as a second pair of eyes on the full diff vs the base branch.
- When the user says "claude review", "run claude on this", "review phase N", etc.

For reviewing design docs before any code is written, use `adversarial-doc-review`.

## Prerequisites

- `claude` CLI on PATH. Verify with `command -v claude` if uncertain.
- Run from the working tree that **contains the changes**. For branch work, that is the worktree on the feature branch, not the main repo.
- **Inside a worktree, `unset PYTHONPATH VIRTUAL_ENV` first.** direnv can leak the main-repo venv/path into worktrees; without this, review-time commands may resolve against the wrong environment.

## Choosing the review scope

Choose exactly one scope:

- **`--base <branch>`** - review the full diff of the current branch against `<branch>`, such as `main`.
- **`--commit <sha>`** - review only the changes introduced by one commit.
- **`--uncommitted`** - review staged, unstaged, and untracked changes in the working tree.

Optional **`--focus <text>`** can be included in the prompt for any scope.

## Workflow

1. **Pick the scope** based on what is being reviewed. Confirm there is actually a diff for that scope; an empty diff yields nothing useful to review.

2. **Build the review prompt.** Use the template below. Substitute the selected scope and include any focus text.

3. **Run Claude.** Invoke the CLI directly, no backgrounding. Substitute the working tree path, then pass the fully rendered prompt as one shell-escaped literal argument. Do not store the prompt in a shell variable because that prevents Codex's narrow command rule from matching:

   ```bash
   env -u PYTHONPATH -u VIRTUAL_ENV \
     claude -p --permission-mode plan --output-format text '<fully rendered prompt>'
   ```

   - `-p` is required: it runs Claude non-interactively and prints the result.
   - `--permission-mode plan` is required: the reviewer must not edit files.
   - `--output-format text` keeps the captured answer easy to relay.
   - Set the tool call's working directory to the worktree. Keep the `env` and `claude` argument prefix exact so the review uses the worktree environment and matches the managed rule. Shell variables, command substitutions, redirects, and wrapper scripts prevent the rule from matching.
   - Set the initial command yield to 30 seconds. If the command is still running, poll its session with an empty `write_stdin` call that waits 60 seconds.
   - A silent reviewer is normal. Do not poll faster than once per 60 seconds, inspect its PID, or launch parallel status checks. Each extra check adds tool and context overhead without making the review finish sooner.
   - Read only newly returned output. With text output, Claude prints the review result directly; temporary output and log files are unnecessary.
   - Do **not** background the call. It must finish this turn so findings can be acted on.

4. **Relay and handle findings.** Show the user the reviewer's summary. For each finding, before acting:
   1. **Verify it's real** — the reviewer can misread context or hit a harness artifact (see failure modes). Confirm the problem actually exists in the code before changing anything.
   2. **Engage on the merits** — no reflexive agreement; assess the technical substance.
   3. **Then fix or push back** — fix verified findings in the working tree; for wrong ones, push back with specific reasoning. Never silently ignore, never blindly implement.

5. **Re-review fixes when needed.** After fixing, re-run with `--commit <fix-sha>` or `--uncommitted` to confirm the specific issues are resolved. Tell the reviewer which prior findings it is confirming so it does not re-raise resolved items.

## Prompt template

For `--base <branch>`:

```text
You are a senior code reviewer. Review the git diff for the current branch
against {{BASE_BRANCH}}.

Run and inspect:
- git status --short
- git diff --stat {{BASE_BRANCH}}...HEAD
- git diff {{BASE_BRANCH}}...HEAD

{{FOCUS_BLOCK}}

Find only actionable issues: correctness bugs, regressions, broken contracts,
missing tests for changed behavior, security/data-loss risks, or maintainability
problems that materially affect this change. Do not flag style preferences.

Output format:

## Findings
Numbered list ordered by severity. Each item must include file path and line or
section reference, the problem, why it matters, and the minimum fix. If none,
write "None.".

## Test gaps
Mention important missing verification, or "None.".

## Residual risk
One short paragraph.

Rules:
- Read the relevant changed files before finalizing findings.
- Do not edit files.
- Do not approve by default. If there are no actionable findings, say so.
```

For `--commit <sha>`, replace the diff commands with:

```text
- git status --short
- git show --stat {{COMMIT_SHA}}
- git show --find-renames {{COMMIT_SHA}}
```

For `--uncommitted`, replace the diff commands with:

```text
- git status --short
- git diff --stat
- git diff
- git diff --stat --staged
- git diff --staged
```

## Failure modes & guidance

- **Nothing to review.** The selected scope has no diff. Pick the right selector.
- **Claude hangs.** Kill the stuck process and report. Do not retry blindly or reintroduce a shell wrapper; diagnose the direct invocation first.
- **Reviewer tries to edit files.** It must not; `--permission-mode plan` plus the prompt make the review read-only.
- **Reviewer reports harness-only failures.** If its sandbox or permission mode blocks a command, note that as a review harness artifact and rely on local verification as authoritative.
- **No findings.** Trust but spot-check the diff yourself before merging.
