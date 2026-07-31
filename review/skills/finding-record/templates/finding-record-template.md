<!--
Field skeleton for one requirement block written by the `finding-record`
skill into review-record.md, below the header block. One block per
requirement. See ../SKILL.md for the full field-by-field rationale.

verdict must be exactly one of: Present, Surface, Absent, Incorrect,
Unverifiable.

spec_ref is required for every verdict except Unverifiable; it is the
stable spec-side locator (clause/section/requirement-id, or heading +
paragraph for unnumbered prose) — distinct from the free-text
`requirement` field, since that field alone does not reliably serve as a
traceability key across re-review.

spec_vs_built is required only when verdict is Incorrect; omit it
otherwise.
-->
---
requirement: <the requirement text or id, verbatim from the spec>
spec_ref: <exact spec clause/section/requirement-id, or a stable heading+paragraph locator; required unless verdict: Unverifiable>
verdict: <Present | Surface | Absent | Incorrect | Unverifiable>
evidence: <file:line or hunk pointer into the diff; for Unverifiable, what access/evidence was missing instead>
rationale: <one line connecting the evidence to the verdict>
spec_vs_built: <required only when verdict: Incorrect — what the spec required vs. what was built; omit otherwise>
---
