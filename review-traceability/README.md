# review-traceability

Mechanizes the per-requirement conformance-traceability slice of the
`review` role's methodology (ISO 19011 / IIA evidence-based audit
practice: independent, per-requirement verdicts derived from the
artifact and spec, never from the builder's stated intent) — and the
`spec_ref:`/`evidence:` field discipline issues #30/#37/#38 added to
the record.

## What the gate checks

`hooks/traceability-gate.sh` is a `PreToolUse` gate on
`Write|Edit|MultiEdit` that inspects the proposed content of two
target surfaces:

- **Phase 1** — `docs/issue-<n>/proposals/review.md`: requires either
  a numbered/bulleted requirement enumeration or an explicit
  "sampling derivation" statement.
- **Phase 2** — `docs/issue-<n>/reports/(conformance-)?review.md`:
  every verdict token (`Present|Surface|Absent|Incorrect|Unverifiable`,
  case-insensitive) must sit in a block that also carries a
  `spec_ref:` field, and — unless the verdict is `Unverifiable` — an
  `evidence:` field.

Any other path is out of scope and allowed through untouched. The
gate never judges whether a verdict or evidence argument is actually
*correct*, or whether the reviewer was behaviorally independent — only
structural field-copresence.

## Kill switch

`export REVIEW_TRACEABILITY_GATE_OFF=1` disables the gate entirely
(allow-everything passthrough). The gate is fail-closed on any
internal error, missing `python3`, unreadable stdin, or unparseable
JSON payload — those deny rather than pass through uninspected.

## Tests

```
bash review-traceability/tests/traceability-gate-test.sh
```
