# review-record-norm

Owns `code_under_review:` / `closed_checks:` sha-matched evidence discipline
for phase-2 review records (contract §16), relocated verbatim from its prior
home under `review/hooks/`. Behavior is unchanged.

## What it enforces

On a `Write`/`Edit`/`MultiEdit`/`NotebookEdit` to the review role's own
record, each `closed_checks:` entry's `code_sha` must match the code sha
currently under review (`code_under_review:`, else `upstream:` /
`upstream_code_sha:`, else `git rev-parse HEAD`). A check closed on a
different sha does not count as closed — the write is refused, not silently
patched. If `closed_checks` entries exist but no current sha can be
determined, the gate fails closed.

## Kill switches

- `REVIEW_CYCLE_DISABLE=1`
- `REVIEW_RECORD_NORM_GATE_OFF=1` (alias, same effect)

Either variable set to a truthy value (anything other than empty/`0`/`false`/
`no`/`off`) skips the gate entirely.

## Running the test

```
bash review-record-norm/tests/closed-checks-gate-test.sh
```
