---
status: proposed
files:
  - README.md
  - review-traceability/skills/finding-record/SKILL.md
  - docs/handbooks/review-hooks.md
  - review/hooks/directive.sh
---

## Request

Align this rulebook's methodology docs, handbook, and hooks with the
realized `conformance-review` role spec landed in marketplace issue #521
(`roles/specs/conformance-review.spec.json`, `tokenmaxxxer/on-the-record`):
layer the spec's EARL-derived per-claim evidence vocabulary
(`subject`/`test`/`result`/`assertedBy`), its 4-state `loop_state`, its
`reference_resolution`/`recomputation` rules, and its `use_when`
board condition onto this rulebook's existing structures — no role-scope
change, reference marketplace-owned gates by name rather than forking
their logic. Mirrors the completed execution-observation-rulebook #63
pattern.

## Constraints

- No role-scope change: this rulebook still decides
  `Present|Surface|Absent|Incorrect|Unverifiable` per requirement, never
  a holistic quality judgment.
- No forked enforcement: where the spec names a `checked_by` gate that
  lives in `on-the-record` (reference-resolution) or is itself marked
  TBD upstream (recomputation), this rulebook documents the rule and
  points at the marketplace owner — it does not implement a competing
  local gate.
- Docs-only write set: no hook logic (deny paths, regexes) changes: this
  is vocabulary alignment, not a new check.
- `loop_state` is additive, not replacing: this rulebook's phase-1
  states (`idle`, `scoped`, `draft-reported`) reflect real states the
  spec's minimal role JSON doesn't enumerate (the spec only names
  `auditing`/`reported`/`spec-ambiguous`/`subject-unreadable`) — keep
  them, documented as a superset, rather than deleting them to match
  the spec's count.

## Rationale

Considered forking `role-spec-reference-guard.sh`'s reference-resolution
check into a local `review-traceability` gate so this rulebook could
enforce it standalone. Rejected: the spec's own `checked_by` field
already names the marketplace hook as the owner, and this rulebook's
existing `traceability-gate.sh` already gates the weaker-but-related
"has a `spec_ref:`+`evidence:` pair" structural requirement; duplicating
the stronger semantic check here would drift out of sync with upstream's
definition the next time issue-521's spec changes, and the issue text
explicitly asks to "reference marketplace gates rather than forking rule
logic."

Considered dropping this rulebook's `idle`/`scoped`/`draft-reported`
loop_state values to match the spec's 4-state minimum exactly. Rejected:
those three values are load-bearing for `review/hooks/state.sh`'s
resume-state detection (it already branches on phase-1-vs-phase-2
existence of `proposals/review.md` vs `reports/review.md|conformance-review.md`)
and for `finding-record/SKILL.md`'s own phase gating; the spec is a
minimum vocabulary the role must expose (`auditing`→`reported`, plus
refusal/error), not an exhaustive enumeration barring role-specific
richness — matching count over matching meaning would break existing
hook behavior for no spec-compliance gain.

## What will be done

- `README.md` `## Record vocabulary`: replace the flat loop_state list
  with the spec's bucketed form (progress/terminal/refusal/error),
  keeping this rulebook's extra progress states listed as a named
  superset; add a short EARL field-name cross-reference line mapping
  `verdict`→`result`, `spec_ref`→`test`, subject-under-audit→`subject`,
  reviewer identity→`assertedBy`.
- `review-traceability/skills/finding-record/SKILL.md`: in the field
  list (spec_ref/subject/verdict/evidence/rationale section), add one
  line per field naming its EARL counterpart and the value-set
  difference where one exists (this rulebook's 5-value verdict vs the
  spec's 5-value `result` enum — different vocabularies, same
  cardinality); state the `reference_resolution` and `recomputation`
  rules verbatim from the spec, each followed by its `checked_by`/TBD
  status so a reader isn't misled into thinking a local gate enforces
  either.
- `docs/handbooks/review-hooks.md`: add a short subsection noting which
  of the spec's rules (`reference_resolution`, `recomputation`) are
  presently unenforced by any gate in this repo, and where enforcement
  is expected to land (`on-the-record` guard, or upstream follow-up).
- `review/hooks/directive.sh`: append the spec's `use_when.board_condition`
  sentence to the existing `USE_WHEN` string, alongside the current
  phase-timing prose (additive, not a replacement — the existing prose
  covers phase-1/phase-2 behavior the board condition doesn't state).

## Out of scope

- Any new or modified gate script / deny logic.
- Renaming the `review` role to `conformance-review` (tracked as the
  same kind of deliberate, un-renamed doubling as the `coding`/
  `implementation` plugin-vs-role split — a follow-up, not this issue).
- Implementing `role-spec-reference-guard.sh`-equivalent logic locally.
- Implementing recomputation enforcement (explicitly TBD upstream per
  issue-521).
- `review-severity` / `review-record-norm` plugin content — the spec
  has no severity or closed_checks fields, so nothing there mismatches.

## How you'll know it worked

- `grep` for each of `subject`, `test`, `result`, `assertedBy` (the
  spec's `required_fields` names) across this rulebook's
  methodology/handbook docs exits 0 for each (issue's acceptance
  check).
- `grep -oE` the loop_state vocabulary out of `README.md` and diff it
  against the spec's `loop_state` value set — the four spec buckets are
  present verbatim; the diff (extra rulebook-only states) is shown in
  the phase-2 record, not hidden.
- `python3 -m pytest -q` exits 0, or (this repo has no pytest suite —
  it's bash-based) the record states
  `unverifiable: no test suite present` per the issue's own fallback
  clause; existing `bash tests/run-gate-tests.sh` still passes
  unchanged since no hook logic is touched.
