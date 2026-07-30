# Current-state survey — issue-27

## Scope of this repo

Only one role directive exists in this repo: `review/hooks/directive.sh`
(review-agent-rulebook). Its RECORD FORMAT section (lines 61-66) reads:

    RECORD FORMAT (do not skip this): review's record is
    docs/issue-<n>/reports/review.md — write it as your FIRST act of
    phase 2, and update its loop_state at every transition. It carries the
    required fields named above (code_under_review:, extracted requirement
    list or sampling derivation, per-requirement verdicts with evidence,
    closed_checks cites) and must be committed on the branch.

It states the record's required contents and location but carries no
enforcement clause and no measured-evidence citation.

## Reference wording (strong form, from this session's own coding-role
directive, which already carries it)

    Ending phase 2 without your record committed on the branch means the
    obligation is unmet. (Measured: a phase-1-only issue left no record
    committed.)

The issue names ux-design-rulebook's `ux-design/hooks/directive.sh` as the
canonical reference for this wording; that file is not part of this repo
and was not read — the wording pattern is already evidenced in-session
(see above) and confirmed by the issue text itself.

## Write set

- `review/hooks/directive.sh` — RECORD FORMAT section only, append the
  two sentences (enforcement + measured citation). All other lines
  (required fields, path, phase-2-first-act, loop_state) stay unchanged
  per the issue's explicit constraint.

## Scout skip record

Skipped — condition 2 applies (the spec leaves no design decision open:
the issue names the exact two clauses to add and gives the reference
wording verbatim).
