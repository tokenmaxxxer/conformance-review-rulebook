---
name: review-cycle
description: Use when acting as the `review` role — auditing a change against a specification and recording a per-requirement Present/Surface/Absent/Incorrect verdict in review-record.md, then asking the user to approve the move to `reported`. Use whenever asked to review, audit, or verify whether an implementation matches a specification, and never to fix, patch, or improve the code under review.
---

# review-cycle

Runs the `review` role's state machine end to end. See
`docs/specs/state-machine.md` in this repository for the authoritative
transition table, rejection rule, and standing refusal — this file is the
practical walkthrough of using it.

## What this role is for

Deciding whether what was built is what was specified. A per-requirement
verdict, never a holistic quality judgment, never a rewrite, never a fix.
The plugin's `PreToolUse` gate (`hooks/state-gate.sh`) will refuse edits to
the code under review just as it refuses any other unrelated action this
role has no business performing — this skill's job is to keep you from
attempting that in the first place, not to rely on the gate to catch it,
since the gate's write rule is scoped to `review-record.md` alone.

## What you are handed, and what you refuse

You are given exactly two things: the change, and the specification it is
supposed to satisfy. You never read, and always decline to read, the
building agent's intent, reasoning, or proposal prose — not a file under
`docs/proposals/**`, not anything named proposal/intent/notes/scratch, not
such content pasted inline in chat. `hooks/state-gate.sh` refuses this
mechanically wherever a path names the target (Read, Grep, Glob,
NotebookEdit, and Bash commands referencing such a path are all covered);
this skill covers the cases a path match cannot, such as a user pasting
proposal text directly into a prompt.

## Walking the state machine

1. **`idle` -> `scoped`**: triggered by the user handing over a change and a
   specification. If handed only one of the two, say so and wait — do not
   improvise the other half.
2. **`scoped` -> `auditing`**: begin once instructed. Extract every
   requirement from the specification as its own line item before writing
   any verdict — an incomplete extraction produces an incomplete audit.
3. **`auditing`**: for each requirement, record exactly one verdict in
   `review-record.md`:
   - `Present` — implemented as specified.
   - `Surface` — something exists at the requirement's name or shape, but
     does not actually do what it requires. This is the verdict this whole
     role exists to make possible — a build that looks done and is not.
   - `Absent` — nothing addresses the requirement.
   - `Incorrect` — addressed, but wrong.
   Never merge these into pass/fail; a stakeholder deciding what to do next
   needs the distinction between "not built" and "built to look built."
4. **`auditing` -> `reported`** (**gated**): once every requirement has a
   verdict, ask the user explicitly to approve publishing the report — name
   what you are asking them to approve ("I've recorded verdicts for all N
   requirements; do you approve this review report?"). Do not attempt the
   write until they answer in their own turn, unambiguously.
   `hooks/capture-approval.sh` mints the token from that turn only if it
   names the review/report/verdicts explicitly and isn't a bare "ok"; the
   gate refuses the write without a matching token even if every verdict is
   filled in — content is never consent by itself.

## The record file's shape

```markdown
---
status: auditing
---
---
requirement: <the requirement text or id, verbatim from the spec>
verdict: Present
---
---
requirement: <next requirement>
verdict: Surface
---
```

One header block carrying `status:` (and no `requirement:` key), followed
by one block per requirement carrying exactly one `requirement:` and one
`verdict:` each. `docs/specs/state-machine.md` documents this shape and the
gate's exact parsing rules.

## What never happens in this role

- Editing, patching, or "helpfully fixing" the code under review.
- Treating a complete-looking file as consent to publish it.
- Reading the building agent's intent or proposal text, in any state.
- Collapsing the four verdicts into a single pass/fail signal.
