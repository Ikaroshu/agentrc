## Engineering Philosophy

- Prefer the simplest design that meets the current contract. Avoid speculative abstractions, state, branches, validation, recovery, retries, guards, or dependencies. First reuse a project primitive, the standard library or platform, or an installed dependency; add a dependency only when it materially lowers total complexity or supplies behavior the project should not own.
- Assume competent users and callers follow documented contracts. Do not handle invalid invocation, contradictory input, tampering, or bypassed workflows when they fail loudly before harm. Validate at real untrusted or external boundaries; user-facing alone is not untrusted. Add runtime safeguards only for plausible valid-use security, data-loss, irreversible, accessibility, or contract failures.
- Do not add `try`/`except`, `try`/`catch`, promise rejection handlers, or equivalent constructs that intercept errors, including error-result branches that recover, translate, suppress, retry, or continue after failure. Let failures propagate directly. Obtain explicit user approval before implementing any such error-catching construct.
- Put broader semantic, integrity, provenance, and consistency audits in tests or explicit maintenance commands. Do not reread, recompute, rehash, or traverse trusted data merely to prove its producer worked; construct immutable artifacts and required identity once.
- Prefer current code over legacy readers, migrations, aliases, shims, or compatibility branches unless requested or required by an active consumer. Disclose required rebuilds or reruns before a breaking change. Do not introduce or change versioning language or constructs—including `version N`, `vN`, `schema N`, version identifiers, or version branches—without explicit user approval. Record actual provenance and source revisions directly.
- Prefer clear names and structure over comments. Document only non-obvious logic, important warnings, or a deliberate simplification's concrete ceiling and revisit condition.
- Do not invent assurance machinery without a real requirement. Obtain user approval before adding assurance machinery.

## Debugging

- Reproduce the problem and read the complete error before theorizing. Trace active callers to the contract owner and fix the shared root cause unless that would alter unrelated contracts.
- Resolve material uncertainty from context or ask. Test one hypothesis at a time and revert failed experiments. After three falsified hypotheses, consult primary documentation or search instead of guessing.
- Verify the fix against the original reproduction before claiming success.

## Communication

- Lead with the outcome or finding. Explain the relevant mechanism and cause in plain language before presenting supporting technical detail.
- Assume an intelligent reader unfamiliar with this particular system. Provide enough context to understand what happened, why, and its practical significance. Define unfamiliar terms when needed; retain precise names and technical details that help assess the conclusion.
- Distinguish confirmed facts, inferences, and unknowns. Be concise without skipping causal steps. Use examples or analogies only when they clarify the mechanism.

## Development Workflow

- Use the implementer subagent for substantive or complex implementation. Keep simple changes with straightforward design and verification with the main agent. A settled design or absence of a spec does not by itself make work simple. When user intent is materially uncertain, use brainstorming to settle the goal, design, outcome, and verification; write and review a spec when the contract needs to be durable. Ask before optional workflows.
- Follow **[brainstorm ->] worktree -> implement -> code-review -> merge** and let each skill own its stage. Approval of a settled contract is sufficient when no spec is written; get implementation approval after document review when there is a spec, and merge approval after code review. Add no other reconfirmation gates.
- Center specs and reviews on the primary outcome. Handle an edge case now only for an active requirement or plausible material failure worth its cost; otherwise note the limitation and concrete revisit condition briefly or, when separately authorized, open a follow-up issue. Never defer plausible security, data-loss, irreversible, or active-contract failures merely because the fix is large.
- Keep specs uncommitted on `main`; put implementation worktrees under `<project-root>/.worktrees/`. When a worktree's resolved Git directory is outside the writable roots, request scoped escalation on the first Git metadata write.
- Give each document or code review unit at most two completed passes, including its initial review. Repairs, replacement reviewers, and follow-up turns do not reset the budget. Use document-review pass two only for a materially changed repair or unresolved blocker; code-review pass two requires a pass-one repair and covers that repair. If pass two is not clear, stop without a third review and explain the context, evidence, impact, what the passes tried, what remains unresolved, and the user decision or external change needed. Use working code and focused checks for questions prose cannot settle; leave the smallest useful regression check for non-trivial behavior changes.
- The implementation owner delivers the clean committed candidate and truthful verification evidence. For delegated work, the orchestrator records that evidence and performs only read-only identity and status checks. Native document and code reviewers own technical inspection and findings. Route definite findings to the responsible owner. When an owner disputes an actionable finding with concrete evidence, send it to the same reviewer for clarification within the current pass; the reviewer may uphold, revise, or withdraw the finding. Route upheld findings for repair, and take material contract changes to the user.
- Dispatch code review only for a clean immutable candidate with completed verification and no unresolved work. Treat acceptance as the last technical gate and ask for merge approval immediately. Any later code or configuration change, or failed check, invalidates acceptance.
- Treat agents and long commands as event-driven. Wait for the requested owner, reviewer, or process; handle unrelated events and resume. Use the longest supported empty terminal wait. Do not poll or narrate unchanged state; check separately only after abnormal duration or a concrete signal.
- When a task needs user-only `sudo` or other privileged work, ask once and end the turn. Do not poll or try workarounds; take an unprivileged path directly only if it is equivalent.

## GitHub Issues

- Unless asked otherwise, issue bodies contain only the problem and relevant context, not solutions or acceptance criteria.

## Check Failures

- Treat checks as evidence, not harness vetoes. Diagnose relevance, fix in-scope regressions, disclose unresolved failures before consequential actions, and proceed only when authorization covers that evidence.

## Python Style

- Type public functions directly. Use `snake_case` for modules/functions, `PascalCase` for classes, and `UPPER_SNAKE_CASE` for constants; include physical units when ambiguous.
- Leading underscores mark private symbols: create no underscore-prefixed modules and import no private symbols across modules, including tests. Do not maintain `__all__`.
- Prefer namespace packages; add `__init__.py` only for genuine exports. Use `uv` and direnv.
