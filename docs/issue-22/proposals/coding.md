# issue-22 build proposal (coding)

files: `review/hooks/directive.sh`

## Request (paraphrased intent)
Wake-routing ownership migration step 3: this rulebook must contain
NOTHING about which role wakes next. Keep this role's own record
states/format; strip or repoint to on-the-record's
`docs/specs/wake-routing.md` anything that names which role a state
summons — including this role's own trigger list, if restated.

## Constraints
- Single file in scope: `review/hooks/directive.sh`, the "YOUR RECORD IS
  THE BOARD" closing section (lines 61-68).
- `docs/proposals/2026-07-26-contract-v2-conformance.md` is a historical
  decision record, not live rulebook text; out of scope, left untouched.
- Keep: which file is review's own record, when to write it (first act
  of phase 2), when to update loop_state.
- Strip: the WAKES-ON mechanism's general consumption/consequence prose
  ("no downstream role... woken", "machine wake-up dead") — this now
  duplicates canon at on-the-record `docs/specs/wake-routing.md`.
- Repoint: replace the stripped routing explanation with a pointer to
  on-the-record `docs/specs/wake-routing.md` for how WAKES-ON consumption
  works.

## What will be done (phase 2, after human APPROVE)
Rewrite `review/hooks/directive.sh` lines 61-68 to read approximately:

    YOUR RECORD IS THE BOARD (do not skip this): review's record is
    docs/issue-<n>/reports/review.md — write it as your FIRST act of
    phase 2, and update its loop_state at every transition. How WAKES-ON
    consumes this record is canon at on-the-record
    docs/specs/wake-routing.md, not restated here.

  - Keeps the file name, write timing, and loop_state update rule (this
    role's own record state/format).
  - Drops "research files, surveys, and proposals wake no one" and the
    "no downstream role... woken" / "machine wake-up dead" consequence
    prose — general WAKES-ON mechanics, now the host doc's job.
  - Repoints to on-the-record `docs/specs/wake-routing.md` for routing
    behavior instead of restating it.
  - No other file in the repo carries WAKES-ON/wake text outside
    docs/issue-*, so no other rulebook file changes.

## Out of scope
- `docs/proposals/2026-07-26-contract-v2-conformance.md` (historical
  record, untouched).
- Any coding/qa/verify/core role directive — this repo carries only the
  `review` role's rulebook; other roles' directives live elsewhere
  (tokenmaxxxer-core per the issue).
- Creating or editing on-the-record's `docs/specs/wake-routing.md` itself
  — that lives in a different repo, out of this rulebook's scope.

## How I'll know it worked
`grep -rni "wake" --include="*.md" --include="*.sh" .` (excluding
`docs/issue-*` and the untouched historical proposal doc) shows no line
that restates which role a state summons or restates general WAKES-ON
consumption/consequence behavior — only this role's own record
state/format survives, plus a pointer to on-the-record
`docs/specs/wake-routing.md`.

## Phase gate
Phase 1 only, per issue-22 and contract v3 s19: this proposal + the
survey are committed and the PR opened; no execution, no edit to
`review/hooks/directive.sh` itself, no APPROVE from any role in this
session. Phase 2 begins in a later session after a human approver's
APPROVE.
