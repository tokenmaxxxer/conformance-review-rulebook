---
subject: issue-39
role: review
---

# Current-state survey (issue #39)

## What this role's plugin already carries (read directly, this session)

- `review/hooks/directive.sh` — a stub sourcing core canon's
  `core_role_directive` with four one-line facet values (`YOU_DECIDE`,
  `USE_WHEN`, `PRODUCES`, `HAND_OFF`). `PRODUCES` already names the
  required record fields in prose (`spec_ref` was added in issue #30
  phase 2), but it is prose read once at `SessionStart` — nothing
  mechanically checks a written record actually carries those fields.
- `review/hooks/closed-checks-gate.sh` (~150 lines) — the only
  role-specific `PreToolUse` gate. Narrow and mechanical: on a write to
  this role's own record, any `closed_checks:`/`code_sha:` entry must
  match the record's own `code_under_review:`/`upstream:` sha, or the
  write is denied. Fail-closed trap-at-top pattern (`__fc` EXIT trap
  forcing exit 2 on any non-{0,2} abort).
- `review/skills/finding-record/SKILL.md` +
  `templates/finding-record-template.md` — the human/agent-facing
  procedure and field skeleton (`requirement`, `spec_ref`, `verdict`,
  `evidence`, …) for writing one finding block. This is documentation
  guidance, not a hook — nothing enforces an agent actually followed it
  when writing `docs/issue-<n>/reports/review.md`.
- `review/skills/severity-classification/SKILL.md` — deterministic
  table-lookup severity guidance, optional-scope, same
  documentation-only status.
- Core canon (registered core-side, not vendored here per issue #31):
  `trailer-gate.sh`, `record-fields-gate.sh` (generic §20
  minimum-content, terminal-state-aware skip), `handbook-trigger-gate.sh`,
  `stub-check.sh`. `record-fields-gate.sh` checks section *presence*
  generically across all roles — it has no notion of `spec_ref`, the
  five-value verdict vocabulary, or any other review-specific field name
  (confirmed in issue #31's proposal, "Record/gate reflection": wiring a
  field-name check into it is out of this repo's write set).

## The gap this issue is against

Issue #30 phase 1 (`docs/issue-30/proposals/conformance-methodology.md`)
did the domain research and adopted, by name, three converged external
methodologies for this role's deliverable: conformance-assessment
requirement decomposition (ISO/IEC), evidence-based independent audit
practice (ISO 19011 / IIA), and deterministic severity table-lookup
(Chromium / Microsoft bug-bar, DREAD abandoned). Phase 2 only reflected
this into **one prose word** (`spec_ref` added to `PRODUCES`, `SKILL.md`,
the template). Nothing after that point *checks* that a written record
actually:

- decomposes the spec into discrete requirements (vs. one holistic
  verdict),
- uses only the five-value vocabulary (`Present|Surface|Absent|Incorrect|
  Unverifiable`),
- carries `spec_ref` + an evidence pointer on every non-`Unverifiable`
  verdict,
- keeps the reviewer's independence stance (no field for this is even
  checkable mechanically, noted below as a limit),
- follows the required *order* — this role's own methodology has an
  implicit sequence (extract/derive requirements → gather evidence per
  requirement → render verdict), which nothing currently tracks.

This is exactly the shape issue #39 names: `implementation-rulebook`
enforces its own adopted methodology (mock-ban, footgun-ban, coding
progress staging, hunt-cadence state) with dedicated `PreToolUse` gates
and, where order matters, a state file — not just a `PRODUCES` line. This
role has the research and the one-line reflection; it has no gate and no
state tracking.

## Comparable machines read this session (reference only, never copied)

- `pricing-rulebook`'s `pricing/hooks/methodology-gate.sh` (local
  checkout, 230 lines): a `PreToolUse` gate targeting exactly this role's
  own proposal/record write surfaces (`docs/issue-<n>/proposals/*pricing*
  .md`, `docs/issue-<n>/reports/pricing.md`), extracting the new/resulting
  text from `Write`/`Edit`/`MultiEdit` tool input, and denying when any of
  six named methodology elements is absent from that text — same
  fail-closed trap-at-top shape as this role's own
  `closed-checks-gate.sh`. Confirms the shape this issue asks for is a
  live, working pattern in this codebase family, not a novel design.
- `performance-engineering-rulebook`'s own `methodology-gate.sh` exists
  alongside it (not read in full this session — same family, not needed
  beyond confirming the pattern recurs across rulebooks).
- `implementation-rulebook`'s `coding/` plugin (local checkout): five
  hook files together ≈442 lines (`directive.sh` 16, `state.sh` 29,
  `hunt-state.sh` 47, `hunt-guard.sh` 172, `coding-progress-gate.sh` 178)
  — the "hook-machine level" issue #39 cites as the bar. `state.sh` +
  `hunt-guard.sh` together are the order-enforcement pattern (a state
  file gates which write surfaces are even reachable next) this role
  needs for its requirements→evidence→verdict sequence.

## Scope note (scout skip record)

Field-scouting (the `scout-directive`'s external sweep) is **skipped**
for this issue. Reason: the spec leaves no open external-practice
question — issue #30 already did that research and adopted named
methodologies (ISO/IEC conformance assessment, ISO 19011/IIA,
deterministic severity table-lookup); issue #39 asks only to *mechanize*
what was already adopted, using this repo's own already-landed sibling
implementations (`pricing`/`performance-engineering`
`methodology-gate.sh`, `implementation-rulebook`'s hook machine) as the
engineering reference. This is the skip condition "the spec literally
leaves no design decision open" applied to the *field* axis specifically
— the remaining design decisions (gate shape, state-file shape) are
internal engineering choices grounded in in-repo precedent, not a
market/practice question requiring a web sweep. See
`scout-brief.md` for the formal skip record.
