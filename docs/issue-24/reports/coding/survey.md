# Current-state survey — issue-24

Scout skip: pure text-strip against a literal spec (issue names the exact
vocabulary to remove and what must remain) — no design decision open.

## Write set

Grepped repo (excluding docs/issue-*, docs/proposals, docs/reports —
historical, untouched per issue) for: WAKES-ON, wake-routing,
board-as-routing, downstream role, "is the board", woken, wake.

Only hit: `review/hooks/directive.sh:61-65` — the "YOUR RECORD IS THE
BOARD" section, naming WAKES-ON and pointing to
docs/specs/wake-routing.md.

`docs/specs/wake-routing.md` itself does not exist in this repo (it is
on-the-record's canon, external). No other rulebook file, skill, gate
script, or plugin manifest under `review/` or `.claude-plugin/` carries
this vocabulary.

## What changed

Reworded the section as a record-format requirement: path, kind
(loop_state field), required fields (code_under_review:, requirement
list/sampling derivation, verdicts+evidence, closed_checks:,
loop_state:), write-first-in-phase-2, update-on-every-transition,
commit-on-branch. Removed "board", "WAKES-ON", and the wake-routing.md
pointer.
