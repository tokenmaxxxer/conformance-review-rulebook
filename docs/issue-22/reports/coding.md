---
role: coding
issue: 22
loop_state: phase2_complete
code_under_review: 42a3428d40e83ac1ac52d1c4330fbaadfff9ab43
closed_checks:
  - check: wake-mention-sweep-post-edit
    code_sha: 42a3428d40e83ac1ac52d1c4330fbaadfff9ab43
    method: "grep -rni 'wake' --include='*.md' --include='*.sh' . (excl. docs/issue-22/) shows only the new pointer text in review/hooks/directive.sh (file name + 'canon at ... wake-routing.md, not restated here', no routing mechanics restated) and the untouched historical doc docs/proposals/2026-07-26-contract-v2-conformance.md, explicitly out of scope"
resolved_findings: []
open_findings: []
---

# Coding record — issue 22 phase 2

## What was done
Executed the approved phase-1 proposal: rewrote `review/hooks/directive.sh` lines 61-68 (the "YOUR RECORD IS THE BOARD" closing section). Kept review's own record state/format (which file is the record, when to write it — first act of phase 2, when to update loop_state). Dropped the general WAKES-ON consumption/consequence prose ("research files, surveys, and proposals wake no one", "no downstream role... woken", "machine wake-up dead"). Repointed to on-the-record `docs/specs/wake-routing.md` for how WAKES-ON consumption works, instead of restating it. Single-file, single-region change; no other file in scope.

## Why
Wake-routing ownership migration step 3 (issue #22): this rulebook must contain nothing about which role wakes next; routing canon now lives at on-the-record `docs/specs/wake-routing.md`. Phase-1 survey found `review/hooks/directive.sh:61-68` as the only rulebook file restating WAKES-ON mechanics. This proposal was approved via the "APPROVE issue-22/coding" comment on issue #22 (per role-handoff contract v3 s19), authorizing this phase-2 execution.

## Upstream basis
Approved phase-1 proposal (`docs/issue-22/proposals/coding.md`) and current-state survey (`docs/issue-22/reports/coding/survey.md`), plus the phase-1 hunt record (`docs/reports/2026-07-30-hunt-wake-routing-scope.md`), all committed under this PR (#23) before the human approver's APPROVE.

## Hunt (warrant-hunter cadence)
Not re-dispatched this phase. The proposal's own phase-1 hunt (`docs/reports/2026-07-30-hunt-wake-routing-scope.md`) already probed file-scope completeness for WAKES-ON/wake-routing mentions across the whole tree and found no missed file. Phase-2 execution matched that scoped write set exactly, introducing no new surface, so no new hunt target exists. Post-edit verification was closed via `closed_checks` above (a completeness sweep, equivalent probe scope to the phase-1 hunt).

## What did not work
(none)

## Open findings
None.

## Next steps
None required for this scoped edit; phase 2 execution is complete. Loop remains open at 'phase2_complete' pending downstream review/merge of PR #23 by other roles.

## Open-finding resolution path
Not applicable — no open findings were raised in this phase.
