## Engineering Philosophy

- Prefer the simplest design that satisfies the current contract. Do not add speculative abstractions, state, branches, validation, error handling, fallbacks, retries, or guards for conditions that should be impossible. Let contract violations fail at their source.
- Before adding code, determine whether the current contract needs new code; then look for an appropriate project primitive or pattern, the standard library or native platform, and an already-installed dependency before writing the smallest clear local implementation. Add a dependency only when it materially reduces total complexity or provides behavior the project should not own.
- Validate or catch only at real boundaries such as untrusted input, external APIs, and user-facing entry points. Do not use exceptions for normal control flow or swallow unexpected failures. Keep a runtime safeguard only when the current operation needs it to prevent a plausible security failure, data loss, inaccessible user-facing behavior, or another contract violation. Put broader semantic, integrity, provenance, and consistency audits in tests or explicit verification and maintenance commands.
- Do not reread, recompute, rehash, or traverse trusted data merely to prove that the producing code worked. Construct immutable artifacts and any required content identity in one pass; compute hashes only when identity or integrity is part of the active contract.
- Prefer clean current code over legacy readers, migrations, aliases, shims, and compatibility branches unless the user requests compatibility or a known active consumer requires it. State before implementation when a breaking change requires rebuilding state or rerunning jobs.
- Use version fields only for active generic storage or serialization protocols or when an external provider exposes a meaningful version. Record normalization provenance and source revisions directly; do not invent source, recipe, or format versions as proxies for current code.
- Prefer clear names and simple structure over comments. Add comments or docstrings only for non-obvious logic, subtle constraints, or important warnings. When a deliberate simplification has a real, non-obvious ceiling, document the ceiling and the concrete condition for revisiting it.

## Debugging

- Reproduce the problem and read the complete error before theorizing. Without a reliable repro, keep gathering evidence.
- For bug fixes, trace the active flow and relevant callers to the layer that owns the contract. Fix the shared root cause once rather than patching only the reported path, unless changing the shared layer would alter unrelated contracts.
- Ask about material uncertainty that cannot be resolved from context. Test one hypothesis at a time with a focused experiment, and revert a failed change before trying another.
- After three falsified hypotheses, consult primary documentation or search online rather than continuing to guess.
- Verify the fix against the original repro before claiming success.

## Development Workflow

- Implement small, clear, low-risk changes directly. Invoke brainstorming automatically only when a material uncertainty about intent, requirements, scope, assumptions, or design choices requires meaningful user input before proceeding. Do not invoke it for uncertainty resolvable through project context, ordinary reasoning, or safe in-scope assumptions. For settled large, cross-cutting, or high-risk work, recommend planning and document review; for borderline work, give a recommendation and let the user choose.
- For non-trivial changed behavior, leave the smallest focused regression check that would fail if the behavior regressed, using the repository's existing test tools; scale surrounding verification to risk.
- Ask before starting an optional workflow. When chosen, follow **[brainstorm ->] plan -> doc-review -> worktree -> implement -> code-review -> merge** and let each skill own its stage mechanics. The agent invokes the selected skills; do not ask the user to invoke them.
- Get approval for the design during brainstorming. After document-review findings are resolved, pause for approval before creating a worktree or implementing. After code-review findings are resolved, pause again before merging. Do not add other reconfirmation gates.
- Keep plans and specs uncommitted on `main`; put planned implementation worktrees under `<project-root>/.worktrees/`. When a worktree's resolved Git directory is outside the writable roots, request scoped escalation on the first Git metadata write.
- Cap each logical document-review or code-review workflow at three completed substantive reviewer turns. Ask before a fourth; only materially new scope resets the count.

## Context Handoffs

- When the user requests a fresh task because the current task's context is too long, create a new task with a concise self-contained handoff prompt. Do not fork the current task, because a fork copies its completed history.
- Keep active issue work in its existing `<project-root>/.worktrees/<name>/` checkout. Make that exact directory the primary folder of a saved local Codex project. Resolve its exact path with the project-listing tool, then create the continuation with the thread-creation tool targeting that project and `environment: local`. Do not target the parent project or select a worktree environment, which would use a different checkout.
- Before dispatch, verify that the saved project's primary path exactly matches the active worktree. If it is unavailable, stop and ask the user to add that worktree as a local project; do not create another worktree, relocate the changes, or construct a temporary patch.
- Include the absolute worktree path, branch and HEAD, working-tree state, governing plan/spec/handoff paths, completed work and verification, remaining work, blockers, and approval boundaries in the handoff prompt.

## GitHub Issues

- Issue bodies describe only the problem and relevant context, without proposed solutions or acceptance criteria, unless the user explicitly asks otherwise.

## Pre-existing Check Failures

- If a pre-stage check fails in files not touched during the session, stop and ask whether to fix those failures or proceed around them. Never commit with known failing checks without explicit approval.

## Python Style

- Add direct type annotations to public functions.
- Use `snake_case` for modules and functions, `PascalCase` for classes, and `UPPER_SNAKE_CASE` for constants. Names carrying physical units include the unit when ambiguity is possible.
- Do not create underscore-prefixed module files. A leading underscore marks a private symbol; do not import private symbols across modules, including from tests, and do not maintain `__all__`.
- Prefer namespace packages. Add `__init__.py` only for genuine package-level exports.
- Use `uv` for dependency management and direnv for project environments.
