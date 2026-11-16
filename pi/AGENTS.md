## Engineering Philosophy

- Prefer the simplest design that meets the current contract. Avoid speculative abstractions, state, branches, validation, recovery, retries, guards, and dependencies. Reuse a project primitive, the standard library, or an installed dependency before adding one.
- Assume callers follow documented contracts. Validate only at real untrusted or external boundaries; user-facing alone is not untrusted. Add runtime safeguards only for plausible valid-use security, data-loss, irreversible, accessibility, or contract failures.
- Get explicit user approval before adding `try`/`except`, `try`/`catch`, promise rejection handlers, or equivalent constructs, and catch only where the code can meaningfully recover. Ordinary `if`/`else` for expected outcomes, such as validation findings, needs no approval. Let unexpected failures propagate and stay visible.
- Get user approval before adding assurance machinery. Put semantic, integrity, provenance, and consistency audits in tests or explicit maintenance commands. Construct immutable artifacts and required identity once; do not reread, recompute, rehash, or traverse trusted data to prove its producer worked.
- Prefer current code over legacy readers, migrations, aliases, shims, and compatibility branches unless requested or required by an active consumer. Disclose required rebuilds or reruns before a breaking change.
- Get explicit user approval before introducing or changing versioning language or constructs, such as `vN`, `schema N`, version identifiers, or version branches. Record actual provenance and source revisions directly.
- Prefer clear names and structure over comments. Comment only non-obvious logic, important warnings, or a deliberate simplification's ceiling and revisit condition. Docstrings meet the same bar: at most a one-line summary for a module or class, and a function docstring only for a contract the signature and names cannot state; explain behavior and math in the project's documentation.

## Debugging

- Reproduce the problem and read the complete error before theorizing, and confirm the fix against that reproduction before claiming success.
- Fix the shared root cause at its contract owner unless that would alter unrelated contracts.
- Test one hypothesis at a time and revert failed experiments. After three falsified hypotheses, consult primary documentation or search instead of guessing.

## Communication

- Default to English in conversation unless the user asks otherwise. Language requirements for a task or artifact apply only to that output.
- Lead with the outcome or finding, then explain the cause in plain language before the technical detail.
- Write for an intelligent reader unfamiliar with this system: define unfamiliar terms and say what the result means in practice.
- Use one name for one concept throughout, and name the actor or referent instead of an ambiguous "it" or "this".
- Separate confirmed facts, inferences, and unknowns. When simplifying, keep uncertainty, conditions, and scope: "may have failed" must not become "failed."

## Git

- Stage files by name so unrelated changes stay out, and commit in the repository's style. A commit request authorizes the checks and post-commit actions the repository requires.
- When committing on `main`, also push to `origin`; if that would publish unrelated commits, disclose them and ask. Push other branches only when the user or repository workflow authorizes it.

## Verification

- Leave the smallest useful regression check for non-trivial behavior changes, and use working code for questions prose cannot settle.
- Run repository-required checks after the final change and review repairs.
- Treat failures as evidence: diagnose relevance, fix in-scope regressions, and disclose unresolved failures before consequential actions, which then proceed only if authorization covers them.

## Python Style

- Type public functions directly, and include physical units in names when ambiguous.
- Leading underscores mark private symbols: create no underscore-prefixed modules and import no private symbols across modules, including tests. Do not maintain `__all__`.
- Prefer namespace packages; add `__init__.py` only for genuine exports. Use `uv` and direnv.

## Development Workflow

- Pi is the fallback harness for basic tasks while Claude and Codex usage limits are exhausted. Do small, well-scoped work directly; when a task needs a design decision, a spec, or a multi-step implementation, say so and stop instead of starting it.
- State the plan and get the user's approval before changing files, unless the request already states the exact change.
- Run servers and long commands, and start helper agents, through Herdr as the `herdr` skill describes. Start helpers only when the user asks.
- Usage is billed per token from API credits: read targeted ranges instead of whole large files, and keep command output short.
