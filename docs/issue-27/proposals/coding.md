# Build proposal — issue-27

files: review/hooks/directive.sh

## Request (paraphrased intent, secrets stripped)

The RECORD FORMAT section of review's role directive lacks the strong-form
enforcement clause and measured-evidence citation already present in other
rulebooks' record sections. Raise it to the same strong form, wording
only — no change to the required fields or format.

## Constraints

- Only `review/hooks/directive.sh` exists in this repo as a role
  directive; no other role's rulebook is present to change.
- Keep all existing role-specific record fields unchanged (path,
  write-first-in-phase-2, loop_state-update-on-every-transition,
  required fields, commit-on-branch).
- Wording-strength alignment only — not a format change.

## What will be done

Append two sentences to the end of the RECORD FORMAT section in
`review/hooks/directive.sh`:

1. Enforcement clause: "Ending phase 2 without your record committed on
   the branch means the record was never written."
2. Measured-evidence citation: "(Measured: a phase-1-only issue left the
   record empty.)"

## Out of scope

Any other role's rulebook (none exist in this repo besides review/).
Any change to the required-fields list, record path, or other sections
of the directive.

## How you'll know it worked

`grep -n "means the record was never written\|Measured: a phase-1-only issue left the record empty" review/hooks/directive.sh`
returns both lines, and the rest of the RECORD FORMAT section is
byte-identical to before.
