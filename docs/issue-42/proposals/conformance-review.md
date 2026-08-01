# Proposal — gate A+ remediation (issue #42)

## Request

Issue #42 requires this rulebook's four PreToolUse gates
(`review-traceability/hooks/traceability-gate.sh`,
`review-severity/hooks/severity-gate.sh`,
`review-record-norm/hooks/closed-checks-gate.sh`,
`review-proposal-completeness/hooks/proposal-completeness-gate.sh`) and
its repo-level checks / README raised from the audited grade B to A+, by:

1. Fixing the four confirmed defects (kill-switch inverted-default,
   `Edit`/`MultiEdit`/`replace_all` mis-reconstruction, repo-level checks
   passing vacuously post-split, README drift) — reference-adopting
   `core`'s gate-house standard (`core/hooks/lib/gate-lib.sh` +
   `gate-lib.py`, issue #72, now landed) rather than re-deriving fixes.
2. Raising the two bare-substring semantic checks (verdict-word scan,
   adoption-word scan) to section/adjacency/structural checks.
3. Adding the gate-house standard's six mandatory test cases to each
   plugin's own test file, plus this repo's semantic-upgrade cases, with
   the full suite green.
4. Resyncing `README.md` to the real repo/plugin/file layout.

Full detail of each confirmed defect and the gap analysis is in
`docs/issue-42/reports/conformance-review/current-state-survey.md`; scout
findings on the semantic-check redesign are in
`docs/issue-42/reports/conformance-review/scout-brief.md`. This is a
phase-1 proposal only — no execution work is included; per contract v3
s19, phase 2 opens only after a human Approve.

## Constraints

- **Reference, never reimplement.** Per the issue's precondition, all
  fixes to kill-switch/fail-closed-trap/path-normalize/write-reconstruct
  must source/import `core`'s `gate-lib.sh`/`gate-lib.py` (issue #72),
  not hand-roll an equivalent. `docs/handbooks/canon-scripts.md`'s
  reference-not-copy rule applies: `stub-check.sh` already flags a
  vendored copy of these files via `core/hooks/tests/canon-manifest.txt`.
- **No behavior change to the two already-correct checks.**
  `severity-gate.sh`'s closed-vocabulary check and
  `closed-checks-gate.sh`'s sha-prefix check are exact-value comparisons
  already, not substring scans — out of scope for the semantic-upgrade
  requirement; touch only their kill-switch/reconstruct/path plumbing.
- **Backward-compatible kill switches.** Existing env var names
  (`REVIEW_TRACEABILITY_GATE_OFF`, `REVIEW_SEVERITY_GATE_OFF`,
  `REVIEW_CYCLE_DISABLE`/`REVIEW_RECORD_NORM_GATE_OFF`,
  `REVIEW_PROPOSAL_COMPLETENESS_GATE_OFF`) must keep working; only the
  on/off orientation logic changes (delegate to
  `gate_kill_switch_active`), not the variable names or the documented
  on-spellings.
- **Every plugin's own test file stays self-contained** (per
  `tests/run-gate-tests.sh`'s existing aggregate-runner shape) — new
  gate-lib mandatory cases are added to each plugin's existing
  `*-gate-test.sh`, not centralized into a new file that would need its
  own wiring into the runner.
