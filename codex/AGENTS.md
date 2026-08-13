## General Coding Style
- **Comments & docstrings:** Prefer self-explanatory code (clear naming, simple structure) over comments. Add docstrings only to explain non-obvious logic, subtle gotchas, or important warnings.
- **Fail out loud:** Don't add defensive code — error handling, input validation, fallbacks, or "just in case" guards for conditions that shouldn't happen given the surrounding contract. Don't silently swallow unexpected errors. Don't use `try/except` (or equivalent) for normal control flow. These turn loud failures into silent ones and hide real bugs. Let errors propagate so the actual cause is visible. Validate or catch only at true system boundaries (untrusted input, external APIs, user-facing entry points).

## Compatibility Policy
- Treat these as personal projects with no external customers. Prefer clean current code over backward compatibility for deprecated configuration, caches, reports, staging state, or run artifacts.
- Do not add legacy readers, compatibility gates, migrations, aliases, shims, or version branches unless the user explicitly requests them. Intentional breaking changes may require clearing or rebuilding caches, regenerating reports or generations, and rerunning jobs.
- Keep version fields only when the active generic storage or serialization protocol requires them or when they record external provider or normalization provenance. Do not use source revision, recipe version, or format version as a proxy for “current code”; record source revision as provenance when useful.
- State destructive or expensive rebuild consequences before implementation, but do not preserve deprecated code solely to avoid them.

## Debugging Guidelines
- **Reproduce first** — get a reliable repro and read the full error before theorizing. No repro yet means keep gathering evidence, not guessing.
- Ask clarifying questions before suggesting fixes.
- Write short scripts to falsify/validate your assumption about the cause; fix the root cause, not the symptom.
- **One change at a time** — if a fix doesn't work, revert it before trying the next. Don't stack speculative patches.
- Search online for solutions after 3 assumptions have been falsified.
- **Verify against the original repro** before claiming it's fixed.
- **Escalate external Git worktree metadata in Codex** — when a worktree's resolved Git directory is outside the active writable roots, request scoped escalation on the first invocation.

## Development Workflow
Choose the workflow based on scope:

- For small, clear, low-risk changes, implement and test directly.
- When a discussion or request has material uncertainty about intent, requirements, scope, assumptions, or design choices that could change the outcome, invoke brainstorming automatically. If the change is also large, cross-cutting, or high-risk, recommend continuing through planning and doc review.
- For large, cross-cutting, or high-risk changes whose requirements are already settled, recommend planning and doc review without requiring brainstorming first.
- For borderline changes, briefly give your recommendation and let the user choose.

Ask before invoking an optional workflow other than automatically triggered brainstorming. When the user chooses planning, follow: **[brainstorm →] plan → doc-review → worktree → implement → code-review → merge.** The agent invokes each chosen skill when its stage is reached. During brainstorming, get approval on the design. After doc review findings are addressed, pause and ask the user for a go/no-go on the reviewed plan and spec before creating a worktree or starting implementation. After code review findings are addressed, pause again and ask the user for a final go/no-go before merging. Outside these required checkpoints, proceed without asking the user to invoke skills or reconfirm. Brainstorming may also be used alone for a small but ambiguous change; after the design is approved, implement and test directly.

1. **Brainstorm (automatic when necessary)** — Use the `brainstorming` skill for material uncertainty that could change the outcome. It surfaces the working view and any genuinely relevant challenge to the user before settling the design, asks only consequential questions, and does not write the implementation plan.
2. **Plan** — Use the `planning` skill on `main`, in the main repo cwd, NOT a worktree. It turns settled requirements into an executable plan at `<project-root>/.plans/plans/`. Brainstorming may supply a spec at `<project-root>/.plans/specs/`. **Do NOT commit** plans or specs.
3. **Doc-review** — Invoke the installed `adversarial-doc-review` skill on the plan/spec. It uses GPT-5.6 Sol at xhigh effort for non-hard reviews and max effort for hard reviews. Address findings before coding.
4. **Worktree** — Create an isolated worktree under `<project-root>/.worktrees/` for the implementation. Skip for small changes when `main` is clean.
5. **Implement** — Use the `implement` skill: dispatch one fresh exact `implementer` role per plan phase with GPT-5.6 Sol at high reasoning effort. Require a completely clean worktree before each dispatch, guard Git control state and task ownership around the phase, and review real verification evidence and the scoped diff before the orchestrator creates the focused phase commit. The implementer chooses an appropriate implementation and testing sequence, may coordinate bounded native helpers with disjoint ownership, and inherits the caller's sandbox. Its no-commit, no-external-write, no-escalation, and no-standalone-harness policy is instruction-level, not a capability boundary. The orchestrator owns every commit, cross-phase decision, and final code review.
6. **Code-review** — After a development phase and before merging, invoke the installed `code-review` skill. It uses GPT-5.6 Sol at xhigh effort for non-hard reviews and max effort for hard reviews. For each finding, **verify it's real before acting** (reviewers misread context and hit sandbox artifacts), then fix it or push back with specific reasoning — never silently skip, never blindly implement.
7. **Merge** — Use the `merge` skill.

- **Cap each logical `adversarial-doc-review` or `code-review` workflow at THREE completed substantive reviewer turns** (initial review plus at most two re-reviews). Count completed substantive outputs, not failed attempts or errors without completed output. Re-invoking a skill does not reset the count. Ask the user before a fourth completed turn. Only a materially new scope starts a new workflow, and disclose that reset.

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
  - No underscore-prefixed module files (`_xxx.py`). Module identity is conveyed by package structure, not filename leading underscores — name the module for what it holds (e.g. `decision_bound.py`, not `_decision_bound.py`).
  - **Symbol privacy is a house-rule convention: a leading underscore on a name (`_helper`, `_CACHE`) marks it private; no leading underscore means public API.** Do NOT maintain `__all__` — the underscore convention is the only privacy signal. A symbol consumed by another module must be public (no underscore); never import an underscore-prefixed name across module boundaries, including from tests.
- **Packages:** Prefer namespace packages; avoid `__init__.py` unless a package genuinely needs to re-export symbols at the package level (still no `__all__` — rely on the underscore convention)
- **Environment:**
  - Use `uv` for Python package management
  - Use direnv with .envrc for automatic venv activation
