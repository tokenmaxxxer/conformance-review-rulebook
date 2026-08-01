---
subject: issue-45
role: review
loop_state: scope-proposed
---

# Proposal — gate A+ final closeout: remaining re-audit defects (issue #45)

## Request (paraphrased intent)

The 2026-08-01 re-audit (grade A-) found three remaining defects outside
the already-landed common prerequisites (core issue #75's gate-lib
source guard / compliance-check detection / missing-core mandatory test
/ `gate_bash_write_targets` Python port, and on-the-record issue #182's
`CLAUDE_PLUGIN_ROOT_CORE` injection in `spawn.py`):

1. Bash-deny logic is implemented and tested in four gate scripts but
   not registered in any `hooks.json` matcher — a dead branch, never
   reachable in production.
2. `NotebookEdit` has a `hooks.json` matcher entry in the same four
   plugins, but the code path for it is a silent no-op — advertised but
   not implemented.
3. `install.sh` references an old/renamed repo name and omits
   `review-agent-env` from its install list.

Issue #45 requires all three fixed, full hooks.json/code parity across
every affected plugin, the full test suite green (including the
missing-core case) plus a recorded compliance-check pass, and zero
old-role-name/ghost-file references in README/manifest. Full detail and
file:line citations are in
`docs/issue-45/reports/conformance-review/current-state-survey.md`;
`docs/issue-45/reports/conformance-review/scout-brief.md` records why
field-scouting is skipped (pure bugfix, no open design decision). This
is a **phase-1 proposal only** — no execution work is included; per
contract v3 s19, phase 2 opens only after a human Approve.

## Constraints

- **Phase-1 only.** This PR touches only `docs/issue-45/**`. No file
  under `review/`, `review-*/`, `tests/`, `.claude-plugin/`, or
  `install.sh` is created, deleted, or edited in this PR. Everything in
  sections (a)-(f) below is a frozen plan for phase 2, executed only
  after a human approver's Approve.
- **No APPROVE in this PR.** This proposal does not, and cannot, approve
  itself.
