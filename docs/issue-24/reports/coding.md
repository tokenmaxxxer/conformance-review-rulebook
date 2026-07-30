---
role: coding
issue: 24
loop_state: phase2_complete
code_under_review: a8af69f430d5ca92a4233d44e89b74527048bb9b
closed_checks:
  - check: routing-vocabulary-sweep-post-edit
    code_sha: a8af69f430d5ca92a4233d44e89b74527048bb9b
    method: "grep -rn 'WAKES-ON|wake-routing|board-as-routing|downstream role' review/ — no matches (exit 1)"
resolved_findings: []
open_findings: []
---

# Coding record — issue 24 phase 2

## What was done
Executed the approved phase-1 proposal: reworded `review/hooks/directive.sh`'s "YOUR RECORD IS THE BOARD" section into "RECORD FORMAT". Dropped WAKES-ON, board-as-routing framing, and the `docs/specs/wake-routing.md` pointer entirely (per issue #24, unlike issue #22's step which kept a pointer). Restated the record obligation purely as record-format requirements: path, write-first-in-phase-2, loop_state-update-on-every-transition, required fields (code_under_review:, extracted requirement list/sampling derivation, per-requirement verdicts with evidence, closed_checks cites), commit-on-branch.

## Why
Issue #24: `review/hooks/directive.sh` still leaked routing-side vocabulary ("YOUR RECORD IS THE BOARD", "WAKES-ON reads...", "no downstream role can ever be woken") even after issue #22's partial pass, which kept a pointer to `docs/specs/wake-routing.md`. That pointer itself leaks that routing exists — a rulebook does not need to know routing exists. This proposal was approved via the "APPROVE issue-24/coding" comment on PR #25 by approvers.md account JiwonJung94 (single-account mode, role-handoff contract v3 s19), authorizing this phase-2 execution.

## Upstream basis
Approved phase-1 proposal (`docs/issue-24/proposals/coding.md`) and current-state survey (`docs/issue-24/reports/coding/survey.md`), committed under PR #25 (merged) before the human approver's APPROVE comment.

## Hunt (warrant-hunter cadence)
Not dispatched this phase: single-file, single-region prose reword with a mechanical grep as its own acceptance check (the phase-1 proposal's own "how you'll know it worked" criterion). No new surface introduced beyond the write set the phase-1 survey already scoped, so no new probe target exists.

## What did not work
(none — single edit, no false starts)

## Open findings
None.

## Next steps
None required for this scoped edit; phase 2 execution is complete.

## Open-finding resolution path
Not applicable — no open findings were raised in this phase.
