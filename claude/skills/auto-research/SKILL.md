---
name: auto-research
description: Run an N-round autonomous research loop. Use when the user asks to auto-research a question, run iterative rounds, or explore a problem with multiple sequential agents. Sets up `auto_research/r<YYYYMMDD>_<short_title>/` with a prompt.md and optional auxiliary scripts, spawns one subagent per round sequentially (each working only in its own round_i folder), then synthesizes report.md covering the arc across rounds, top results, problems encountered, and recommendations.
---

# Auto-Research

Orchestrates iterative research. Each round is a fresh subagent that reads a shared `prompt.md`, forms ONE hypothesis, implements and evaluates it, and records findings that inform the next round. After all rounds, the orchestrator synthesizes a single report.

**Your role is orchestration.** You set up the workspace, dispatch subagents, and synthesize the final report. You do NOT do the research yourself.

## Arguments

- **Problem description** (free-form): the research question. If missing or ambiguous, ASK the user.
- **`n_rounds`** (integer, default **10**): number of rounds to run. If the user says "5 rounds" or "3 iterations" or similar, use that.

## Workflow

Create a TodoWrite task for each phase below and complete them in order.

### Phase 1 — Setup

1. **Parse arguments**. Extract `n_rounds` (default 10) and the problem description.
2. **Derive a short title** from the problem description. Use snake_case (e.g., `cn_portfolio`, `matmul_speedup`, `image_classifier`). Don't ask the user — just pick a sensible short name. The title must be a valid Python identifier fragment (letters, digits, underscores; no hyphens).
3. **Create the workspace folder** at `auto_research/r<YYYYMMDD>_<short_title>/` in the current working directory. Use today's date, no separators (e.g., `r20260419_cn_portfolio`). The `r` prefix + underscore-only convention keeps the folder name a valid Python identifier so scripts inside can be imported as `auto_research.r<YYYYMMDD>_<short_title>.xxx`.
4. **Draft `prompt.md`** in that folder (see template below). Fill in what you know from the user's description. **ASK the user** for anything you can't confidently fill — especially success criteria and evaluation methodology. Don't invent metrics or thresholds.
5. **Ask about auxiliary scripts**:
   > Does this research need auxiliary scripts? Common examples: a shared evaluation harness (like running the same backtest across many parameter sets), a data loader, plotting utilities, or pre-computed fixtures. Describe any you want and I'll draft them alongside prompt.md.

   If yes: discuss scope, create the scripts in the workspace folder, reference them from prompt.md.

6. **Confirm setup**. Show the folder tree (prompt.md + any aux files) and ask the user to approve before launching rounds.

### Phase 2 — Round execution (sequential, NEVER parallel)

For each `i` in `1..n_rounds`:

7. **Create the round folder** yourself: `mkdir auto_research/<folder>/round_{i}/`. Do this before spawning the subagent so the subagent's working scope is unambiguous.

8. **Spawn one subagent** via the Agent tool with `subagent_type: "general-purpose"`. Use this prompt (fill the `<folder>` and `{i}` placeholders):

   > Read `auto_research/<folder>/prompt.md` and execute research round {i}.
   >
   > - Work ONLY inside `auto_research/<folder>/round_{i}/` (already created). Do not create, modify, or delete files anywhere else, EXCEPT to append your concise round summary to `prompt.md` under `## Round {i}` at the end.
   > - Read previous round summaries in prompt.md before forming your hypothesis.
   > - Form ONE hypothesis. Implement, evaluate, iterate as needed inside your round folder (editing scripts, fixing bugs, re-running is fine).
   > - After evaluation, do both of:
   >   1. Write detailed findings to `round_{i}/findings.md` (sections: Hypothesis, Approach, Results, Analysis, Recommendations for Future Rounds).
   >   2. Append a concise 300–500 word summary to `prompt.md` under `## Round {i}`.
   > - If you hit a blocker you can't resolve: record the blocker clearly in findings.md and still append a round summary noting it. Do not leave the round silently incomplete.

9. **After the subagent returns**, verify:
   - `auto_research/<folder>/round_{i}/findings.md` exists and is non-empty.
   - `prompt.md` now has a `## Round {i}` section at the end.
   - If either is missing, stop and ask the user: retry the round, skip it, or abort the run?

10. **Commit the round** before moving on. Stage everything under `auto_research/<folder>/` and commit with a message like `auto-research(<folder>): round {i}`. This gives a clean checkpoint per round so failed/regrettable rounds can be reverted independently and the report can reference round-level diffs.

11. **Between rounds, do nothing else**. Don't edit prompt.md yourself. Don't preview findings. Just proceed to the next round — the next subagent reads the updated prompt.md automatically.

### Phase 3 — Report synthesis

After all `n_rounds` complete:

