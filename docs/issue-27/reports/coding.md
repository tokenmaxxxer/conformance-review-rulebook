---
role: coding
issue: 27
loop_state: phase2_complete
code_under_review: PLACEHOLDER_SHA
closed_checks:
  - check: record-format-strong-form-grep
    code_sha: PLACEHOLDER_SHA
    method: "grep -n 'means the record was never written\\|Measured: a phase-1-only issue left the record empty' review/hooks/directive.sh returns both lines (line 67-68); bash -n review/hooks/directive.sh passes; rest of RECORD FORMAT section byte-identical to pre-edit content"
resolved_findings: []
open_findings:
  - finding: "warrant-hunter (docs/reports/2026-07-30-hunt-raise-record-discipline-clause-to-strong-form.md) flagged that the phase-1 survey's cited source wording doesn't match the text actually committed"
    disposition: "not blocking — the committed wording is copied verbatim from issue #27's own body, which specified both sentences exactly; the survey's paraphrase mismatch is a phase-1 documentation drift, not a defect in the shipped directive text. No further action taken this phase."
---

# Coding record — issue 27 phase 2

## What was done
Executing the approved phase-1 proposal: appending two sentences to the
end of the RECORD FORMAT section in `review/hooks/directive.sh` — an
enforcement clause ("Ending phase 2 without your record committed on the
branch means the record was never written.") and a measured-evidence
citation ("(Measured: a phase-1-only issue left the record empty.)").
Wording only; no other change to required fields, record path, or other
sections. Single-file, single-region change.

## Why
Issue #27: review's RECORD FORMAT section lacked the strong-form clauses
already present in feasibility/verify/reflect/ux-design rulebooks.
Approved via merged PR #28's phase-1 content (proposal +survey committed
on this branch); phase-2 execution follows that approved scope.

## Upstream basis
`docs/issue-27/proposals/coding.md` (approved) and
`docs/issue-27/reports/coding/survey.md`, both already on main via PR
#28.

## Hunt (warrant-hunter cadence)
Dispatched at end of phase 2 (silent-failure/composition-regression
stance). Result: one finding, non-blocking — see open_findings above
and docs/reports/2026-07-30-hunt-raise-record-discipline-clause-to-strong-form.md.

## What did not work
(none)

## Open findings
See open_findings frontmatter above (non-blocking, disposition recorded).

## Next steps
None required for this scoped edit; phase 2 execution complete. Commit,
push, open PR.

## Open-finding resolution path
Not applicable — no open findings raised.
