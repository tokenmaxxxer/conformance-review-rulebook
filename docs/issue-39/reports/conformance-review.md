---
subject: issue-39
role: review
loop_state: landed
---

# Phase-2 delivery record: plugin-set mechanization (issue #39)

## What was done

Implemented the approved proposal
(`docs/issue-39/proposals/conformance-review.md`, APPROVE
issue-39/conformance-review) exactly as frozen in sections (b)-(e): five
self-contained plugins replace the single `review` plugin's ad-hoc
methodology enforcement.

| Plugin | Files added/moved |
|---|---|
| `review` (deepened) | `hooks/directive.sh` (phase-1/phase-2 facet split), `hooks/state.sh` (new, informing-only `SessionStart`, resumes phase state from branch/artifact presence), `hooks/hooks.json` (SessionStart only — `closed-checks-gate.sh` PreToolUse entry removed, relocated), `.claude-plugin/plugin.json` (description trimmed to composition-root role) |
| `review-traceability` | `hooks/traceability-gate.sh` (phase-1 requirement-list/sampling-derivation check; phase-2 `spec_ref`/`evidence` field-copresence per verdict block), `skills/finding-record/` (relocated unchanged + per-requirement checklist appended), `tests/traceability-gate-test.sh` (10 cases), `.claude-plugin/plugin.json`, `hooks/hooks.json`, `README.md` |
| `review-severity` | `hooks/severity-gate.sh` (Chromium-5-band/MSFT-4-level table-lookup allow, DREAD-style numeric/averaged deny), `skills/severity-classification/` (relocated unchanged), `tests/severity-gate-test.sh` (9 cases), `.claude-plugin/plugin.json`, `hooks/hooks.json`, `README.md` |
| `review-record-norm` | `hooks/closed-checks-gate.sh` (relocated from `review/hooks/`, behavior byte-identical + `REVIEW_RECORD_NORM_GATE_OFF` kill-switch alias added), `tests/closed-checks-gate-test.sh` (4 cases), `.claude-plugin/plugin.json`, `hooks/hooks.json`, `README.md` |
| `review-proposal-completeness` | `hooks/proposal-completeness-gate.sh` (five structural sections per issue #30(a): Request, Constraints, sourced-adoption, adopt-vs-skip split, How-this-will-be-judged), `tests/proposal-completeness-gate-test.sh` (10 cases), `.claude-plugin/plugin.json`, `hooks/hooks.json`, `README.md` |

`.claude-plugin/marketplace.json` gained the four new `plugins` entries
per proposal (d), text unchanged from the frozen design. `install.sh`'s
`PLUGINS` array now installs all five plugins (the redundant `BUNDLE`
variable, which duplicated `review`, was removed rather than kept as a
second identical install path). `tests/run-gate-tests.sh` is now an
aggregate runner over the four new per-plugin test files (the prior
single-file harness's cases moved into `review-record-norm/tests/
closed-checks-gate-test.sh` unchanged).

## Why

Issue #30 adopted (phase 1) and reflected (phase 2, issues #37/#38) a
conformance methodology for this role, but that reflection lived only as
directive prose and skill text with no mechanical enforcement — the
rationale (based on: issue #39). Issue #39 asked to close that gap by
mechanizing the adopted methodology as a composable plugin set —
corrective feedback on the first proposal revision rejected a single
deepened directive plus one monolithic gate and required one
independent, kill-switchable, separately testable plugin per adopted
methodology, matching how `core` hosts `freelunch`/`scout` as separate
plugins rather than one merged one. This record implements that
corrected, approved design (upstream basis: `docs/issue-39/proposals/
conformance-review.md`, APPROVE issue-39/conformance-review).

## Verification

- `bash tests/run-gate-tests.sh`: **33/33 passed** across all four new
  plugin test files (10 traceability + 9 severity + 4 record-norm + 10
  proposal-completeness).
- `bash tests/deny-only-check.sh <plugin>/hooks` run per plugin: the
  `permissionDecision` scan is clean for all five (no `allow` grant
  anywhere). The shared script's second check (a "substance probe"
  asserting *some* gate in the directory refuses an empty
  `docs/issue-999/reports/review.md`) fails for `review-traceability`,
  `review-severity`, `review-record-norm`, and
  `review-proposal-completeness` individually — each plugin's own gate is
  narrowly scoped by design (traceability only checks when a verdict
  token exists; severity only when a `severity:` field exists;
  record-norm only when `closed_checks:` exists; proposal-completeness
  only fires on `proposals/review.md`, not `reports/review.md`), so none
  singularly denies a content-free write to that generic probe path.
  Confirmed via `git stash` against the pre-issue-39 `review/hooks`
  (single `closed-checks-gate.sh`) that this same probe already failed
  identically before this change — not a regression, a structural
  mismatch between the shared probe (written for a directory that
  bundles a record-fields-gate alongside a narrow gate) and this repo's
  now-decomposed plugin set. No relaxation of any existing check.
- `python3 -m json.tool` accepted every `plugin.json`/`hooks.json`/
  `marketplace.json` touched.
- `bash -n install.sh` passes.

## Deviations from the frozen phase-2 design

None. Every file/plugin named in proposal sections (b)-(e) exists;
`review-traceability`'s two firing surfaces
(`docs/issue-<n>/proposals/review.md` phase-1 and
`docs/issue-<n>/reports/(conformance-)?review.md` phase-2) match (a.2)'s
composition table; `closed-checks-gate.sh`'s deny/allow logic is
unchanged (only the kill-switch alias is additive); no canon or
sibling-rulebook script text was copied verbatim into any new gate —
each was rewritten structurally from the pattern in
`review/hooks/closed-checks-gate.sh` (now `review-record-norm/hooks/
closed-checks-gate.sh`), per the proposal's constraint.

Out of scope (per proposal, unchanged): no cross-plugin state-tracking
gate, no change to `core`'s `record-fields-gate.sh`, no re-litigation of
the adopted methodology.

## Open findings

None. All frozen phase-2 deliverables are present and their own test
suites pass; the one known gap (the shared `deny-only-check.sh`
substance probe's directory-level assumption) is pre-existing per the
`git stash` comparison above and is not a defect introduced by this
delivery.

code_under_review: 9bbb8e8