12. **Read all round summaries** from `prompt.md`.
13. **Read individual `round_{i}/findings.md`** files when you need specific detail the summary doesn't carry (e.g., for the §2 best-results table or §3 problems section).
14. **Write `report.md`** in `auto_research/<folder>/` with these sections (adapt section count to what was discovered):
    - **§1 Overall Summary** — the arc of the research as a table: `| round | what moved | key outcome |`. Follow with the final committed answer / best finding if one emerged, including robust uncertainty if the research produced it.
    - **§2 Top-N Best Results** — ranked table of the best configurations or outcomes. Include source round for each. Be honest about which numbers are single-seed / single-run vs. robust estimates.
    - **§3 Problems Encountered & Improvements Needed** — bugs, methodology issues, infrastructure friction. Quote from findings.md where specific. Split into subcategories (e.g., codebase issues vs. evaluation issues) if the volume warrants.
    - **§4 Recommendations** — next steps and code/ideas worth promoting from research to production (if applicable). Rank by value × confidence.
15. **Commit the report** with a message like `auto-research(<folder>): final report`.
16. **Present the report path** to the user and offer to open it or discuss specific sections.

## prompt.md template

Use this structure. Replace placeholders and ask the user for anything ambiguous BEFORE writing.

```markdown
# <title>

## Problem
<user's research question, refined into a clear, self-contained problem statement>

## Success criteria
<metrics, constraints, thresholds — ASK user if missing. Don't invent thresholds>

## Evaluation methodology
<how rounds should be evaluated — the same standard applied to every round.
ASK user if missing. Examples: "run backtest X across these dates", "score on
this held-out set", "measure on these benchmarks">

## Your Workflow (per round)

1. Read this entire prompt, including previous round summaries.
2. Your round folder (`round_{i}/`) has already been created for you. Work ONLY inside it.
3. Review previous rounds (summaries below; full detail in `round_{j}/findings.md`).
4. Form ONE hypothesis. Build on previous findings or start fresh if round 1.
5. Implement and evaluate. Iterate freely inside your round folder.
6. Record results:
   - Write `round_{i}/findings.md` (Hypothesis / Approach / Results / Analysis / Recommendations for Future Rounds)
   - Append a concise summary to this file under `## Round {i}` at the end.

## Constraints / Environment
<known constraints, data sources, tool availability, API limits, etc.>

## Codebase / Data Reference
<paths to relevant code, data, or tools — inferred from the current project
structure. Examples:
- portfolio strategies: `portfolio/`
- evaluation harness: `auto_research/<folder>/evaluate.py`
- market data: `data_access/`>

## Auxiliary Scripts
<list any aux scripts created during setup — their purpose and usage>

## Findings format (round_{i}/findings.md)

```
# Round {i} Findings

## Hypothesis
<what was tested>

## Approach
<how it was tested>

## Results
<concrete numbers / observations>

## Analysis
<interpretation>

## Recommendations for Future Rounds
<next-step suggestions>
```

---

## Round Summaries

(Agents: append your `## Round {i}` summary here after completing your round.)
```

## Orchestrator guidelines

- **Never spawn rounds in parallel.** Each round depends on the accumulated findings in prompt.md that earlier rounds wrote.
- **Don't do the research yourself.** Your job is setup → dispatch → synthesize.
- **Don't edit subagent output.** Preserve `round_*/findings.md` and existing `## Round {i}` sections verbatim.
- **Don't invent success criteria or metrics.** If the user hasn't defined them, ask. A vague prompt produces diffuse research.
- **Be honest in the report.** Include failures and negative results. Distinguish best-single-seed from robust-ensemble numbers when relevant.
- **If interrupted mid-run**, you can resume: re-invoke the skill pointing at the same workspace, and it should pick up from the next unfilled round.

## Common pitfalls

- **Letting the first round start without user approval of the setup.** Always show the workspace and get a go-ahead at the end of Phase 1.
- **Spawning a subagent with a verbose prompt that duplicates prompt.md.** The subagent prompt should be short — just the dispatch instructions. All the problem context lives in prompt.md.
- **Forgetting to verify each round wrote both findings.md and the prompt.md summary.** Silent incomplete rounds will mislead subsequent rounds.
- **Writing report.md while rounds are still pending.** Report comes after ALL rounds complete.

## Example invocations

- `/auto-research find the best CN stock portfolio. 5 rounds.`
  → pick title `cn_portfolio`, folder `r20260419_cn_portfolio`, n_rounds: 5. Ask: what's "best"? (metrics, constraints, evaluation).

- `/auto-research optimize the matmul kernel for small inputs`
  → pick title `matmul_small`, folder `r20260419_matmul_small`, n_rounds: 10 (default). Ask: what's "small"? baseline? target speedup? hardware?

- User, mid-conversation: "run auto-research on whether we can replace the legacy parser with a grammar-based one"
  → pick title `parser_grammar_migration`, folder `r20260419_parser_grammar_migration`, n_rounds: 10. Ask: what's the success criterion? (correctness rate? performance? code-size reduction?)
