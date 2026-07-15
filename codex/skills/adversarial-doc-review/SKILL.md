---
name: adversarial-doc-review
description: Run a Claude-backed adversarial review of a spec and/or implementation plan via `claude -p`. Use after writing spec/plan docs, typically in `.plans/specs/` and `.plans/plans/`, and before starting implementation. Returns the reviewer's findings inline so they can be addressed in the same turn.
---

# Adversarial Doc Review

Shells out to the local Claude CLI (`claude -p`) with a critical-reviewer prompt aimed at spec and plan documents, not code. This is the Codex-side counterpart to Claude's `adversarial-doc-review` skill, which shells out to `codex exec`.

## When to use

- After writing a spec and/or plan, before implementation begins.
- The skill reviews **documents**, not code diffs. To have Claude review a code diff during implementation, use the sibling `claude-code-review` skill.

## Prerequisites

- `claude` CLI on PATH. Verify with `command -v claude` if uncertain.
- Run from the **main repo cwd on the main branch**, not from inside a worktree. Spec/plan files live at stable paths under `.plans/`; worktrees are ephemeral and relative paths get confused.

## Arguments

The caller supplies explicit file paths to review:

- **`--spec <path>`** - path to the spec file, optional if only reviewing a plan.
- **`--plan <path>`** - path to the plan file, optional if only reviewing a spec.
- **`--focus <text>`** - optional extra guidance to weight the review.

At least one of `--spec` or `--plan` must be provided. Paths may be absolute or relative to the current working directory.

## Workflow

1. **Validate inputs.** Confirm each supplied path exists and is a regular file. If a path is missing, stop and report it. Do not silently fall back to auto-discovery.

2. **Build the review prompt.** Use the template below verbatim, substituting the absolute paths of the supplied files. Include the `--focus` text under "Reviewer focus" if provided.

3. **Run Claude.** Invoke the CLI directly, no backgrounding. Pass the fully rendered prompt as one shell-escaped literal argument; do not store it in a shell variable because that prevents Codex's narrow command rule from matching:

   ```bash
   claude -p --permission-mode plan --output-format text '<fully rendered prompt>'
   ```

   - `-p` is required: it runs Claude non-interactively and prints the result.
   - `--permission-mode plan` is required: the reviewer must not edit files.
   - `--output-format text` keeps the captured answer easy to relay.
   - Run the command with `sandbox_permissions="require_escalated"`: Claude's
     API is outside the workspace network sandbox. Use the justification
     "Run the user-authorized read-only Claude review, which transmits the
     supplied design documents to the Anthropic Claude API?" The managed
     `claude-review.rules` rule records this explicit external-transmission
     authorization for future reviews.
   - Keep this exact argument prefix and pass the prompt literally. Shell variables, command substitutions, redirects, and wrapper scripts prevent the managed `claude-review.rules` prefix from matching.
   - Set the initial command yield to 30 seconds. If the command is still running, poll its session with an empty `write_stdin` call that waits 60 seconds. Keep polling every 60 seconds until the process exits; a thorough review can legitimately take more than 10 minutes.
   - Text output is buffered, so a silent reviewer is normal. Silence and elapsed time alone are never evidence that Claude is hung. Do not impose an arbitrary timeout, send `Ctrl-C`, terminate the process, inspect its PID, or launch parallel status checks while the session remains active. Give the user brief status updates and continue waiting.
   - Read only newly returned output. With text output, Claude prints the review result directly; temporary output and log files are unnecessary.
   - Do **not** background the call. The review must complete in the same turn so findings can be acted on.

4. **Relay and handle findings.** Show the user the reviewer's verdict and findings. For each finding, before acting:
   1. **Verify it's real** — the reviewer can misread the doc or its context. Confirm the issue genuinely holds before changing anything.
   2. **Engage on the merits** — no reflexive agreement; weigh the technical substance.
   3. **Then address or push back** — fix verified findings in the spec/plan and re-run the skill to confirm; for wrong ones, defend the design with specific reasoning. Never silently ignore, never blindly implement.

## Prompt template

Substitute `{{SPEC_PATH}}`, `{{PLAN_PATH}}`, and `{{FOCUS_BLOCK}}`, or omit a file line entirely if that file was not provided.

```text
You are an adversarial reviewer of design documents: a spec and/or an
implementation plan. Your job is to find the strongest objections a senior
engineer would raise before any code is written.

Files to review:
- Spec: {{SPEC_PATH}}
- Plan: {{PLAN_PATH}}

Read all supplied files in full from disk before saying anything.

{{FOCUS_BLOCK}}

Evaluate, in this order:

1. Correctness & completeness
   - Does the spec actually describe the problem and constraints, or hand-wave?
   - Does the plan's approach satisfy the spec? Any gap, contradiction, or
     unstated assumption?
   - Edge cases the plan ignores: empty inputs, concurrency, partial failure,
     idempotency, large inputs, time zones, ordering?

2. Risk & blast radius
   - What's the worst thing that breaks if the plan is wrong? Data loss?
     Silent corruption? Cascading failures? Reversibility?
   - Migrations, schema changes, or destructive operations without a rollback?

3. Design & alternatives
   - Is the proposed approach the simplest viable one, or over-engineered?
   - Are there obvious alternatives the plan dismissed without justification?
   - Premature abstractions, speculative generality, or features-not-asked-for?

4. Testability & verification
   - How will we know it actually works? Are the verification steps real
     commands and expected outputs, or vague?
   - What tests are missing? What's untestable as written?

5. Process & scope
   - Anything not in the spec that the plan quietly added?
   - Anything in the spec the plan silently dropped?

Output format - use these exact section headers, in order:

## Verdict
One sentence: APPROVE / APPROVE WITH CHANGES / REWORK. Then one sentence of why.

## Blocking findings
Numbered list. Each item: (1) what is wrong, (2) why it matters, (3) the
minimum change that would fix it. Cite file + line range or section heading.
If none, write "None.".

## Non-blocking suggestions
Numbered list, same shape but lower stakes. If none, write "None.".

## Questions for the author
Numbered list of clarifications needed before this can be approved. If none,
write "None.".

Rules:
- Be specific. "Consider error handling" is useless; cite the missing case.
- No flattery, no restating the doc. Land critique, not summary.
- If the doc is genuinely solid, APPROVE and keep the rest short. Do not
  manufacture findings.
- Do not edit files.
```

## Failure modes & guidance

- **Long-running or silent review.** Keep polling until the process exits, even after 10 minutes. Do not classify it as hung or terminate it based only on silence or elapsed time.
- **Confirmed failure.** Treat the review as failed only when the process exits nonzero, the tool reports a hard timeout/error, the user asks to stop, or there is other concrete evidence that progress is impossible. Report the exact evidence; do not retry blindly or reintroduce a shell wrapper.
- **Reviewer wants to edit files.** It must not; `--permission-mode plan` plus the prompt make the review read-only. The verdict and findings are the deliverable.
- **No findings at all + APPROVE.** Trust it but spot-check the doc yourself before moving to implementation. Do not treat APPROVE as a rubber stamp.
- **Inside a worktree.** Stop and switch back to the main repo cwd on `main` before running.
