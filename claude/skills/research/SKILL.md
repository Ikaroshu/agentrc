---
name: research
description: Run a research study with the user in discussed rounds, tracked on the study's board.md, delegating well-defined execution to Codex. Use only when the user invokes /research or asks to start, continue, or close a research study; not for incidental questions or investigation.
---

# Research

A study answers one research question through rounds. Claude and the user do the research together:
Claude proposes, runs, and interprets each round; the user decides the next round after discussing
the last one's results. Codex is the execution tool for well-defined work. The study's `board.md` is
its tracked state: the user reads it to stay informed, and any session resumes from it.

## Repository requirements

Before starting or resuming a study, read the research requirements the repository instructions
point to, if any. They may set the workspace location, branch naming, how experiments are executed
and evaluated, claim levels and evidence standards, extra sections for round reports and the final
report, finishing steps, and cleanup rules. Apply them on top of this skill; where they conflict
with it, the repository's requirements win. If the repository sets no workspace location, ask the
user where the workspace should live; it must stay out of version control and survive worktree
removal.

## Roles

- **User:** decides the question, what each round investigates and spends, and when the study ends.
- **Claude:** owns the research thinking — framing claims, designing rounds, interpreting evidence,
  keeping the board — and the discussion. Claude does exploratory and judgment-heavy work itself:
  reading data, quick probes, analysis, checking numbers.
