# tokenmaxxxer / conformance-review-rulebook

The `review` role on contract v3. A review session is spawned with two
plugin sets installed: this marketplace's (`tokenmaxxxer-review`) five
plugins, and the
[tokenmaxxxer-core](https://github.com/tokenmaxxxer/tokenmaxxxer-core)
plugins (`core`, `terse`, `freelunch`, `scout`). Core owns the interaction
protocol — issue in, two-phase PR out (research/survey/proposal → human
review Approve → execution), branch `issue-<n>/conformance-review`, record
at `docs/issue-<n>/reports/conformance-review.md`. This rulebook owns only
what is review-specific.

## What `review` decides

Whether what was built matches what was specified — a per-requirement
verdict (`Present | Surface | Absent | Incorrect | Unverifiable`), never a
holistic code-quality judgment, and never a fix. It works from the change
and the specification, deliberately without the building agent's intent —
preventing a surface imitation of a requirement from passing as a genuine
implementation.

## What is here

Five self-contained plugins (issue #39's split), each a directory with its
own `.claude-plugin/plugin.json`, `hooks/`, and `tests/`:

    review/hooks/directive.sh                  SessionStart stub — sources core's
                                               role-directive.sh, supplies review's
                                               four role-unique values (YOU DECIDE,
                                               USE_WHEN, PRODUCES, HAND-OFF)
    review/hooks/state.sh                      resume-state hook

    review-traceability/hooks/traceability-gate.sh
                                               phase-1 requirement-list/sampling
                                               check; phase-2 per-verdict
                                               spec_ref:/evidence: field
                                               copresence (issues #30/#37/#38)
    review-traceability/skills/finding-record  the finding schema and template

    review-severity/hooks/severity-gate.sh     closed-vocabulary severity check
                                               (Chromium 5-band / Microsoft
                                               4-level bug-bar); denies
                                               DREAD-style averaged scores
    review-severity/skills/severity-classification
                                               deterministic band lookup

    review-record-norm/hooks/closed-checks-gate.sh
                                               a closed_checks cite must match
                                               the record's code_under_review:
                                               sha — never the working branch
                                               HEAD (contract §16)

    review-proposal-completeness/hooks/proposal-completeness-gate.sh
                                               freelunch-grade structural
                                               completeness bar on this role's
                                               own phase-1 proposals (issue
                                               #39 (b.5))

    tests/                                     repo-level checks (never installed):
                                               parse-check.sh, deny-only-check.sh,
                                               run-gate-tests.sh (aggregate runner)

All four `*-gate.sh` scripts source `core`'s gate-house standard
(`core/hooks/lib/gate-lib.sh` + `gate-lib.py`, issue #72) by reference —
never a vendored copy — for their fail-closed trap, kill-switch check, JSON
parse, path normalize, and Write/Edit/MultiEdit/Bash reconstruction, per
[`docs/handbooks/gate-house-standard.md`](https://github.com/tokenmaxxxer/tokenmaxxxer-core/blob/main/docs/handbooks/gate-house-standard.md)
(issue #42's remediation). `core/hooks/tests/compliance-check.sh` (also
referenced, never vendored) checks each plugin's `hooks/` directory for
drift from this standard.

Commit-trailer enforcement (`Subject: issue-<n>`), s20 record-fields
minimum-content checks, and s21 same-turn handbook sync are core canon
gates (`core/hooks/hooks.json`, issue-31 / core issues #63 & #66) — they
fire for every plugin install and are not vendored here.

## Record vocabulary

`loop_state`: `idle, scoped, auditing, draft-reported, reported`
(terminal: `reported`). Cross-role signals: per-requirement `verdict:`,
`evidence:`, `rationale:`, `spec_vs_built:` (Incorrect only), optional
`severity:`, `closed_checks:` keyed to `code_under_review:`, inline
`finding` blocks with `addressed_to:`/`severity: blocking|advisory`.

## Install

    claude plugin marketplace add tokenmaxxxer/conformance-review-rulebook
    claude plugin install review@tokenmaxxxer-review
    claude plugin install review-traceability@tokenmaxxxer-review
    claude plugin install review-severity@tokenmaxxxer-review
    claude plugin install review-record-norm@tokenmaxxxer-review
    claude plugin install review-proposal-completeness@tokenmaxxxer-review

or run `install.sh` in this repo, which does the same for user scope.

Kill switches (each independent; any value other than a recognized
on-spelling `1`/`true`/`yes`/`on` leaves the gate ACTIVE):
`REVIEW_TRACEABILITY_GATE_OFF`, `REVIEW_SEVERITY_GATE_OFF`,
`REVIEW_CYCLE_DISABLE` (alias `REVIEW_RECORD_NORM_GATE_OFF`),
`REVIEW_PROPOSAL_COMPLETENESS_GATE_OFF`.

## Run the checks

    bash tests/run-gate-tests.sh
    bash tests/parse-check.sh
    bash tests/deny-only-check.sh

Each plugin also carries its own gate test file, runnable standalone, e.g.
`bash review-traceability/tests/traceability-gate-test.sh`. `compliance-check.sh`
is core canon, run by reference against each plugin's `hooks/` directory, e.g.:

    "${CLAUDE_PLUGIN_ROOT_CORE:-../core}/hooks/tests/compliance-check.sh" review-traceability/hooks
