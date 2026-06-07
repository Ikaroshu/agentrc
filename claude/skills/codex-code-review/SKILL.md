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

## Choosing the review scope

`codex exec review` takes exactly one scope selector:

- **`--base <branch>`** — review the full diff of the current branch against `<branch>` (e.g. `--base main`). Use for "review this feature/phase" and pre-merge review.
- **`--commit <sha>`** — review only the changes introduced by one commit. Use to re-review a fix commit.
- **`--uncommitted`** — review staged + unstaged + untracked changes in the working tree. Use for work not yet committed.

Optionally append a custom instruction string as the trailing `[PROMPT]` argument to focus the review (e.g. weighting a specific risk). Omit it to use Codex's default review behavior.

## Workflow

1. **Pick the scope** (`--base` / `--commit` / `--uncommitted`) based on what is being reviewed. Confirm there is actually a diff for that scope — an empty diff yields "nothing to review".

2. **Run Codex.** Single Bash call, no backgrounding. Substitute the scope selector; `cd` into the worktree first if reviewing branch work:

   ```bash
   cd /path/to/worktree        # the tree that holds the changes
   unset PYTHONPATH VIRTUAL_ENV  # only needed inside a worktree
   OUT=$(mktemp /tmp/codex_code_review.XXXX.txt)
   LOG=$(mktemp /tmp/codex_code_review_log.XXXX.txt)
   codex exec review \
     --skip-git-repo-check \
     --color never \
     -o "$OUT" \
     --base main \
     </dev/null >"$LOG" 2>&1
   rc=$?
   if [ "$rc" -eq 0 ]; then cat "$OUT"; else echo "codex failed (rc=$rc); log tail:"; tail -40 "$LOG"; fi
   rm -f "$OUT" "$LOG"
   ```

   - **`-o "$OUT"` writes ONLY the reviewer's final summary to `$OUT`.** The raw
     stream (prompt echo, headers, reasoning, the reviewer's own tool/test runs,
     token usage) is verbose noise — a single run easily exceeds 200KB and will
     blow out the context window. It goes to `$LOG`, discarded unless the run
     fails. Read `$OUT`, never the raw stream. Do **not** try to salvage the raw
     stream with `awk`/`tail` — `-o` is the correct mechanism.
   - `</dev/null` is required: Codex hangs on "additional input from stdin" if
     stdin is left open.
   - `--color never` keeps the captured summary clean.
   - Do **not** pass `--json` — `-o` already gives the plain final message.
   - Do **not** background the call. It must finish this turn so findings can be acted on.
   - To focus the review, add a quoted instruction as the last argument, e.g.
     `... --base main "Weight look-ahead / information-leakage heavily."`

3. **Relay findings.** Show the user the reviewer's summary. For each finding, either fix it in the working tree, or push back with reasoning if it's wrong — explicitly, never silently. After fixing, re-run with `--commit <fix-sha>` (or `--uncommitted`) to confirm the specific issues are resolved; tell the reviewer which prior findings it's confirming so it doesn't re-raise resolved items.

## Failure modes & guidance

- **"Nothing to review."** The selected scope has no diff. Pick the right selector (a fresh worktree branch needs `--base <base>`, uncommitted work needs `--uncommitted`).
- **Codex hangs.** Almost always an open stdin — confirm `</dev/null`. Kill with `pkill -f "codex exec"` and report; don't retry blindly.
- **Reviewer runs tests that fail in its sandbox.** The review sandbox is read-only, so cache writes / DB writes / network can fail as sandbox artifacts (e.g. "attempt to write a readonly database"). These are not real findings — note them as harness artifacts and rely on `uv run pyright` + the local test suite as authoritative.
- **APPROVE with no findings.** Trust but spot-check the diff yourself before merging; don't treat it as a rubber stamp.
