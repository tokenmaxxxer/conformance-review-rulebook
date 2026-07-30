# Build proposal — issue-24

files: review/hooks/directive.sh

## Request (paraphrased)

Strip routing-side vocabulary (wake, board-as-routing-device, WAKES-ON,
downstream roles, pointers to wake-routing.md) from review's rulebook;
restate the record obligation purely as a record-format requirement.

## Constraints

- Historical docs (docs/issue-*, docs/proposals, docs/reports) untouched.
- No mention of wake, waking, board-as-routing, WAKES-ON, downstream
  roles, or who reads the record.
- Recording deliverables under docs/ stays — only routing-device framing
  goes.

## What will be done

Reword `review/hooks/directive.sh`'s "YOUR RECORD IS THE BOARD" section
into a "RECORD FORMAT" section: path, write-first-in-phase-2,
loop_state-update-on-every-transition, required fields, commit-on-branch
— no routing vocabulary, no wake-routing.md pointer.

## Out of scope

Any other role's rulebook (none exist in this repo besides review/).
docs/specs/wake-routing.md (external canon, not present in this repo).
Historical docs.

## How you'll know it worked

`grep -rn "WAKES-ON\|wake-routing\|board-as-routing\|downstream role" review/`
returns nothing.
