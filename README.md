# tokenmaxxxer / review-agent-rulebook

The `review` role on contract v3. A review session is spawned with two
plugin sets installed: this marketplace's `review` plugin, and the
[tokenmaxxxer-core](https://github.com/tokenmaxxxer/tokenmaxxxer-core)
plugins (`core`, `terse`, `freelunch`, `scout`). Core owns the interaction
protocol — issue in, two-phase PR out (research/survey/proposal → human
review Approve → execution), branch `issue-<n>/review`, record at
`docs/issue-<n>/reports/review.md`. This rulebook owns only what is
review-specific.

## What `review` decides

Whether what was built matches what was specified — a per-requirement
verdict (`Present | Surface | Absent | Incorrect | Unverifiable`), never a
holistic code-quality judgment, and never a fix. It works from the change
and the specification, deliberately without the building agent's intent —
preventing a surface imitation of a requirement from passing as a genuine
implementation.

## What is here

    review/hooks/directive.sh           SessionStart — the four facets:
                                        research (audit exemplars, sampling
                                        derivation), survey (artifact-only,
                                        extract every requirement first),
                                        proposal (spec + requirement list +
                                        code_under_review), judgment (verdict
                                        vocabulary, evidence-as-diff-pointer,
                                        never-fix, solo vs human calls)
    review/hooks/record-fields-gate.sh  s20 minimum content + verdict
                                        vocabulary + spec_vs_built on Incorrect
    review/hooks/closed-checks-gate.sh  a closed_checks cite must match the
                                        record's code_under_review: sha —
                                        never the working branch HEAD
    review/hooks/trailer-gate.sh        commits staging docs/issue-<n>/** carry
                                        `Subject: issue-<n>`
    review/hooks/handbook-trigger-gate.sh  s21 same-turn handbook sync
    review/skills/finding-record        the finding schema and template
    review/skills/severity-classification  deterministic band lookup
    tests/                              repo-level checks (never installed)

## Record vocabulary

`loop_state`: `idle, scoped, auditing, draft-reported, reported`
(terminal: `reported`). Cross-role signals: per-requirement `verdict:`,
`evidence:`, `rationale:`, `spec_vs_built:` (Incorrect only), optional
`severity:`, `closed_checks:` keyed to `code_under_review:`, inline
`finding` blocks with `addressed_to:`/`severity: blocking|advisory`.

## Install

    claude plugin marketplace add tokenmaxxxer/review-agent-rulebook
    claude plugin install review@tokenmaxxxer-review

on-the-record installs it per role alongside the core marketplace. Kill switch:
`REVIEW_CYCLE_DISABLE=1`.

## Run the checks

    /bin/bash tests/parse-check.sh
    /bin/bash tests/run-gate-tests.sh
    /bin/bash tests/deny-only-check.sh
