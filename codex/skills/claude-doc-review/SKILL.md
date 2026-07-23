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
- `--focus <text>`: optional review emphasis.

Require at least one of `--spec` or `--plan`. Resolve every supplied path to an absolute path and verify it is a regular file. Never auto-discover a substitute.

## Workflow

1. Render the prompt below with the supplied paths and optional focus.
2. Invoke Claude directly with the fully rendered prompt as one literal argument:

   ```bash
   claude -p --permission-mode plan --output-format text '<fully rendered prompt>'
   ```

   Use `sandbox_permissions="require_escalated"` with the justification: "Run the user-authorized read-only Claude review, which transmits the supplied design documents to the Anthropic Claude API?"

   Keep the exact argument prefix. Do not use shell variables, command substitutions, redirects, wrappers, or backgrounding; these prevent the managed permission rule from matching.

3. Start with a 30-second yield. If the process remains active, poll with an empty `write_stdin` call every 60 seconds until it exits. Text output is buffered, so silence and elapsed time alone are not evidence of a hang. Do not impose an arbitrary timeout, interrupt the process, inspect its PID, or launch parallel status checks while it remains active. Give the user brief status updates while waiting.
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

{{FOCUS_BLOCK}}

Evaluate, in order:
1. Correctness and completeness: gaps, contradictions, unstated assumptions,
   and ignored edge cases.
2. Risk and blast radius: data loss, security, migrations, partial failure,
   reversibility, concurrency, and external contracts.
3. Design and alternatives: unnecessary complexity, premature abstraction,
   or a simpler viable approach.
4. Testability: exact verification, missing tests, and untestable claims.
5. Process and scope: scope creep or requirements silently dropped.

Output these exact sections:

## Verdict
APPROVE, APPROVE WITH CHANGES, or REWORK, followed by one sentence explaining why.

## Blocking findings
Numbered findings with file and line or section, problem, impact, and minimum fix. Write "None." if empty.

## Non-blocking suggestions
Numbered suggestions in the same form. Write "None." if empty.

## Questions for the author
Numbered questions required for approval. Write "None." if empty.

Be specific, do not flatter or restate the documents, and do not manufacture findings.
```

Omit absent file lines and the focus block instead of leaving placeholders.

## Failure handling

- Missing input: stop and report the exact path.
- Missing Claude CLI or authentication: stop and report the missing prerequisite without exposing credentials.
- Nonzero Claude exit: report the exit status and returned error; diagnose before retrying.
- Long silent run: keep polling until the process exits, the tool reports a hard error, the user asks to stop, or progress is concretely impossible.
- No findings: spot-check the documents yourself before continuing.
