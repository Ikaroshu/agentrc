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

- Use plain, concise language without buzzwords.
- After exploration, issue triage, or debugging, concisely explain the relevant infrastructure and root cause in beginner-friendly language. Keep the key technical facts and clearly separate what is proven, inferred, and still unknown.

## Development Workflow

- Implement a settled change directly and scale verification and review to impact. When user intent is materially uncertain, use brainstorming to settle the goal with the user first, then the design, outcome, and verification. Brainstorming also writes and reviews a spec when a durable contract is needed. Ask before optional workflows.
- Follow **[brainstorm ->] worktree -> implement -> code-review -> merge**. The agent invokes each skill and lets it own its stage; brainstorming writes a spec and invokes document review before the worktree when needed. Approval of the settled contract is sufficient when no spec is written; get implementation approval after document review when there is a spec, and merge approval after code review. Add no other reconfirmation gates.
- Center specs and reviews on the primary outcome. Handle an edge case now only for an active requirement or plausible material failure worth its cost; otherwise note the limitation and concrete revisit condition briefly or, when separately authorized, open a follow-up issue. Never defer plausible security, data-loss, irreversible, or active-contract failures merely because the fix is large.
- Keep specs uncommitted on `main`; put implementation worktrees under `<project-root>/.worktrees/`. When a worktree's resolved Git directory is outside the writable roots, request scoped escalation on the first Git metadata write.
- Give every review unit at most two completed review passes, including its initial review. A unit is one document review or one code review; repairs, replacement reviewers, and follow-up turns do not reset its budget. Advance as soon as a pass is clear. Use document-review pass two only for a materially changed repair or unresolved blocker; code-review pass two requires a pass-one repair. If pass two is not clear, stop the review workflow and explain the blocker in ELI5 terms, including the relevant context, evidence, impact, what the two passes tried, what remains unclear, and the user decision or external change needed. Do not dispatch a third review. Use working code and focused checks for questions prose cannot settle. For non-trivial behavior changes, leave the smallest focused regression check and scale surrounding verification to risk.
- The implementer owns delivery and truthful verification evidence for the clean committed candidate. After it reports the exact commit and tree, clean status, commands, and successful results, the orchestrator records that evidence and performs at most read-only candidate identity and status checks for coordination. It does not inspect or review the implementation diff, rerun the reported checks, or independently verify reviewer findings. The exact native `code_reviewer` owns independent technical inspection and actionable findings. Route definite findings to the implementer. If the implementer disputes an actionable reviewer finding with concrete technical evidence, forward that evidence to the same reviewer for clarification and reconsideration within pass one before repair; this follow-up does not consume or become pass two. The reviewer may uphold, revise, or withdraw the finding. Repair an upheld finding, and take material design, spec, or contract ambiguity to the user only when the reviewer concludes resolution requires changing the settled contract.
- Dispatch one code review only after implementation and verification have settled one clean immutable candidate with no unresolved work. Treat its acceptance as the last technical gate: ask for merge approval immediately, with only read-only identity or status checks allowed before the request. Any later code or configuration change, or any failed check, returns the candidate to implementation and invalidates acceptance.
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
