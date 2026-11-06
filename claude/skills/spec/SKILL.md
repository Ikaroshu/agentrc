---
name: spec
description: Writes the implementation spec Codex builds from and gets the user's approval of it. Use once no design question remains open on work that needs a spec; not for design discussion.
---

# Spec

Don't ask whether to write the spec. If a design question is open, ask that instead; otherwise write it, because the written spec is what the user approves.

Save it to `<project-root>/.plans/specs/<YYYYMMDD>_<short_title>.md` from main, uncommitted, organized around:

- **Design:** responsibilities, interfaces, data flow, constraints, and material failure behavior.
- **Outcome:** observable success, active requirements, scope, and non-goals.
- **Verification:** behavioral evidence and exact checks that demonstrate delivery, leaving to implementation what working code can safely settle. If the change starts trusting state it used to recheck, confirm that state once on real data; this is a one-time check, not a runtime guard.

State what must be true, not phases, task order, commit boundaries, or code structure the design does not require. Codex has not seen this conversation: include the evidence, file paths, and constraints it needs to avoid guessing intent.

Check the draft against the conversation for dropped agreements, contradictions, and scope growth. Then ask for approval as a decision request in the `codex` skill's layout, naming what the spec decides that you and the user did not discuss, and any accepted limitation. On approval, proceed to the `codex` skill.
