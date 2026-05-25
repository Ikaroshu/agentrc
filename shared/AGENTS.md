## Me
Shu (xx9liao@gmail.com)

## General Coding Style
- **Comments & docstrings:** Prefer self-explanatory code (clear naming, simple structure) over comments. Add docstrings only to explain non-obvious logic, subtle gotchas, or important warnings.
- **Fail out loud:** Don't add defensive code — error handling, input validation, fallbacks, or "just in case" guards for conditions that shouldn't happen given the surrounding contract. Don't silently swallow unexpected errors. Don't use `try/except` (or equivalent) for normal control flow. These turn loud failures into silent ones and hide real bugs. Let errors propagate so the actual cause is visible. Validate or catch only at true system boundaries (untrusted input, external APIs, user-facing entry points).

## Debugging Guidelines
- Ask clarifying questions before suggesting fixes.
- Write short scripts to falsify/validate your assumption about the fix.
- Search online for solutions after 3 assumptions have been falsified.

## Superpowers Plugin Instruction
- **Workflow order: doc → review → worktree → implement.** Stay on `main` (in the main repo cwd, NOT a worktree) while writing the spec and plan and while running the adversarial review. Only create the worktree once the doc cycle is finished and you're ready to write code. Reason: spec/plan files live at stable `.superpowers/...` paths relative to project root; from a worktree those paths get confused.
- Save plans to `<project-root>/.superpowers/plans/` and specs to `<project-root>/.superpowers/specs/` (NOT inside worktree directories — worktrees are ephemeral)
- DO NOT commit plans and specs
- After writing the spec and plan (on main), invoke the `adversarial-doc-review` skill via the Skill tool, passing the spec and plan paths. The skill shells out to `codex exec` synchronously and returns findings in the same turn. Address findings before proceeding.
- **Cap `adversarial-doc-review` at TWO invocations per spec/plan cycle** (the initial review, plus at most one re-review after addressing findings). Do not run a third review on your own initiative — even if you think more findings might surface or you want to validate a rewrite. If a third pass seems warranted, ask the user first; only run more when they explicitly say so.
- Do NOT use the official `/codex:adversarial-review` plugin command — it has been replaced by the homebrewed `adversarial-doc-review` skill because the plugin was unstable for doc review.
- Prefer using worktree for development. If the scope is small and main branch is clean, consider developing on main directly.

## GitHub Issues
- Issue bodies describe the problem and context only — no proposed fixes, suggested approaches, design sketches, or acceptance criteria. The author often doesn't fully understand the problem; prescribing a solution biases whoever picks it up later.

## Pre-existing Errors (lint, type check, tests)
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
- **Environment:**
  - Use `uv` for Python package management
  - Use direnv with .envrc for automatic venv activation