- **Full suite green at delivery.** `tests/run-gate-tests.sh`,
  `tests/parse-check.sh`, and `tests/deny-only-check.sh` must all pass
  after remediation, and the vacuous-pass bug in the latter two must
  itself be fixed and demonstrated (a probe that would have silently
  passed before must now actually run against all five plugins' hooks).

## Adopted (with source)

- **Adopt `gate-lib.sh`/`gate-lib.py` by reference for all four gates'**
  fail-closed trap, kill-switch check, JSON parse, path normalize, and
  Write/Edit/MultiEdit reconstruction, per
  `docs/handbooks/gate-house-standard.md` (core issue #72, landed at
  `tokenmaxxxer-core@22a7cad`) — this is the exact shared library the
  issue's precondition names, and its handbook's "Per-repo migration
  checklist" section is the adoption procedure this proposal follows.
- **Adopt `compliance-check.sh` as the pre/post gate** — run
  `core/hooks/tests/compliance-check.sh` against this repo's hooks before
  remediation (recording the violation list, matching the migration
  checklist's step 1) and again after (must be clean), per the same
  handbook.
- **Adopt label/block-adjacency matching for the two semantic checks**,
  per this proposal's own scout brief
  (`docs/issue-42/reports/conformance-review/scout-brief.md`), which
  found every surveyed structural validator (remark-lint-frontmatter-
  schema, PyMarkdown front-matter extension, markdownlint) checks a
  *parsed structural position*, never a bare document-wide substring —
  concretely:
  - `traceability-gate.sh`: a verdict only counts when it sits on (or
    immediately follows, same line/next-non-blank-line) a
    `verdict:`-labeled field — not anywhere the bare word appears in
    prose — eliminating the "surface area"/"data present" false-positive
    class named in the issue.
  - `proposal-completeness-gate.sh`: the sourced-adoption check requires
    the "adopt(ed)" clause and the source-attribution pattern to sit in
    the *same sentence or an immediately adjacent list item*, not merely
    the same (potentially multi-topic) paragraph.

## Skipped / out of scope

- **Full CommonMark/AST-based markdown parsing** for the semantic
  checks — the scout brief's adopt/skip judgment: disproportionate new
  dependency for a bash/python hook; adjacency/line-scan regex reaches
  the same structural precision the issue asks for ("섹션/인접성/구조")
  without it.
- **Rewriting `severity-gate.sh`/`closed-checks-gate.sh`'s value checks**
  — already exact-match, not substring; only their plumbing (kill-switch,
  reconstruct, path-normalize) migrates.
- **Changing the phase-1/phase-2 filename patterns the gates match**
  (`proposals/review.md`, `reports/(conformance-)?review.md`) — a
  pre-existing mismatch against this repo's actual
  `proposals/conformance-review.md` naming convention (see this very
  file's path) is out of scope for issue #42, which names four specific
  defect classes, not the filename-pattern question; flagged here for a
  future issue, not fixed in this one.
- **Any phase-2 execution work** (the actual code edits, test additions,
  README rewrite) — deferred to phase 2 per contract v3 s19; this
  proposal is phase-1 design only.

## How this will be judged

- `core/hooks/tests/compliance-check.sh review-traceability/hooks`
  (and the other three plugin dirs) exits 0 with no violations, where it
  currently flags the hand-rolled kill-switch/reconstruct pattern in all
  four.
- `bash tests/run-gate-tests.sh` passes with all four suites green,
  including each plugin's added six gate-lib mandatory cases (`Edit
  replace_all:true` on a multiply-occurring string, mixed-`replace_all`
  `MultiEdit`, malformed/empty/non-object JSON, unrecognized kill-switch
  value asserting the gate stays active, absolute + `./`-prefixed path
  matching the same scope as a relative fixture, and a `Bash`-tool file
  write reaching the same target a `Write` call would hit) plus new
  semantic-adjacency test cases (a "surface area"/"present" false-
  positive fixture that must now pass, and an "adopt...unrelated source
  elsewhere in paragraph" fixture that must now fail).
- `bash tests/parse-check.sh` and `bash tests/deny-only-check.sh`, run
  with no arguments (i.e. their own defaults, as README documents),
  actually exercise all five plugins' hook files — verified by a
  deliberately-broken fixture gate placed under one of the five plugin
  dirs causing a non-zero exit, proving the check no longer passes
  vacuously.
- `README.md`'s repo name, file paths, and install command match
  `.claude-plugin/marketplace.json` and the real directory layout
  byte-for-byte checkable (`grep` for each path/name the README cites
  resolves to a real file).
