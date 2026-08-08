# review plugin set — current state

Current state. Edited from now on to stay true.

Issue #39 replaced the single `review` plugin's ad-hoc methodology
enforcement with **five self-contained plugins**, each independently
registered in `.claude-plugin/marketplace.json` and installed by
`install.sh`'s `PLUGINS` array, plus a sixth one-install bundle
(`review-agent-env`, no code of its own — declares the five above as
`dependencies`; added to the marketplace/README/`install.sh` in issue
#45). A third check, stub-check, remains core canon (core #69) and is
run by reference against the installed `core` plugin — never vendored as
a local copy.

All four gates below (`review-traceability`, `review-severity`,
`review-record-norm`, `review-proposal-completeness`) are dispatched on
matcher `Write|Edit|MultiEdit|NotebookEdit|Bash` — `Bash` and
`NotebookEdit` both landed in issue #45 (`Bash`'s content-scan branch was
implemented and tested before this but not registered in the matcher, a
dead branch; `NotebookEdit` was matcher-advertised but silently allowed
through in code, a no-op). Each `*-gate.sh`'s `. ".../gate-lib.sh"` source
line (and `review/hooks/directive.sh`'s `. ".../role-directive.sh"`)
carries a `||`-guard, per core issue #75's fail-open fix, applied by
reference — an unreachable core denies (exit 2) rather than silently
allowing every write through.

- `review/hooks/` — role identity / phase protocol, the composition root:
  - `directive.sh` — SessionStart stub. Sources core canon's
    `core/hooks/lib/role-directive.sh` and calls `core_role_directive`
    with review's four role-unique values (YOU DECIDE / USE_WHEN /
    PRODUCES / HAND-OFF), now spelling out the phase-1/phase-2 split. No
    local boilerplate; core's `stub-check.sh`, run by reference, enforces
    this shape.
  - `state.sh` — new SessionStart hook, informing only (never
    blocks/denies). On resume, restates which phase the current subject
    is in (derived from branch name + presence of `docs/issue-<n>/
    proposals/review.md` / `docs/issue-<n>/reports/(conformance-)?
    review.md`) and therefore which sibling plugins' gates are live for
    it.
  - No PreToolUse gate lives here anymore — `closed-checks-gate.sh`
    relocated to `review-record-norm/` (below).
- `review-traceability/hooks/traceability-gate.sh` — PreToolUse
  (Write|Edit|MultiEdit|NotebookEdit|Bash). Phase-1 mode (`docs/issue-<n>/proposals/
  review.md`): requires a requirement list or an explicit sampling
  derivation. Phase-2 mode (`docs/issue-<n>/reports/(conformance-)?
  review.md`): every verdict token (`Present|Surface|Absent|Incorrect|
  Unverifiable`) must sit in a block that also carries `spec_ref:` and
  (unless `Unverifiable`) `evidence:` — this is where the issue #37/#38
  `spec_ref` reflection is mechanically enforced. Kill switch
  `REVIEW_TRACEABILITY_GATE_OFF=1`. No core canon counterpart.
- `review-severity/hooks/severity-gate.sh` — PreToolUse, fires only when
  a `severity:` field is present in a phase-2 record. Allows Chromium
  5-band / Microsoft 4-level bug-bar tokens; denies DREAD-style
  numeric/averaged values. Kill switch `REVIEW_SEVERITY_GATE_OFF=1`. No
  core canon counterpart.
- `review-record-norm/hooks/closed-checks-gate.sh` — PreToolUse
  (Write|Edit|MultiEdit|NotebookEdit), relocated unchanged from
  `review/hooks/`. Role-specific: a `closed_checks` cite must match the
  record's `code_under_review:` sha, never the working branch HEAD.
  Kill switches `REVIEW_CYCLE_DISABLE=1` (original) and
  `REVIEW_RECORD_NORM_GATE_OFF=1` (added alias). No core canon
  counterpart.
- `review-proposal-completeness/hooks/proposal-completeness-gate.sh` —
  PreToolUse on `docs/issue-<n>/proposals/review.md`. freelunch-grade
  structural bar for this role's own phase-1 proposals (Request /
  Constraints / sourced-adoption / adopt-vs-skip / How-this-will-be-
  judged). Kill switch `REVIEW_PROPOSAL_COMPLETENESS_GATE_OFF=1`. No core
  canon counterpart.
