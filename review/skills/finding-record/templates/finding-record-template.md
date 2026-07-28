<!--
Field skeleton for one requirement block written by the `finding-record`
skill into review-record.md, below the header block. One block per
requirement. See ../SKILL.md for the full field-by-field rationale.

verdict must be exactly one of: Present, Surface, Absent, Incorrect,
Unverifiable.

spec_vs_built is required only when verdict is Incorrect; omit it
otherwise.
-->
---
requirement: <the requirement text or id, verbatim from the spec>
verdict: <Present | Surface | Absent | Incorrect | Unverifiable>
evidence: <file:line or hunk pointer into the diff; for Unverifiable, what access/evidence was missing instead>
rationale: <one line connecting the evidence to the verdict>
spec_vs_built: <required only when verdict: Incorrect — what the spec required vs. what was built; omit otherwise>
---
