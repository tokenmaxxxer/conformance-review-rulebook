# review-severity

Deterministic severity table-lookup enforcement for the `review` role's
phase-2 records. This plugin owns exactly one methodology: severity must be
assigned by looking a finding up in a fixed table, not by averaging factors
into a score.

## Methodology

Severity is drawn from a closed vocabulary, matching either:

- **Chromium 5-band**: `Critical`, `High`, `Medium`, `Low`, `Unknown`
  (case-insensitive, optionally suffixed with `(S0)`–`(S4)`).
- **Microsoft 4-level bug-bar**: `Critical`, `Important`, `Moderate`, `Low`
  (case-insensitive).

DREAD-style averaged/numeric scores (e.g. `7.5`, `18/25`) are explicitly
rejected — issue #30 (c) names DREAD's abandonment as the specific reason
this role adopted table lookup instead. The vocabulary itself is fixed by
the `severity-classification` skill shipped alongside this gate.

## What the gate checks

`hooks/severity-gate.sh` runs on `PreToolUse` for `Write`/`Edit`/`MultiEdit`/
`NotebookEdit`. It fires only on writes to
`docs/issue-<n>/reports/(conformance-)?review.md`, and only when the
proposed content contains one or more `severity:` fields — severity is
optional/conditional, so a record with no `severity:` field at all is
outside this gate's business and is always allowed.

For each `severity:` value found:

- a recognized table token (either vocabulary above) is allowed;
- a numeric/averaged-looking value (`N`, `N.N`, or `N/N`) is denied, citing
  issue #30 (c);
- anything else (neither a table token nor numeric) is denied as not drawn
  from either closed vocabulary.

The gate is fail-closed: missing python3, unreadable stdin, malformed JSON,
or any internal error all deny rather than allow an uninspectable write.

## Kill switch

`REVIEW_SEVERITY_GATE_OFF=1` disables the gate entirely (allows everything).

## Running the tests

```
bash review-severity/tests/severity-gate-test.sh
```
