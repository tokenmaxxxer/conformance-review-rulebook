---
subject: issue-31
role: implementation
loop_state: scoped
---

# Current-state survey: this rulebook vs core canon (issue #31)

## Scope note (scout skip)

Scouting is skipped. This is a pinned follow-through on core's own already-
landed design (core issues #63/#66), not an open design question needing
external exemplars — the reference implementation is the landed core repo
itself, inspected directly below.

## What this repo actually has

This repo (`tokenmaxxxer/review-agent-rulebook`, plugin name `review`) ships
exactly one plugin: `review/`. Inventory against the issue's five items:

1. **warrant-hunter copy** — none exists. `find . -iname '*warrant*'` (repo
   root) returns nothing: no `agents/warrant-hunter.md`, no hunt-cadence
   directive text anywhere in `review/`. Item 1 is **not applicable** to
   this rulebook — there is nothing to remove or repoint.
2. **Three role-agnostic gate copies** — all three exist and are vendored
   byte-for-byte, each with a trap-at-top fail-closed preamble and its own
   `hooks.json` `PreToolUse` registration:
   - `review/hooks/trailer-gate.sh` — `PreToolUse(Bash)`, commit-trailer
     enforcement (contract §13).
   - `review/hooks/record-fields-gate.sh` — `PreToolUse(Write|Edit|
     MultiEdit)`, §20 minimum-content check on `review`'s own record.
   - `review/hooks/handbook-trigger-gate.sh` — `PreToolUse(Bash)`, §21
     same-turn handbook sync.
3. **`directive.sh`** — `review/hooks/directive.sh` is a full standalone
   file: trap/kill-switch/`CLAUDE_ROLE` guard preamble (identical shape to
   every other rulebook's copy) plus a large role-unique heredoc (the four
   facets: research/survey/proposal/execution-judgment prose, plus a
   closing RECORD line). Registered as the `SessionStart` hook in
   `review/hooks/hooks.json`.
4. **`RECORD_FIELDS_TERMINAL_STATES`-shaped divergence** — `review`'s own
   local `record-fields-gate.sh` hardcodes its terminal-state set as
   `{"reported"}` (grep: `TERMINAL_STATES = {"reported"}` — the loop_state
   vocabulary named in `review/hooks/directive.sh` and `README.md` is
   `idle, scoped, auditing, draft-reported, reported`, terminal `reported`).
   This **differs from core canon's default**, confirmed by reading the
   landed file directly (`tokenmaxxxer-core` @ `2fd1fcb`,
   `core/hooks/record-fields-gate.sh:86`):
   `RF_TERMINAL="${RECORD_FIELDS_TERMINAL_STATES:-landed}"` — core's
   built-in default terminal set is `{"landed"}`, not `{"reported"}`. This
   is a **genuine, real divergence**, not a hypothetical one — see the open
   question below.
5. **`core/hooks/tests/stub-check.sh`** — does not exist in this repo yet;
   confirmed present in the landed core repo
   (`tokenmaxxxer-core/core/hooks/tests/stub-check.sh`) and distributed
   "the same way `parse-check.sh` already is" per its own header. This repo
   has no `tests/parse-check.sh`-analogue copy of it yet either.

## What core canon actually landed (read directly, not inferred)

Inspected `tokenmaxxxer-core` at commit `2fd1fcb` (merged PRs #65 warrant/#63,
#68 gates/#66):

- `core/hooks/hooks.json` registers `trailer-gate.sh`, `record-fields-
  gate.sh`, and `handbook-trigger-gate.sh` **core-side**, under a single
  `PreToolUse` block with matcher `".*"` — i.e. the issue-66 proposal's
  "open question for the human approver" (core-side vs. rulebook-side hook
  registration) was **resolved as core-side**: these three gates now fire
  for every plugin install automatically, with no per-rulebook `hooks.json`
  entry needed or expected.
- `core/hooks/lib/role-directive.sh` exposes one function,
  `core_role_directive(you_decide, use_when, produces, hand_off)`. It reads
  `CLAUDE_ROLE`, derives a per-role kill switch
  (`<ROLE_UPPER>_CYCLE_OFF`), and prints the opening `[${role}] Role
  directive...` line, the four supplied values, and a fixed closing
  `RECORD: docs/issue-<n>/reports/${role}.md, phase-gated per contract v3
  s19` line. A rulebook's `directive.sh` shrinks to: source this file, set
  the four values, call `core_role_directive`.
- `core/hooks/tests/stub-check.sh` is a drift detector distributed to every
  rulebook: (a) fails if any of `trailer-gate.sh` / `record-fields-gate.sh`
  / `handbook-trigger-gate.sh` / `parse-check.sh` exists anywhere under the
  rulebook's own hooks tree (depth ≤3) — vendored copy is drift, full stop;
  (b) structurally checks any `directive.sh` found: must source
  `role-directive.sh`, must call `core_role_directive`, and every other
  non-blank/non-comment line must be a plain `VAR=value` assignment — a raw
  `case`, `echo`, or `cat` is treated as regrown boilerplate and fails.
- `closed-checks-gate.sh` is **not** in core's promoted set — core's
  `hooks.json` lists only the three gates above (plus `directive.sh`,
  `board-gate.sh`, `approval-gate.sh`, `gh-guard.sh`, all pre-existing core
  files unrelated to this issue). `review/hooks/closed-checks-gate.sh` is
  role-specific logic (closed_checks `code_sha` vs. `code_under_review:`
  matching) that has no core-canon counterpart and is out of this issue's
  scope — item 2 names exactly three gates, not four.
- No env-injection mechanism for `RECORD_FIELDS_TERMINAL_STATES` is visible
  anywhere in the landed core files, `hooks.json`, or its own test harness
  (`core/hooks/tests/run-role-gates-tests.sh` sets the env var directly in
  its own test invocation, which proves the gate script *reads* the var,
  but not how a rulebook is meant to *set* it once the gate is registered
  core-side with a fixed, non-rulebook-owned `hooks.json` entry). See the
  proposal's open question.

## Comparison with sibling rulebooks' phase-1 work on the same issue

Multiple sibling rulebook repos (`brand-design`, `accessibility`,
`api-design`, `incident-response`, `growth-analytics`, others) carry the
identical issue as their own issue #2 and have already produced phase-1
proposals for the same core-canon switch. `brand-design`'s proposal (no
divergent terminal-state, no role-specific gate content) is the closest
structural analogue to this repo's own item-1-N/A, item-2/3 shape, and its
proposal document's five-item write-set framing is reused directly below.
No sibling repo's proposal documents a *confirmed* (not hypothetical)
`RECORD_FIELDS_TERMINAL_STATES` divergence backed by a direct read of the
landed core file — this repo's `{"reported"}` vs. core's `{"landed"}`
default appears to be the first repo in this batch with a real, non-
speculative instance of item 4.
