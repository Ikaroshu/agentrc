---
name: commit
description: Run Shu's commit workflow for a repository. Use when the user asks to commit changes, run the commit workflow, or prepare a tested commit and push. Reads repo instructions for checks, runs validation before staging, stages files explicitly, commits with an appropriate message, and pushes the current branch.
---

# Commit Workflow

Run tests, commit, and push. Adapt behavior based on the repository's instructions.

**Announce at start:** "Running commit workflow."

## Step 1: Read Project Config

Read the repository instructions — prefer `AGENTS.md`; if absent, read `CLAUDE.md`. Look for a `## Git Workflow` (or equivalent) section for these fields:

- **Pre-stage checks** — lint/type-check commands to run before staging (default: none)
- **Commit tests** — test command to run before commit (default: `pytest`)
- **Pre-commit** — whether pre-commit hooks are enforced (default: no)

If no such section exists, use defaults.

## Step 2: Run Pre-stage Checks

Run the configured pre-stage check commands (e.g., `ruff check --fix`, `pyright`). **If type checking fails, stop.** Fix lint issues automatically where possible, but do not proceed if errors remain.

**If checks fail in files you did NOT touch this session, stop and ask the user** whether to fix them or commit around them. Do not silently classify them as pre-existing and move on.

## Step 3: Run Tests

Run the configured test command. **If tests fail, stop.** Do not proceed to commit. If no automated tests exist, run the repo's required validation gate or clearly report the gap. Do not commit with known failing checks unless the user explicitly confirms.

## Step 4: Stage and Commit

1. Run `git status` and `git diff` to review changes
2. Stage relevant files by name (never `git add -A` or `git add .`); preserve unrelated user changes
3. Craft a concise commit message following the repo's existing style
4. Commit (pre-commit hooks will run automatically if configured)
5. If pre-commit fails, fix issues, re-stage, and create a NEW commit

## Step 5: Push

Push to the current branch unless repo instructions or the user say otherwise:

```bash
git push origin $(git branch --show-current)
```

## Defaults Summary

| Setting | Serious project | Casual project |
|---------|----------------|----------------|
| Tests | from repo instructions | `pytest` |
| Pre-commit | yes | no |
| Push | yes | yes |