- `review-agent-env/` — one-install bundle, no `hooks.json`/code of its
  own (out of scope for the matcher/code parity check by construction —
  it has no PreToolUse branch to reconcile). `dependencies` in its
  `plugin.json` names the five plugins above.
- `stub-check.sh` — core canon (`core/hooks/tests/stub-check.sh`), run by
  reference against the installed `core` plugin, not vendored under
  `review/hooks/`. Fails if a vendored copy of `trailer-gate.sh` /
  `record-fields-gate.sh` / `handbook-trigger-gate.sh` / `parse-check.sh`
  (or `stub-check.sh` itself) reappears under `review/hooks/` (depth ≤3),
  or if `directive.sh` regrows local boilerplate instead of staying a
  stub.

Commit-trailer enforcement (`Subject: issue-<n>`), §20 record-fields
minimum-content checks, and §21 same-turn handbook sync are **not**
vendored here — they are core canon (`core/hooks/hooks.json`, registered
core-side, matcher `.*`), fired for every plugin install once the `core`
plugin is present alongside `review` (issue-31, following core issues
#63/#66).

`tests/run-gate-tests.sh` (repo-level, never installed) is now an
aggregate runner over the four new per-plugin test files
(`review-traceability/tests/traceability-gate-test.sh`,
`review-severity/tests/severity-gate-test.sh`,
`review-record-norm/tests/closed-checks-gate-test.sh`,
`review-proposal-completeness/tests/proposal-completeness-gate-test.sh`)
— the three promoted core gates' test coverage still lives in core's own
test suite.

## conformance-review spec alignment (issue-521)

The marketplace `conformance-review` role spec
(`roles/specs/conformance-review.spec.json`, `tokenmaxxxer/on-the-record`
issue-521) names two rules over this rulebook's own
`subject`/`test`/`result`/`assertedBy`-equivalent vocabulary
(`review-traceability/skills/finding-record/SKILL.md`'s
`spec_ref`/`verdict`/`evidence` fields). Neither is enforced by any gate
in this repo:

- `reference_resolution` (test/subject must resolve to a real conformance
  criterion and repo path, not a vague description) — `checked_by`
  `on-the-record/hooks/role-spec-reference-guard.sh`, owned and enforced
  upstream in `tokenmaxxxer/on-the-record`. This rulebook's own
  `review-traceability/hooks/traceability-gate.sh` enforces a weaker,
  related structural requirement (a `spec_ref:`+`evidence:` pair must be
  present), not the semantic resolution check.
- `recomputation` (overall verdict = worst-case result across cited
  entries, never an independently-asserted summary) — `checked_by`: TBD
  upstream (issue-521 out-of-scope note); unenforced anywhere, including
  here.

## Known gap

Core's `record-fields-gate.sh` defaults `RECORD_FIELDS_TERMINAL_STATES` to
`{"landed"}` and, being registered core-side with a fixed command line,
exposes no per-rulebook override path. This role's own terminal states
(`review`'s `reported`, `implementation`'s `phase2_complete`) are not in
that default set, so a genuinely-terminal record here is currently treated
as still-open by core's gate until a per-rulebook override mechanism is
added core-side. See `docs/issue-31/reports/implementation.md`'s "Open
findings" for the full detail and the recommended core-side fix.

The shared `tests/deny-only-check.sh` substance probe (an empty record
at `docs/issue-999/reports/review.md` must be refused by *some* gate in
the target directory) is directory-scoped and assumes a bundle that
includes a record-fields-style gate. Run per plugin
(`tests/deny-only-check.sh review-traceability/hooks`, etc.), each of the
four new narrowly-scoped gates fails that specific probe on its own,
since each only fires when its own trigger condition (a verdict token, a
`severity:` field, a `closed_checks:` entry, or a proposal-path write) is
actually present — this is a pre-existing property of a narrowly-scoped
gate (confirmed unchanged from before the issue #39 split, when the same
probe already failed against the single `closed-checks-gate.sh`), not a
regression. The `permissionDecision:allow` half of that same script does
pass cleanly for every plugin.
