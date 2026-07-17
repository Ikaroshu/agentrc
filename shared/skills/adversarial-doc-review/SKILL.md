---
name: adversarial-doc-review
description: Run an OMP-backed adversarial review of a spec and/or implementation plan through a tiered OpenRouter model. Estimates an easy, medium, or hard tier, announces it transparently, and returns findings inline before implementation.
---

# Adversarial Doc Review

Use the local OMP `review` profile as a neutral third-party reviewer for design documents. The profile selects an OpenRouter model by review tier and exposes only `read`, `grep`, and `glob`; it cannot edit files or run commands.

## Prerequisites

- `omp` is on `PATH`.
- `~/.omp/profiles/review/agent/config.yml` and `models.yml` are installed by `agentrc/omp/install.sh`.
- `~/.omp/profiles/review/agent/.env` links to `~/.omp/agent/.env`, which contains `OPENROUTER_API_KEY`.
- Run from the main repository cwd on the main branch, not from a worktree.

## Arguments

- `--spec <path>`: optional spec path.
- `--plan <path>`: optional plan path.
- `--focus <text>`: optional review emphasis.
- `--difficulty <easy|medium|hard>`: optional explicit tier override.

At least one of `--spec` or `--plan` is required. Validate every supplied path as a regular file; never auto-discover a substitute.

## Select the review tier

Honor an explicit `--difficulty`. Otherwise estimate from the supplied documents:

- **Easy**: small, localized, familiar change with no public contract, persistent state, concurrency, security, or data-loss implications.
- **Medium**: multi-file behavior or a meaningful contract/state change whose blast radius remains localized.
- **Hard**: architecture or cross-system work; public APIs or schemas; migrations; concurrency; security; data-loss risk; high blast radius; or substantial ambiguity.

Round upward when signals are mixed. Before invoking OMP, tell the user the selected tier and one-sentence rationale, then proceed immediately unless the user objects or supplied an override.

Map tiers to models exactly:

- easy: `openrouter/deepseek/deepseek-v4-pro`
- medium: `openrouter/x-ai/grok-4.5`
- hard: `openrouter/moonshotai/kimi-k3`

## Workflow

1. Resolve supplied document paths to absolute paths.
2. Render the prompt below with those paths, the optional focus, and the selected tier.
3. Run OMP using this exact argument order, substituting only the model and final prompt:

   ```bash
   omp --profile review \
     -p \
     --no-session \
     --no-extensions \
     --no-skills \
     --no-rules \
     --no-lsp \
     --tools read,grep,glob \
     --approval-mode always-ask \
     --model openrouter/x-ai/grok-4.5 \
     '<fully rendered prompt>'
   ```

   Pass the prompt as one literal argument. Do not add shell wrappers, environment prefixes, redirects, extra tools, extensions, skills, rules, or MCP configuration. Codex's managed permission rule matches this fixed read-only command shape.

4. Treat OMP as a long-running synchronous review. Start with a 30-second yield; if it is still running, poll every 60 seconds until exit. Silence alone is not a failure signal.
5. Relay the verdict and findings. For each finding, verify it against the documents and repository context before changing anything. Classify it as confirmed, rejected with specific reasoning, or needing clarification. Never blindly implement or silently skip feedback.

## Prompt template

```text
You are an adversarial reviewer of design documents. Review tier: {{TIER}}.
Your job is to find the strongest objections a senior engineer would raise
before implementation.

Files to review:
- Spec: {{SPEC_PATH}}
- Plan: {{PLAN_PATH}}

Read every supplied file in full. Use read, grep, and glob only when repository
context is needed. Do not edit files and do not run commands.

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

Omit absent file lines and the focus block rather than leaving placeholders.

## Failure handling

- Missing input: stop and report the exact path.
- Missing OMP profile or API key: stop and report the missing prerequisite without printing secret values.
- Nonzero OMP exit: report the exit status and returned error; diagnose before retrying.
- No findings: spot-check the reviewed documents yourself before continuing.
