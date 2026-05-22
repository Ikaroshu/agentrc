## Me
Shu (xx9liao@gmail.com)

## General Coding Style
- **Docstrings:** Prefer self-explanatory code (clear naming, simple structure) over comments. Add docstrings only to explain non-obvious logic, subtle gotchas, or important warnings.
- **Fail out loud:** Don't add defensive code — error handling, input validation, fallbacks, or "just in case" guards for conditions that shouldn't happen given the surrounding contract. Don't silently swallow unexpected errors. Both turn loud failures into silent ones and hide real bugs. Let errors propagate so the actual cause is visible. Validate or catch only at true system boundaries (untrusted input, external APIs, user-facing entry points).

## Debugging Guidelines
- Ask clarifying questions before suggesting fixes.
- Write short scripts to falsify/validate your assumption about the fix.
- Search online for solutions after 3 assumptions has been falsified.

## Superpowers Plugin Instruction
- Save plans to `<project-root>/.superpowers/plans/` and specs to `<project-root>/.superpowers/specs/` (NOT inside worktree directories — worktrees are ephemeral)
- DO NOT commit plans and specs
- After writing the spec and plan, invoke ONE `/codex:adversarial-review --wait` via the Skill tool on both files before starting implementation. The `--wait` flag is required so the review runs in the foreground and returns results in the same turn — do not let it prompt for foreground/background. Address findings before proceeding.
- **Cap `/codex:adversarial-review` at TWO invocations per spec/plan cycle** (the initial review, plus at most one re-review after addressing findings). Do not run a third review on your own initiative — even if you think more findings might surface or you want to validate a rewrite. If a third pass seems warranted, ask the user first; only run more when they explicitly say so.
- Prefer implement directly on new branch, ask user if current branch is not main or if there are uncommited files.

## Github
- Do not suggest fix when creating issue.

## Pre-existing errors (lint, type check, tests)
- If pre-stage checks (ruff, pyright, pytest, etc.) fail on files I did NOT touch in this session, **STOP**. Do not silently classify them as "pre-existing and unrelated" and move on.
- Report the errors to the user and ask explicitly: "these are pre-existing failures in <files> — fix in this session, or commit around them?"
- Only proceed once the user answers. Never commit with known failing checks without confirmation, even if my own changes are clean.

## Python Coding Style
- **Type hints:** Add type hints on public functions; prefer direct type annotations over quoted
- **Naming conventions:**
  - `snake_case` for modules/functions
  - `PascalCase` for classes
  - `UPPER_SNAKE_CASE` for constants
- **Packages:** Prefer namespace packages; avoid `__init__.py` unless explicit symbol exports needed
- **Error handling:** Don't use `try/except` for normal control flow; catch exceptions only at clear integration boundaries
- **Environment:** 
  - Use `uv` for Python package management
  - Use direnv with .envrc for automatic venv activation