- **Apply core #75 by reference, never reimplement.** Everywhere this
  proposal touches ground shared with core issue #75's finalized
  guard/rule shape (`gate_bash_write_targets`'s Python port, the
  mandatory source guard, the missing-core test case), phase 2 must pull
  core's current landed shape and diff/adopt it — not hand-roll an
  equivalent, per `docs/handbooks/canon-scripts.md`'s reference-not-copy
  rule (reaffirmed by issues #31/#34/#42 in this repo).
- **Net-additive parity fix, never a behavior relaxation.** Registering
  `Bash` in a matcher must not weaken any existing Write/Edit/MultiEdit
  check; implementing `NotebookEdit` must not create a bypass where none
  existed (a no-op today is stricter-by-accident than a wrong
  implementation would be — the fix must not regress that).
- **Role boundary / write_scope unchanged.** No change proposed here
  alters which artifact surfaces (`docs/issue-<n>/proposals/**`,
  `docs/issue-<n>/reports/(conformance-)?review.md`) these gates
  inspect — only which tool calls against those surfaces are dispatched
  to them, and what the dispatched code does.

## (a) Bash-deny dead branch — 4 plugins

**Defect:** `review-proposal-completeness/hooks/hooks.json:5`,
`review-record-norm/hooks/hooks.json:5`,
`review-severity/hooks/hooks.json:5`, and
`review-traceability/hooks/hooks.json:5` all set matcher
`"Write|Edit|MultiEdit|NotebookEdit"` — no `Bash`. Each plugin's gate
script already has a real, tested `Bash` branch (verified this session:
`review-proposal-completeness/hooks/proposal-completeness-gate.sh:79-91`
and the equivalent lines in the other three, per the survey), but
Claude Code's hook dispatcher never invokes these scripts for a `Bash`
tool call, so the branch is unreachable in production despite passing
its own test file (which invokes the script directly, bypassing
dispatch).

**Proposed fix:** add `Bash` to each of the four `hooks.json` matchers,
changing the matcher string to
`"Write|Edit|MultiEdit|NotebookEdit|Bash"` (or equivalent) in all four
files. Before landing, phase 2 must diff each plugin's existing `Bash`
branch against core #75's finalized `gate_bash_write_targets.py` shape
(pulled fresh from `tokenmaxxxer-core`, not from this proposal's
description of it, since this proposal is written without re-pulling
core) — if core #75 changed the reconstruction/detection contract this
branch relies on, the branch must be updated to match core's current
shape by reference (e.g. importing/calling core's helper) rather than
this repo re-deriving its own Bash-token-scan logic independently.

## (b) NotebookEdit no-op — 4 plugins

**Defect:** the same four gate scripts fall through
`if tool not in ("Write", "Edit", "MultiEdit"): sys.exit(0)`
(`review-proposal-completeness/hooks/proposal-completeness-gate.sh:93`,
and the equivalent line in the other three) — so a `NotebookEdit` call,
despite being named in the matcher, is silently allowed through
uninspected.

**Options:**
- (a) Implement a real `NotebookEdit` branch in each of the four gate
  scripts, mirroring the existing Write/Edit/MultiEdit content-check
  logic (extract the resulting file content from `tool_input`'s
  notebook-edit shape — new cell source or edited cell source — and run
  the same structural/field checks already applied to Write/Edit
  content).
- (b) If `NotebookEdit` truly has no meaningful content-check
  equivalent for this role's artifact surfaces (`docs/issue-<n>/**` are
  markdown, never `.ipynb` — a `NotebookEdit` call against them would be
  unusual but not impossible via a tool-call type mismatch), remove
  `NotebookEdit` from the matcher entirely and document why in each
  plugin's own comment/README entry.

**Recommendation: (a), implement real coverage.** One-line rationale:
the matcher already advertises `NotebookEdit` and the surrounding test
suites are built around exercising every advertised branch (per the
Bash case in (a) above, sibling code) — silently dropping advertised
surface reduces the audited coverage claim rather than fixing the
defect, and the artifact surfaces this role governs are markdown files
that could in principle be reached via a `NotebookEdit` call if a
building agent mis-selects the tool; a fail-closed content check is
consistent with every other branch in these gates rather than a
special-cased allow-through.

## (c) install.sh stale repo name / missing plugin

**Defect:** `install.sh:15` sets
`GITHUB_REPO="tokenmaxxxer/review-agent-rulebook"`; `git remote -v`
confirms the actual repo is `tokenmaxxxer/conformance-review-rulebook`.
`install.sh:16`'s `PLUGINS` array and the header comment
(`install.sh:2-6`) both omit `review-agent-env`.

**Proposed fix:**
- `install.sh:15`: `GITHUB_REPO="tokenmaxxxer/conformance-review-rulebook"`.
- `install.sh:16`: add `review-agent-env` to the `PLUGINS` array — but
  only once `review-agent-env` is actually registered in
  `.claude-plugin/marketplace.json` (it is not, today — see (f)) and has
  a resolved `dependencies` field (today it names a nonexistent
  `review-cycle` plugin — see (f)). Phase 2 must resolve (f) before this
  line can be added without installing a broken dependency.
- `install.sh:2-6`'s header comment must be updated in the same change
  to name all six plugins once `review-agent-env` is added, so the
  comment and the array stay in sync (today they already agree with
  each other, both excluding it — the fix must keep them agreeing after
  the addition).

## (d) hooks.json/code full parity — audit method for phase 2

**Acceptance check for phase 2:** for every plugin with a `hooks.json`,
enumerate every matcher entry and confirm a code branch exists in the
gate script that is exercised by that plugin's own test file; separately
enumerate every code branch keyed on `tool_name` (or equivalent) in the
gate script and confirm a matcher entry actually dispatches to it. Both
directions must close with zero gaps:
- matcher → code: `Write`, `Edit`, `MultiEdit`, `NotebookEdit`, `Bash`
  (post-fix) each map to a real, tested branch in
  `review-proposal-completeness`, `review-record-norm`,
  `review-severity`, `review-traceability`.
- code → matcher: no branch keyed on a `tool_name` value should exist in
  any gate script without a corresponding matcher entry (this direction
  is expected to already hold post-(a)/(b) fixes, but must be explicitly
  re-checked, not assumed).
- `review`'s `hooks.json` (SessionStart only, no PreToolUse) and
  `review-agent-env` (no `hooks.json` at all) are out of scope for this
  parity check by construction — neither has a PreToolUse code branch to
  reconcile — but `review-agent-env`'s absence of any `hooks.json` is a
  separate open question phase 2 must resolve explicitly (does it need
  one, given it "contains no code of its own" per its own
  `plugin.json:4` description) rather than silently leaving unaddressed.

## (e) missing-core test case + compliance-check record

Phase 2 must pull core's finalized issue #75 guard/test shape from
`tokenmaxxxer-core` and apply it **by reference** (source/import, not
reimplement) to add the missing-core mandatory test case to each of the
five plugins with a `hooks.json`, then run the full local suite
(`tests/run-gate-tests.sh`, `tests/parse-check.sh`,
`tests/deny-only-check.sh`, plus each plugin's own gate test file) green,
and record a `compliance-check.sh` pass (run by reference against core,
per `README.md:108-112`'s existing documented invocation pattern) in the
phase-2 deliverable record. This is phase-2 record content
(`docs/issue-45/reports/conformance-review.md`), not phase-1 content —
noted here only as the stated acceptance bar this proposal commits
phase 2 to meeting.

## (f) README / manifest cleanup

Concrete list for phase 2 (from the survey's completed grep/read pass —
recorded here so phase 2 does not have to re-derive it):

1. **No old-role-name string hits found anywhere** in `README.md`,
   `.claude-plugin/marketplace.json`, or any plugin's own
   `.claude-plugin/plugin.json` — confirmed by reading all of them this
   session plus `docs/issue-30`, `docs/issue-39`, `docs/issue-42`'s
   proposals for prior naming history. Explicitly recorded as "none
   found" so phase 2 does not re-run this check from scratch; it should
   still re-verify once phase 2's other edits land, since edits to
   `install.sh`/`README.md` in this same phase 2 could in principle
   introduce a typo'd name.
2. **Ghost dependency reference (new finding, not in the issue's
   original three items but falls under requirement 4's zero-ghost-
   reference bar):** `review-agent-env/.claude-plugin/plugin.json:8-10`
   declares `"dependencies": ["review-cycle"]`, and no plugin named
   `review-cycle` exists in this repo's `.claude-plugin/
   marketplace.json` or anywhere on disk. Phase 2 must either (i)
   correct this to name a real plugin this repo actually ships (most
   likely one or more of the five split plugins from issue #39, if that
   is what `review-agent-env` was meant to bundle), or (ii) if
   `review-agent-env`'s intended role can no longer be determined,
   flag it for the human approver to decide removal-vs-repair rather
   than guessing silently.
3. **`review-agent-env` itself is unregistered**: no entry in
   `.claude-plugin/marketplace.json`'s `plugins` array, no mention in
   `README.md`'s plugin listing or install instructions, excluded by
   name from `install.sh`'s header comment and `PLUGINS` array. Phase 2
   must either document + register + install it consistently (once (2)
   above is resolved) or, if it is genuinely not meant to ship yet,
   record that decision explicitly rather than leaving it as silent
   drift — this ambiguity should be raised to the human approver at
   Approve time if phase 2 cannot resolve it unilaterally from existing
   written intent.
4. **No ghost file-path references found** in `README.md`'s file
   listing — every path named corresponds to a real file in this
   checkout (verified by directory listing this session).

## What is deliberately out of scope

- Re-litigating the plugin-split architecture from issue #39 — this
  proposal only reconciles matcher/code parity and stale references
  within the existing five-plugin-plus-review-agent-env shape.
- Any change to `review-severity`'s or `review-record-norm`'s existing
  Write/Edit/MultiEdit check logic — untouched by (a)/(b).
- Re-deriving core #75's or on-the-record #182's guard/injection shapes
  — both are landed common prerequisites, applied by reference only.
- Deciding `review-agent-env`'s ultimate fate beyond flagging it — if
  its intended dependency truly cannot be reconstructed from written
  history, that is a call for the human approver, not this proposal.

## How this will be judged

- `docs/issue-45/reports/conformance-review/current-state-survey.md`
  and `scout-brief.md` exist, with the survey citing file:line for every
  claim and completing the README/manifest ghost-reference grep the
  issue's own prior pass left incomplete.
- This proposal names a concrete fix for all three original defects (a,
  b, c) plus the audit method for full parity (d), the phase-2
  acceptance bar for the missing-core case + compliance-check record
  (e), and a concrete, non-hand-wavy README/manifest cleanup list (f),
  including the newly-found ghost dependency in `review-agent-env`.
- No file outside `docs/issue-45/**` is modified by this PR.
- Every fix proposed above that overlaps core #75's guard shape is
  stated as "apply by reference to core's current landed shape," never
  as a hand-rolled reimplementation.

**PHASE 1 ONLY — do not APPROVE, do not execute phase 2 fixes in this
PR.**
