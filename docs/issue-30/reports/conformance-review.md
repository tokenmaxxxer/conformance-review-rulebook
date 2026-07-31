---
subject: issue-30
role: review
loop_state: phase2_complete
---

# Record: conformance-review methodology and deliverable norms (issue #30, phase 2)

## What was done

Executed the approved proposal's frozen reflection plan
(`docs/issue-30/proposals/conformance-methodology.md`, part (d)) after the
human approver's approval via the role-handoff protocol:

1. **`review/hooks/directive.sh`** — extended the existing `PRODUCES`
   value to name the new required field explicitly. Changed only the
   `PRODUCES` line; `YOU_DECIDE`, `USE_WHEN`, and `HAND_OFF` are untouched,
   as the proposal specified (they already state the verdict vocabulary
   and independence constraint correctly):

   ```
   PRODUCES="PRODUCES (required record fields): extracted requirement list
   (or sampling derivation), per-requirement verdicts with spec_ref +
   diff-pointer evidence, code_under_review:, closed_checks cites keyed to
   that sha"
   ```

2. **`review/skills/finding-record/SKILL.md`** — added `spec_ref` to the
   field list, positioned between `requirement` and `verdict` (per the
   proposal: it is the traceability key the free-text `requirement` field
   does not reliably serve as). Extended the refusal section: the skill
   now refuses to write a verdict of `Present`, `Surface`, `Absent`, or
   `Incorrect` with no `spec_ref`, mirroring the existing `evidence`
   refusal exactly. `Unverifiable` remains the one verdict that may omit
   both `evidence` (a diff pointer) and `spec_ref` (a spec locator), for
   the same underlying reason: nothing was checked, so neither side of
   the traceability pair is available.
3. **`review/skills/finding-record/templates/finding-record-template.md`**
   — added `spec_ref` to the field skeleton (same position as in
   `SKILL.md`) and to the template's header comment, so the template and
   `SKILL.md` state the same required field together, not just one — the
   proposal's own required gate condition (part (d), "PR/gate condition to
   add").

No other file under `review/` was touched. `review/hooks/closed-checks-gate.sh`
is unchanged, as the proposal explicitly scoped it out. No canon script was
vendored or copied into this repo; `spec_ref` enforcement is stated in this
role's own skill/template/directive only, not wired into any core-side gate
— per the proposal's own note that field-level enforcement in
`record-fields-gate.sh` is core's write set, not this repo's, and is left as
a follow-up for the user to file against core if wanted.

## Why

Issue #30 asks this rulebook to encode, in its plugin, the methodology and
required-component norms this role's own phase-1 proposal (issue #30
itself) established after domain research (ISO/IEC conformance-assessment
practice, ISO 19011 / IIA audit standards, and the DREAD-vs-bug-bar
severity convergence — see the proposal's part (c)). `spec_ref` closes the
one concrete gap the proposal identified: a traceability matrix needs a
stable key on the spec side of each finding, not just the diff-evidence
side, and the free-text `requirement` field does not serve that purpose
reliably across re-review.

## Upstream basis

- `docs/issue-30/proposals/conformance-methodology.md` (this repo,
  approved) — part (d), the reflection plan executed verbatim here.
- `docs/issue-30/reports/conformance-review/scout-brief.md` and
  `current-state-survey.md` (this repo, phase 1) — background survey and
  current-state audit the proposal is built on.
- Issue #30 approval: role-handoff protocol, human approver, prior to this
  phase-2 execution (per the task instructions this record is written
  under).

## Open findings

None new. The proposal's own part (d) already notes that wiring a
`spec_ref` field-name check into core's `record-fields-gate.sh` is out of
this repo's write set; that remains an open follow-up for the user to file
against `tokenmaxxxer-core` if field-level (not just section-presence)
enforcement is wanted. Not blocking — this issue's own write set
(`directive.sh`, `SKILL.md`, template) is fully executed.

### Next steps

- If field-level enforcement of `spec_ref` is wanted, file a follow-up
  issue against `tokenmaxxxer/tokenmaxxxer-core` requesting
  `record-fields-gate.sh` check for the new field name — this role's
  `gh-guard.sh` restricts issue filing to the user (contract v3 s9), so
  this is recorded here rather than filed directly.
- Watch the proposal's own stated failure signal (part (d)/"Failure
  signal"): if `spec_ref` starts being filled with copy-pasted noise
  because a spec has no stable locators, revert the field rather than
  keep it for its own sake.

### Open-finding resolution path

Tracked as the open finding above; resolution (a core-side gate change) is
external to this repo and not blocking. No further phase is open for
issue #30 in this repo.

## loop_state

`phase2_complete` — this role's own terminal state (see
`docs/issue-31/reports/implementation.md` for precedent on why
next-steps/resolution-path sections are included even at a terminal state,
pending a core-side terminal-state recognition gap).
