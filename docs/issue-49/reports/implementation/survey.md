# Survey — issue #49: align rulebook with realized conformance-review spec

## Upstream spec (tokenmaxxxer/on-the-record, main)

`roles/specs/conformance-review.spec.json` (issue #521):

- `required_fields`: `subject` (ref), `test` (ref), `result` (enum:
  `passed|failed|cantTell|inapplicable|untested`), `assertedBy` (string).
  Source standard: EARL 1.0 Schema (W3C).
- `reference_resolution`: `test` must resolve to the actual conformance
  criterion (spec section / requirement / lint rule), not a vague
  description; `subject` must resolve to a real repo path or commit sha.
  `checked_by`: `on-the-record/hooks/role-spec-reference-guard.sh`.
- `recomputation`: overall verdict = worst-case across cited test entries
  (`failed > cantTell > inapplicable > untested > passed`), never an
  independently-asserted summary field (issue-515 invariant 4).
  `checked_by`: TBD — issue-521 marks per-role recomputation enforcement
  as a deliberate follow-up, not yet built.
- `write_scope`: `["docs/issue-<n>/reports/conformance-review.md"]`.
- `loop_state`: progress `["auditing"]`, terminal `["reported"]`,
  refusal `["spec-ambiguous"]`, error `["subject-unreadable"]`.
- `use_when.board_condition`: "an implementation commit landed on the
  branch AND no conformance-review record exists yet for this commit
  sha."

`roles/conformance-review.json` mirrors the same `write_scope` and
`loop_state`, adds `decides`/`produces`/`use_when` prose (Korean),
confirms role name is `conformance-review` (not `review`).

## This rulebook's current state

- **Role name mismatch (pre-existing, out of scope per issue text — "no
  role scope change"):** `README.md:1-9` and `review/hooks/directive.sh`
  both name the role `review`, record path `docs/issue-<n>/reports/review.md`
  or `conformance-review.md` (state.sh checks both), while the
  marketplace spec's role is `conformance-review`. `review/hooks/state.sh`
  already checks for both record filenames — the doubling is already
  tolerated in code, just not named in docs.
- **Vocabulary mismatch:** this rulebook's finding schema
  (`review-traceability/skills/finding-record/SKILL.md`,
  `review-traceability/hooks/traceability-gate.sh`) uses fields
  `spec_ref`, `verdict` (`Present|Surface|Absent|Incorrect|Unverifiable`),
  `evidence`, `rationale` — none of the spec's EARL field names
  (`subject`, `test`, `result`, `assertedBy`) appear anywhere in the repo
  (`grep -rn` confirms zero hits outside this survey/proposal).
- **`loop_state` mismatch:** `README.md:86` states
  `idle, scoped, auditing, draft-reported, reported` (terminal:
  `reported`) — a 5-state list. The spec's `conformance-review` role
  states 4 buckets: progress `auditing`, terminal `reported`, refusal
  `spec-ambiguous`, error `subject-unreadable`. `idle`, `scoped`,
  `draft-reported` are this rulebook's own values with no spec
  counterpart; `spec-ambiguous` and `subject-unreadable` do not appear
  anywhere in this rulebook's docs or hooks.
- **No `reference_resolution` analog:** `spec_ref`/evidence pointer
  checking exists (`traceability-gate.sh` denies a verdict without a
  `spec_ref:` + `evidence:` pair), but nothing states the resolution
  rule in the spec's terms (`test` must resolve to an actual
  criterion, `subject` to a real path/sha) or references a marketplace
  gate for it (`role-spec-reference-guard.sh` is not mentioned or
  installed here).
- **No `recomputation` analog:** nothing in this rulebook computes or
  checks a worst-case overall verdict across cited requirements; no
  document states the rule or notes it as upstream's declared
  follow-up.
- **No `use_when.board_condition` analog:** `directive.sh`'s `USE_WHEN`
  is prose describing phase timing, not the spec's machine-checkable
  board condition ("implementation commit landed AND no
  conformance-review record exists for this sha").
- **Severity vocabulary** (`review-severity`) and **record-norm**
  (`closed_checks:` vs `code_under_review:`) plugins have no spec
  counterpart in `conformance-review.spec.json` — spec doesn't mention
  severity or closed_checks, so no mismatch to fix there; leave as-is.

## Precedent: execution-observation-rulebook#63 (on-the-record PR #66)

Referenced in the issue as the completed pattern. That rulebook layered
its target spec's field/vocabulary names onto its existing finding
schema and README record-vocabulary section, added the spec's
loop_state states alongside (not replacing) role-specific ones where
the rulebook needed extra states beyond the spec's minimum, and pointed
at the marketplace's own reference/recomputation gates by name rather
than reimplementing them. No role-scope or write-scope change. (Not
independently re-fetched here — issue text names it as the pattern to
mirror; this repo's own current-state contrast above is what drives the
proposal.)

## Write-set implication

Files that need the spec's vocabulary layered in, and nowhere else:

- `README.md` — `## Record vocabulary` section: add EARL field names,
  correct the loop_state list to the spec's 4 buckets (keep this
  rulebook's extra progress states as an explicit superset, not a
  silent drop, since `scoped`/`idle`/`draft-reported` reflect real
  phase-1 states the spec's minimal role JSON doesn't need to name).
- `review-traceability/skills/finding-record/SKILL.md` — the finding
  schema section: cross-reference the EARL field each existing field
  maps to (`spec_ref`→`test`, subject-under-audit→`subject`,
  `verdict`→`result` with the value-set difference noted, reviewer
  identity→`assertedBy`), and state the reference_resolution and
  recomputation rules with a pointer to the marketplace gate/follow-up
  status.
- `docs/handbooks/review-hooks.md` — hooks catalog: note where
  reference-resolution and recomputation currently are NOT enforced by
  a local gate (spec's own `checked_by` fields say the guard lives in
  `on-the-record`, recomputation enforcement is TBD upstream) so a
  reader doesn't assume local enforcement exists.
- `review/hooks/directive.sh` — `USE_WHEN` string: fold in the spec's
  board_condition wording alongside the existing phase-timing prose.

No hook logic changes (no new gate, no new deny path) — this is a
docs-only alignment per the issue's "layer vocabulary onto existing
structures, no role scope change" instruction.
