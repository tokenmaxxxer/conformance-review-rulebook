---
kind: coding-record
subject: issue-49
produced_by: implementation
code_under_review: README.md, review-traceability/skills/finding-record/SKILL.md, docs/handbooks/review-hooks.md, review/hooks/directive.sh
loop_state: landed
---

# implementation record — issue-49

## Summary of work

Layered `roles/specs/conformance-review.spec.json`'s (tokenmaxxxer/on-the-record,
main, blob sha `fe597307b3b3f2ecebf13788cd9d2c48b28638c4`) EARL-derived
vocabulary onto this rulebook's existing methodology docs/handbook/hooks per
the approved phase-1 proposal, with no role-scope change and no forked
enforcement logic:

- `README.md` `## Record vocabulary` — replaced the flat `loop_state` list
  with the spec's bucketed form (progress/terminal/refusal/error), keeping
  this rulebook's extra `idle`/`scoped`/`draft-reported` progress states
  as a named superset, and added an EARL field cross-reference line
  (`verdict`→`result`, `spec_ref`→`test`, subject-under-audit→`subject`,
  reviewer identity→`assertedBy`).
- `review-traceability/skills/finding-record/SKILL.md` — added an EARL
  cross-reference note per field in "The artifact and its field list", and
  a new "EARL alignment (issue-521 spec)" section stating the
  `reference_resolution` and `recomputation` rules verbatim from the spec,
  each with its `checked_by`/TBD status.
- `docs/handbooks/review-hooks.md` — added a "conformance-review spec
  alignment (issue-521)" subsection naming which spec rules
  (`reference_resolution`, `recomputation`) are presently unenforced by
  any gate in this repo and where enforcement is expected to land.
- `review/hooks/directive.sh` — appended the spec's
  `use_when.board_condition` sentence to `USE_WHEN`, additive to the
  existing phase-timing prose.

## Why

Basis: `docs/issue-49/proposals/implementation.md`, approved via issue
comment `APPROVE issue-49/implementation` (JiwonJung94, on issue #49).
Rationale for the approach (vocabulary layering, not a forked gate, not a
role-scope or loop_state-value change) is recorded in that proposal's
`## Rationale`.

## Acceptance checks (issue #49)

1. **required-field grep** — every `required_fields` name of the spec
   (`subject`, `test`, `result`, `assertedBy`) appears at least once in
   this rulebook's methodology/handbook docs:

   ```
   $ for f in subject test result assertedBy; do grep -rl "$f" README.md review-traceability/skills/finding-record/SKILL.md docs/handbooks/review-hooks.md >/dev/null && echo "$f: found" || echo "$f: MISSING"; done
   subject: found
   test: found
   result: found
   assertedBy: found
   ```

2. **loop_state set-diff** — this rulebook's `docs/hooks`
   (`review/hooks/directive.sh` via `USE_WHEN`, and `README.md`) vs the
   marketplace `roles/conformance-review.json` / spec state buckets
   (`progress: [auditing]`, `terminal: [reported]`,
   `refusal: [spec-ambiguous]`, `error: [subject-unreadable]`):

   ```
   spec buckets:        auditing, reported, spec-ambiguous, subject-unreadable
   rulebook README.md:  idle, scoped, auditing, draft-reported, reported
   diff (rulebook-only, extra progress states not in spec's 4-state minimum):
     idle
     scoped
     draft-reported
   diff (spec-only): none — all four spec states appear verbatim in README.md's bucketed form.
   ```

   Extra states are intentional (proposal `## Rationale`, second
   paragraph): the spec is a minimum vocabulary, not an exhaustive
   enumeration; dropping them would break `review/hooks/state.sh`'s
   resume-state detection.

3. **test suite** —

   ```
   $ python3 -m pytest -q
   no tests ran in 0.02s (exit 1 — no tests collected)
   ```
   `unverifiable: no test suite present` — this repo is bash-based (no
   `pytest.ini`/`conftest.py`/`*_test.py` anywhere in the tree). Ran the
   repo's actual gate suite instead, as the closest equivalent, since no
   hook logic was touched (docs-only write set):
   ```
   $ bash tests/run-gate-tests.sh
   == 4 suites passed, 0 suites failed ==
   ```

## closed_checks

- check: required-field grep — all 4 required_fields (`subject`, `test`,
  `result`, `assertedBy`) present across README.md,
  review-traceability/skills/finding-record/SKILL.md,
  docs/handbooks/review-hooks.md. result: passed.
- check: loop_state set-diff — spec-only diff empty (all 4 spec states
  present verbatim in README.md's bucketed form). result: passed.
- check: `bash tests/run-gate-tests.sh` — 4 suites passed, 0 failed;
  confirms no regression from the docs-only edits (unchanged hook logic).
  result: passed.

## What did not work

None.

## Open findings

Before-landing warrant hunt (stance 0, `docs/reports/2026-08-09-hunt-align-rulebook-vocabulary-with-conformance-review-spec.md`)
found that the new `USE_WHEN` clause in `review/hooks/directive.sh`
(the spec's `use_when.board_condition` sentence) is inert prose printed
once at SessionStart, not enforced by any script. Not treated as
blocking: `directive.sh` is core canon's `core_role_directive` stub — a
SessionStart informational call, never a PreToolUse gate (see
`docs/handbooks/review-hooks.md`, "No PreToolUse gate lives here
anymore"); the proposal's own `## Out of scope` excludes any new/modified
gate logic, and the spec itself names no `checked_by` for
`use_when.board_condition` (unlike `reference_resolution` and
`recomputation`, which do). Recorded here for visibility, not as a
defect to fix under this issue's scope.

## Doc placement

- `docs/handbooks/review-hooks.md` updated in this same commit (new
  subsection) — the doctrine-ladder home for a spec cross-reference note
  touching the handbook.
- No new env var / dependency / migration / setup step introduced — no
  other doctrine-ladder placement required.
