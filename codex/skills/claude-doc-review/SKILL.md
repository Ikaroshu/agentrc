---
name: claude-doc-review
description: Run a Claude-backed adversarial review of a spec and/or implementation plan via `claude -p`. Use when the user explicitly asks for a Claude document review before implementation. Returns findings inline for verification and follow-up.
---

# Claude Doc Review

Use the local Claude CLI as a read-only third-party reviewer for design documents. This optional skill does not replace the workflow's default `adversarial-doc-review` skill.

## Prerequisites

- `claude` is on `PATH`.
- Run from the main repository cwd on the main branch, not from a worktree.

## Arguments

- `--spec <path>`: optional spec path.
- `--plan <path>`: optional plan path.
- `--focus <text>`: optional concern to emphasize without narrowing the review.

Require at least one of `--spec` or `--plan`. Resolve every supplied path to an absolute path and verify it is a regular file. Never auto-discover a substitute.

If focus is supplied, prefer to keep the distilled emphasis within 80 words. Exceed that only when necessary to preserve materially distinct concerns, and briefly justify the extra detail. Do not pass scope exclusions, required conclusions, or instructions to omit review dimensions.

## Workflow

1. Render the prompt below with the supplied paths and optional distilled focus.
2. Invoke Claude directly with the fully rendered prompt as one literal argument:

   ```bash
   claude -p --permission-mode plan --output-format text '<fully rendered prompt>'
   ```

   Use `sandbox_permissions="require_escalated"` with the justification: "Run the user-authorized read-only Claude review, which transmits the supplied design documents to the Anthropic Claude API?"

   Keep the exact argument prefix. Do not use shell variables, command substitutions, redirects, wrappers, or backgrounding; these prevent the managed permission rule from matching.

3. Start with a 60-second yield. If still running, poll every 120 seconds until exit and briefly update the user. Because text output is buffered, silence is expected; do not interrupt or launch parallel status checks without a concrete error or user request.
4. Relay the verdict and findings. Verify every finding against the documents and repository context before editing. Classify each as confirmed, rejected with specific reasoning, or needing clarification. Never blindly implement or silently skip feedback.

## Prompt template

```text
You are an adversarial reviewer of design documents: a spec and/or an
implementation plan. Your job is to find the strongest objections a senior
engineer would raise before any code is written.

Files to review:
- Spec: {{SPEC_PATH}}
- Plan: {{PLAN_PATH}}

Read every supplied file in full from disk before responding. You may inspect
relevant repository context, but do not edit files.

Additional emphasis only; this does not narrow the review or suppress findings:
{{FOCUS_EMPHASIS}}

Evaluate, in order:
1. Problem validity and proportionality: whether the motivating problem is
   supported by realistic scenarios or evidence and is worth solving now.
   Distinguish likely real-world cases from speculative or extremely rare edge
   cases. Challenge designs whose complexity, maintenance burden, or risk
   outweighs the expected benefit, and identify when documentation, an
   operational workaround, or accepting the limitation would be preferable.
2. Correctness and completeness: gaps, contradictions, unstated assumptions,
   and ignored edge cases.
3. Risk and blast radius: data loss, security, migrations, partial failure,
   reversibility, concurrency, and external contracts.
4. Design and alternatives: unnecessary complexity, premature abstraction,
   or a simpler viable approach.
5. Testability: exact verification, missing tests, and untestable claims.
6. Process and scope: scope creep or requirements silently dropped.

Output these exact sections:

## Verdict
APPROVE, APPROVE WITH CHANGES, or REWORK, followed by a concise rationale
proportional to the verdict. For REWORK based on problem validity or
proportionality, explain the real-world evidence or likelihood gap, why the
design cost outweighs the expected benefit, and which simpler disposition
should be considered.

## Blocking findings
Numbered findings with file and line or section, problem, impact, and minimum fix. Write "None." if empty.

## Non-blocking suggestions
Numbered suggestions in the same form. Write "None." if empty.

## Questions for the author
Numbered questions required for approval. Write "None." if empty.

Be specific, do not flatter or restate the documents, and do not manufacture findings.
```

Omit absent file lines and the additional-emphasis lines instead of leaving placeholders.

## Failure handling

- Missing input: stop and report the exact path.
- Missing Claude CLI or authentication: stop and report the missing prerequisite without exposing credentials.
- Nonzero Claude exit: report the exit status and returned error; diagnose before retrying.
- Long silent run: keep polling until the process exits, the tool reports a hard error, the user asks to stop, or progress is concretely impossible.
- No findings: spot-check the documents yourself before continuing.