- **Codex:** executes well-defined tasks that Claude specifies (see [Delegate to Codex](#delegate-to-codex)).
  Codex does not choose what the study tests or interpret its results.

Claude subagents are for well-defined, separable searches only, never the study's direction.

## Start a study

1. Settle with the user, in discussion: the question; the claims it concerns and what evidence would
   support or refute them (see [Claims and evidence](#claims-and-evidence)); scope, constraints, and
   non-goals; and what prior work already established. Ask about what is materially unclear; do not
   invent thresholds.
2. Create one research branch and worktree under `<project-root>/.worktrees/`, based on
   `origin/main` unless the user names another base, following the repository's branch and
   worktree rules. Claude and Codex share this one worktree with disjoint file ownership;
   incompatible variants live side by side under different names, flags, or modules.
3. Create the study workspace, with `board.md` from the [board template](board-template.md) and an
   empty `rounds/`.
4. Plan round 1 and stop for the user's decision.

## Rounds

A round investigates one focused question. It may contain as many experiments, variants, and
follow-ups as that question needs, but the user decides each round before it starts.

### Plan a round

Add the round to the board with status `proposed`:

- the question, and why it is the most informative next step now;
- the claims it tests and the level of each;
- the approach: data, method, comparisons, and controls; which parts Claude does and which go to Codex;
- what results would mean: what would support, refute, or leave open each claim, and what would
  change the study's direction;
- the cost: expected time, compute, and paid runs with their estimated cost.

Present the plan in conversation and stop. Discussion may change it. The user's go authorizes the
round's plan and spend.

### Run a round

- Work in `rounds/NN_<name>/`: research-only code, scripts, results, figures, and `notes.md`, which
  records what ran, the exact commands, the results, and how the plan changed.
- Adapt freely within the round's question and budget. Check in early, and stop, when a result
  changes the question, the plan needs spend beyond the approval, a blocker appears, or a surprise
  bears on the user's judgment, such as a data defect.
- Before reporting a number that decides a claim, recompute or spot-check it, and confirm the code
  computed what the claim needs, such as using only data available at decision time.
- Keep the board's status line current, including what the round is waiting on.

### Report and discuss

When the round finishes, update the board — the round's result, the claims, open angles, and spend —
and report in conversation. Size the report to what happened; it opens a discussion. Cover:

- **What we did,** including deviations from the plan.
- **Results:** the key numbers, tables or figures with their paths, and surprises.
- **What this shows and what it does not:** each claim's new status and the level it holds at; what
  remains confounded or untested.
- **Where to go next:** the candidate next rounds worth considering, what each would tell us and
  cost, and your recommendation with its reasoning — or a recommendation to stop.
- **Questions only the user can judge.**
- Any section the repository requires.

Then stop. Discuss until the user decides the next round, a different direction, or to finish.
Record the decision and its reason in the round's board entry before planning the next round.

Never start a round on your own. The exception is a standing instruction the user gives explicitly,
such as "keep sweeping the lookback while results stay clean": record it on the board with its
limits, and stop at the first result outside them.

## Claims and evidence

- State each claim at the level it concerns, using the repository's claim levels when it defines
  them. For example, whether an input carries information is a different claim from whether a
  system using that input performs better.
- A result supports or refutes a claim only at the level it was measured. "Adding the input did not
  improve system X" refutes that claim, not "the input carries no information". Leave the unmeasured
  levels open on the board instead of closing them by inference.
- Choose measures, controls, and samples that fit the claim, and settle the evidence standard with
  the user when it decides a conclusion.
- Distinguish robust evidence from exploratory or single-run evidence. Negative results are
  findings; record what they rule out.

## Delegate to Codex

Hand Codex a task when it is well defined: what to build or run, its inputs and outputs, and how to
check it are known. Examples: implement a described experiment harness or feature, add a data
loader, port a prior study's code, run a batch of evaluations and collect the results, run a sweep.
Keep work whose next step depends on what you see: exploring data, choosing comparisons, interpreting.

1. Write the task to `rounds/NN_<name>/tasks/<task>.md`: the goal and how it serves the round; the
   exact inputs, paths, and references; the expected outputs and where they go; the checks that show
   it is done right; the owned files; and the limits — work in the study worktree under the
   [experimental-code exception](#experimental-code), start no agents, do not merge or push, and the
   paid runs and budget it may use, if any.
2. Start the study's Codex session following the `herdr` skill:
   `hc run --bg --name codex-research-<short_title> --cwd <worktree> codex --no-daemon "$brief"`,
   where the brief names the sender (Claude at `$HC_TERMINAL_ID`), the task file, and the report
   route: `hc send <claude address> "<report>"`, with longer reports written next to the task file.
   Reuse the session for later tasks when its accumulated context helps; start a fresh one for
   unrelated work.
3. Continue work that does not depend on the task, or end the turn. Codex reports arrive as
   `<hc from="...">` input.
4. Before using the result, read the diff of load-bearing code and check the outputs as
   [Run a round](#run-a-round) requires. Send defects back to the same session.

Answer Codex questions within the approved round plan; take changes to the plan or spend to the user.

## Experimental code

Any code change the research needs is allowed in the study worktree, including shared repository
code, and it need not preserve the production structure. This is an explicit exception to the
development workflow: no spec, test gate, code review, or acceptance gate is required. Supporting
research claims with evidence remains required. Keep research-only code in the workspace when it
need not live in the repository. Promoting code to `main` is a separate user-approved task under the
normal development workflow.

## Resume a study

Read the repository requirements, `board.md`, and the current round's `notes.md` and task reports;
check the status of any Codex session or run the board says the round is waiting on; and continue
from the board's status.

## Finish a study

When the user decides to finish, write `report.md` in the workspace: the question and the answer at
each level studied; the claims and their final status; how the rounds changed the hypotheses; the
strongest positive and negative results; uncertainty and limitations, separating robust from
exploratory evidence; and ranked recommendations. Identify the branch, list its code changes and
which are worth keeping and why, and state the tests or reviews run and the validation still needed
before adoption. Add any section and finishing step the repository requires. Then close the study.

## Close a study

Treat an explicit request such as "close the study" as a request to assess retention and finish
cleanup, not to start another round.

Review `report.md`, branch-only commits, working changes, and untracked or ignored files for anything
worth retaining or merging. If worthwhile work still needs a retention or merge decision, tell the
user exactly what, why it is useful, and your recommendation, and keep the worktree and branch until
the user decides; closing alone does not authorize merging.

Otherwise, after checking that no Codex session, job, or pending consumer needs them, stop the
study's Codex sessions (`hc kill`, `hc rm`) and remove the worktree and its local branch. The close
request authorizes this cleanup, including discarding experimental commits assessed as not worth
keeping, without another confirmation; it does not authorize remote branch or cloud deletion. Keep
the board, round notes, task files, scripts, reports, compact results, and unique or expensive
inputs; remove regenerable bulk under the repository's cleanup rules. Record the disposition in
`report.md`, set the board's status to `closed`, and report retained paths with their purpose.

## Constraints

- Do not fabricate experiments, results, metrics, or success criteria.
- The board is the current state; round folders are the history. Do not rewrite a past round's
  notes or reports; when later evidence disproves a recorded claim, add a dated, labeled correction.
