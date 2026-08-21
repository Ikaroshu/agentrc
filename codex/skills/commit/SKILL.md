---
name: commit
description: Run Shu's commit workflow for a repository. Use when the user asks to commit changes, run the commit workflow, or prepare a tested commit and push. Reads repo instructions for checks, runs validation before staging, stages files explicitly, commits with an appropriate message, and pushes automatically when the work is on main or otherwise when authorized.
---

# Commit Workflow

Run tests and commit, then push automatically when the work is on `main`; on other branches, push when the user or repository workflow authorizes it. Adapt behavior based on the repository's instructions.

**Announce at start:** "Running commit workflow."

## Step 1: Read Project Config

Read the repository instructions — prefer `AGENTS.md`; if absent, read `CLAUDE.md`. Look for a `## Git Workflow` (or equivalent) section for these fields:

- **Pre-stage checks** — lint/type-check commands to run before staging (default: none)
- **Commit tests** — test command to run before commit (default: `pytest`)
- **Pre-commit** — whether pre-commit hooks are enforced (default: no)

If no such section exists, use defaults.

## Step 2: Run Pre-stage Checks

Run the configured pre-stage check commands (e.g., `ruff check --fix`, `pyright`). Treat their results as evidence: diagnose failures far enough to say whether they are caused by the proposed commit, and report unresolved failures accurately.

## Step 3: Run Tests

Run the configured test command. If no automated tests exist, run the repository's validation command or clearly report the gap. A failed check is not by itself a harness veto: assess its relevance, fix in-scope regressions, and disclose any unresolved failure before committing or pushing. Proceed only when the user's authorization covers accepting that evidence.

## Step 4: Stage and Commit

1. Run `git status` and `git diff` to review changes
2. Stage relevant files by name (never `git add -A` or `git add .`); preserve unrelated user changes
3. Craft a concise commit message following the repo's existing style
4. Commit (pre-commit hooks will run automatically if configured)
5. If pre-commit fails, fix issues, re-stage, and create a NEW commit

## Step 5: Push

Resolve the current branch after committing:

- If it is `main`, push `origin main` as part of the commit workflow without a separate authorization prompt.
- On any other branch, push only when the user's request or repository workflow explicitly authorizes it.
- Before either push, inspect the unpublished commits. If the push would publish unrelated commits, surface them and obtain explicit approval.

```bash
git push origin $(git branch --show-current)
```

## Defaults Summary

| Setting | Serious project | Casual project |
|---------|----------------|----------------|
| Tests | from repo instructions | `pytest` |
| Pre-commit | yes | no |
| Push | automatic on `main`; otherwise when authorized | automatic on `main`; otherwise when authorized |
