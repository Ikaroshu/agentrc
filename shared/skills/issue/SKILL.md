---
name: issue
description: Read a GitHub issue, explore the code to understand it, and discuss the problem and solution with the user. Use when the user asks to triage an issue, look at issue #N, or work through a GitHub issue. Stops at discussion — writes no spec, plan, or code.
---

# Issue Triage Workflow

Read a GitHub issue, explore the code to understand it, and discuss the problem and solution with the user.

Usage: `issue <issue-link-or-number>`

**Announce at start:** "Running issue workflow."

This workflow stops at discussion. It does NOT write a spec, plan, or any code, and never edits files — that comes later, once the user agrees on a direction.

## Step 1: Read the Issue

Fetch the issue with `gh`:

```bash
gh issue view <number> --comments
```

The argument may be a full URL, an `owner/repo#number` reference, or a bare number. For a URL or cross-repo reference, pass `--repo <owner/repo>`. Read the body and every comment.

Then pull any issue it references (`gh issue view <n>`) and scan related/sibling issues (`gh issue list`). Note which are duplicates, already closed, or deliberately sequenced before/after this one.

## Step 2: Explore and Verify (read-only)

**Treat the issue body as a hypothesis to verify, not a spec to echo.** The reporter — often the user himself — may be wrong, vague, or describing a problem that's already been partly fixed. Your main value is catching that.

Ground everything in code you actually read:

- **Open every file/line the issue cites** and confirm the described behavior is really there. Flag anything the issue gets wrong (a claimed bug that doesn't reproduce, a proposed signature that doesn't fit, a "missing" thing that already exists).
- **Check whether it's stale or already solved** — read recent commits/merges touching the area; part of the issue may already be done.
- **Map the blast radius** — grep for importers/callers/consumers and the tests that pin current behavior. Report counts (source vs. test). Note persisted-state risk (cache, pickle, on-disk schema).
- **Reproduce when surprised** — if a claim or data point is surprising, verify it empirically with a quick script before theorizing.

Use subagents for broad searches when the relevant code isn't obvious. Make no code changes — say so.

## Step 3: Present Your Understanding

Lead with the verdict, then support it. Keep it dense and `file:line`-precise, not prose paragraphs:

- **The real problem** — what's actually going wrong, in your own words. Separate the *symptom as filed* from the *root cause*, and name any distinct axes the issue conflates into one.
- **Root cause** — pinned to the specific enabling construct, with `file:line` references.
- **Blast radius** — the call sites / consumers / tests affected, with counts.
- **Status** — if the issue is stale, already subsumed by existing code, or partly fixed, say so plainly. A "what's already done / what's left" split when relevant.
- **Settled vs. open** — what the issue makes unambiguous (no need to discuss) vs. the genuine decisions where the answer changes the outcome.

If your reading of the code contradicts the issue's description, say so directly.

## Step 4: Discuss

Work through the open decisions — only the ones where the choice actually changes the outcome. Pin them one fork at a time; the user answers tersely ("A", "1", "confirm") and expects forward motion after each.

- Present options as a short labeled list (A/B/C), each with its cost, and give a **recommendation** with a one-line why — not a neutral menu.
- **Flag any new method, parameter, or abstraction you'd introduce as its own decision point** ("do we need this, or can existing X carry it?"). Prefer the smallest change that fixes the root cause. Respect the project + global instruction conventions (namespace packages, no `__init__.py` just for scaffolding, the underscore-privacy house rule, fail-loud).
- **Non-code outcomes are valid endpoints** — propose them when they fit: document a limitation, re-scope/rewrite the issue body, or close-with-comment because existing code already subsumes it.
- **Offer to spin out-of-scope findings into separate deferred issues** rather than bloating this one. (Issue bodies stay problem + context + `file:line` references only — no proposed fix — unless the user says this is a personal work-queue item.)

Once the user is aligned on the approach, stop and let them decide the next step (the spec/plan workflow, or implementing directly). Do not start implementing on your own.
