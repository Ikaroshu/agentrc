---
name: codex-code-review
description: Run a Codex-backed code review of a git diff during implementation via `codex exec review`. Use after implementing a feature/phase or before merging, to get an independent reviewer on the changes against a base branch, a commit, or the uncommitted working tree. Returns the review summary inline so findings can be addressed in the same turn.
---

# Codex Code Review

Drives the local Codex CLI's purpose-built review subcommand (`codex exec review`) to review a code diff and return findings inline. This is the code-diff counterpart to the `adversarial-doc-review` skill (which reviews spec/plan **documents** before implementation). Use this one for **code**, during or after implementation.

## When to use

- After finishing a phase / chunk of implementation, to get an independent reviewer before moving on.
- Before merging a branch, as a second pair of eyes on the full diff vs the base branch.
- When the user says "codex review", "run codex on this", "review phase N", etc.

For Claude-native review instead of Codex, use `/code-review`. For reviewing design docs before any code is written, use `adversarial-doc-review`.

## Prerequisites

- `codex` CLI on PATH. Verify with `command -v codex` if uncertain.
- Run from the working tree that **contains the changes** — for branch work that is the worktree on the feature branch, not the main repo.
- **Inside a worktree, `unset PYTHONPATH VIRTUAL_ENV` first.** direnv leaks the main-repo venv/path into worktrees; without this the reviewer's tool calls (e.g. `uv run pyright`) resolve against the wrong environment.

> **CLI-version note (verified codex-cli 0.130.0).** The `review` subcommand's flags differ from plain `codex exec`. It has **no `-o`/`--output-last-message`, no `--color`, and no `--json`** — the review summary is written to **stdout** only, so capture stdout and read its tail. And a trailing **`[PROMPT]` conflicts with every scope selector** (`--base`/`--commit`/`--uncommitted`): you cannot focus a *scoped* review with a custom instruction. If a documented flag below errors, run `codex exec review --help` and adapt.

## Choosing the review scope

`codex exec review` takes exactly one scope selector:

- **`--base <branch>`** — review the full diff of the current branch against `<branch>` (e.g. `--base main`). Use for "review this feature/phase" and pre-merge review.
- **`--commit <sha>`** — review only the changes introduced by one commit. Use to re-review a fix commit.
- **`--uncommitted`** — review staged + unstaged + untracked changes in the working tree. Use for work not yet committed.

A trailing **`[PROMPT]`** (custom focus instruction) is accepted **only with no scope selector** — `codex exec review "Weight X heavily."` reviews the default scope. It **cannot** be combined with `--base`/`--commit`/`--uncommitted` (clap rejects it: "the argument '--base <BRANCH>' cannot be used with '[PROMPT]'"). So for a scoped review you get Codex's default review behavior, unfocused. If you need both a specific scope *and* a focus, bake the focus into the diff selection (e.g. review just the relevant commit) and rely on the default behavior.

## Workflow

1. **Pick the scope** (`--base` / `--commit` / `--uncommitted`) based on what is being reviewed. Confirm there is actually a diff for that scope — an empty diff yields "nothing to review".

2. **Run Codex.** Single Bash call, no backgrounding. Substitute the scope selector; `cd` into the worktree first if reviewing branch work. The `review` subcommand has no output-file flag, so capture **stdout** to a file and read its tail:

   ```bash
   cd /path/to/worktree        # the tree that holds the changes
   unset PYTHONPATH VIRTUAL_ENV  # only needed inside a worktree
   OUT=$(mktemp /tmp/codex_code_review.XXXX.txt)
   codex exec review \
     --skip-git-repo-check \
     --base main \
     </dev/null >"$OUT" 2>&1
   rc=$?
   echo "rc=$rc; bytes=$(wc -c <"$OUT")"
   if [ "$rc" -eq 0 ]; then tail -120 "$OUT"; else echo "codex failed (rc=$rc); tail:"; tail -40 "$OUT"; fi
   rm -f "$OUT"
   ```

   - **There is no `-o`/`--color`/`--json` on `review` (codex-cli 0.130.0).** The
     full run goes to stdout: prompt echo, the reviewer's own tool/grep/test
     runs, then the final summary last. A run easily exceeds 100KB, so **never
     `cat` the whole stream into context** — redirect to `$OUT` and `tail` it.
     The verdict is the trailing block (often the `codex` summary line, sometimes
     printed twice). If the tail looks truncated mid-finding, widen to
     `tail -200`; only grep the whole file if you must locate a specific finding.
   - `</dev/null` is required: Codex hangs on "additional input from stdin" if
     stdin is left open.
   - Do **not** background the call. It must finish this turn so findings can be acted on.
   - **No custom focus prompt with a scope.** `[PROMPT]` conflicts with
     `--base`/`--commit`/`--uncommitted` (see "Choosing the review scope"). To
     focus, either narrow the scope (review one commit) or run the unscoped
     `codex exec review "Weight look-ahead heavily."` and accept its default
     diff selection.

3. **Relay findings.** Show the user the reviewer's summary. For each finding, either fix it in the working tree, or push back with reasoning if it's wrong — explicitly, never silently. After fixing, re-run with `--commit <fix-sha>` (or `--uncommitted`) to confirm the specific issues are resolved; tell the reviewer which prior findings it's confirming so it doesn't re-raise resolved items.

## Failure modes & guidance

- **"Nothing to review."** The selected scope has no diff. Pick the right selector (a fresh worktree branch needs `--base <base>`, uncommitted work needs `--uncommitted`).
- **Codex hangs.** Almost always an open stdin — confirm `</dev/null`. Kill with `pkill -f "codex exec"` and report; don't retry blindly.
- **Reviewer runs tests that fail in its sandbox.** The review sandbox is read-only, so cache writes / DB writes / network can fail as sandbox artifacts (e.g. "attempt to write a readonly database"). These are not real findings — note them as harness artifacts and rely on `uv run pyright` + the local test suite as authoritative.
- **APPROVE with no findings.** Trust but spot-check the diff yourself before merging; don't treat it as a rubber stamp.
