---
subject: issue-31
role: implementation
loop_state: scope-proposed
---

# Proposal: switch this rulebook to core canon references (issue #31)

## Request (paraphrased intent)

Core landed a single canon for the warrant-hunt agent (core issue #63) and
the three role-agnostic gates + directive boilerplate (core issue #66).
This rulebook (`review`) still vendors byte copies of the three gates and a
full standalone `directive.sh`. Replace the vendored copies with references
to core canon in one batch, preserving this role's own genuinely unique
content. See `docs/issue-31/reports/implementation/survey.md` for the full
current-state audit this proposal is built on.

## Constraints

- Phase-1 only — no file is deleted or edited outside `docs/issue-31/**` in
  this PR. Phase 2 executes only after Approve.
- Scouting skipped — recorded in survey.md's Scope note: pinned follow-
  through on core's own already-landed design, not an open design question.
- Order constraint from the issue: this must land before this rulebook's
  own "rulebook maturation" phase 2 starts.
- Write set for phase 2 (frozen, listed so it can be reviewed before
  approval):
  - delete `review/hooks/trailer-gate.sh`
  - delete `review/hooks/record-fields-gate.sh`
  - delete `review/hooks/handbook-trigger-gate.sh`
  - rewrite `review/hooks/directive.sh` (stub form, sourcing core's
    `role-directive.sh`)
  - rewrite `review/hooks/hooks.json` (drop the 3 gate `PreToolUse`
    entries; keep `SessionStart` → `directive.sh` and the
    `closed-checks-gate.sh` entry, which is not part of this promotion)
  - add `review/hooks/tests/stub-check.sh` (copied verbatim from core)
  - resolve the `RECORD_FIELDS_TERMINAL_STATES` open question below before
    the stub can be considered done — this role's terminal state genuinely
    differs from core's default
  - `docs/issue-31/reports/implementation.md` (phase-2 record, written
    after Approve, per contract v3 s19), stating the `stub-check.sh` pass
    result verbatim (item 5)

## What will be done (phase 2 only — not applied yet)

### 1. warrant-hunter — not applicable, no action

Survey confirms no `agents/warrant-hunter.md` or hunt-cadence copy exists
anywhere in this repo. Nothing to delete, nothing to repoint. Recorded here
so the record shows this item was checked, not silently skipped.

### 2. Remove the 3 gate copies + their `hooks.json` registrations

Delete `trailer-gate.sh`, `record-fields-gate.sh`, `handbook-trigger-
gate.sh`. Core registers all three core-side (`core/hooks/hooks.json`'s
single `PreToolUse` block, matcher `".*"`) per the issue-66 approver
decision, confirmed by reading the landed file directly — they fire for
every plugin install automatically once `core` is installed alongside
`review`. Remove the matching three `PreToolUse` entries from `review/
hooks/hooks.json`; keep the `SessionStart` entry and the existing
`closed-checks-gate.sh` `PreToolUse` entry, which core's promotion does
not cover (role-specific `code_sha` matching logic — not one of the three
gates the issue names).

Behavior-preservation note: core's `trailer-gate.sh` and `handbook-
trigger-gate.sh` are pure `CLAUDE_ROLE`-parameterized copies of this repo's
own logic (per core's own issue-66 report: "every existing inter-copy diff
is role-name substitution only... no role has gate logic that actually
differs") — deleting these two is a pure mechanical no-op in behavior.
`record-fields-gate.sh` is **not** a pure no-op for this role — see item 4.

### 3. `directive.sh` → stub sourcing `core_role_directive`

Replace with:

```bash
#!/usr/bin/env bash
trap 'rc=$?; if [ "$rc" != 0 ] && [ "$rc" != 2 ]; then exit 2; fi' EXIT
set -uo pipefail
. "${CLAUDE_PLUGIN_ROOT_CORE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../core" && pwd -P)}/hooks/lib/role-directive.sh"
core_role_directive \
  "YOU DECIDE: whether what was built matches what was specified — a per-requirement verdict (Present|Surface|Absent|Incorrect|Unverifiable), never a holistic code-quality judgment, never a fix" \
  "USE_WHEN: after a build reaches a reviewable state, working from the artifact and the spec, deliberately without the building agent's intent" \
  "PRODUCES (required record fields): extracted requirement list (or sampling derivation), per-requirement verdicts with diff-pointer evidence, code_under_review:, closed_checks cites keyed to that sha" \
  "HAND-OFF: findings addressed_to the owning role; never fixed here"
```

Survey found `review/hooks/directive.sh`'s current heredoc maps cleanly
onto the four-argument template with no leftover unmapped section (unlike
`brand-design`'s `WRITE_SCOPE`/`BOUNDARY CASE` overflow) — the existing
RESEARCH / CURRENT-STATE SURVEY / PROPOSAL / EXECUTION JUDGMENT sections
compress into `USE_WHEN`/`PRODUCES`/`HAND-OFF` without losing a distinct
clause. The severity-table and closed-checks-sha-discipline detail
currently spelled out in the directive's prose is judged safe to drop from
the SessionStart briefing specifically because it already lives in
`review/skills/severity-classification/SKILL.md` and in `closed-checks-
gate.sh`'s own header comment — the directive was restating, not the only
place the rule lives.

### 4. `RECORD_FIELDS_TERMINAL_STATES` — open question for the human approver

This is a **real divergence**, confirmed by reading both files directly:
this repo's `record-fields-gate.sh` hardcodes `terminal = {"reported"}`;
core's canon `record-fields-gate.sh` defaults to
`RF_TERMINAL="${RECORD_FIELDS_TERMINAL_STATES:-landed}"`. Deleting the
local copy without preserving this changes gate behavior: `reported` would
stop being recognized as terminal, and a completed `review` record would be
wrongly required to carry a next-steps/open-finding-resolution section it
should not need.

The blocker: core's three gates are registered **core-side**
(`core/hooks/hooks.json`, a file this repo does not own), not through this
repo's own `hooks.json` — so there is no obvious place left in this repo
to set `RECORD_FIELDS_TERMINAL_STATES=reported` before the gate runs. No
env-injection mechanism for a core-side-registered hook is visible
anywhere in the landed core repo (its own `run-role-gates-tests.sh` sets
the var directly in its own test process, which is not a pattern available
to a plugin install). Two options, deferred to the approver:

- **(a)** Core issue #66 in fact left this as an open gap (its own
  proposal's "open question" resolved core-side hook registration, but
  never separately answered how per-role env config reaches a core-side-
  registered hook). If so, this repo cannot execute item 4 correctly until
  core exposes a mechanism (e.g. a settings file core's gate reads by
  walking up from `CLAUDE_PROJECT_DIR`, or a rulebook-side supplementary
  `hooks.json` entry that layers an env-prefixed second invocation of the
  same core script). This proposal recommends filing that gap back against
  core rather than inventing a local workaround.
- **(b)** If a mechanism does exist and was simply not found in this
  survey's reading of the landed files, phase 2 uses it directly and this
  section becomes a one-line confirmation in the phase-2 record instead of
  an open question.

Phase 2 must resolve which of (a)/(b) applies **before** deleting the local
`record-fields-gate.sh` — deleting it first and discovering no override
path exists would silently regress this role's terminal-state behavior.

### 5. `stub-check.sh` pass, recorded

Copy `core/hooks/tests/stub-check.sh` verbatim into `review/hooks/tests/
stub-check.sh`. Run `bash review/hooks/tests/stub-check.sh review/hooks`
after items 2–4 land; `docs/issue-31/reports/implementation.md` states the
pass/fail result verbatim, per the issue's item 5. A pass requires: no
`trailer-gate.sh`/`record-fields-gate.sh`/`handbook-trigger-gate.sh`/
`parse-check.sh` found under `review/hooks` (depth ≤3), and `directive.sh`
matching the structural stub shape (source line + `core_role_directive`
call, no regrown boilerplate) — `closed-checks-gate.sh` is not one of the
four names `stub-check.sh` scans for, so it is unaffected by this check.

## What is deliberately out of scope

- `review/hooks/closed-checks-gate.sh` — role-specific logic with no core
  canon counterpart; not one of the issue's named items.
- Installing the `core`/`warrant` plugins into any live session — that is
  on-the-record's job, not a file this repo writes.
- Any change to `review/.claude-plugin/plugin.json`'s `name`/`description`/
  `author` fields.

## How this will be judged

- `stub-check.sh` exits 0 against `review/hooks/` post-change.
- `hooks.json` contains no `PreToolUse` entry for any of the three deleted
  gate filenames; `closed-checks-gate.sh`'s entry is unchanged.
- `directive.sh` matches the structural stub shape `stub-check.sh` checks
  for.
- `trailer-gate.sh`, `record-fields-gate.sh`, `handbook-trigger-gate.sh` no
  longer exist under `review/`.
- The `RECORD_FIELDS_TERMINAL_STATES` question (item 4) is resolved one way
  or the other before the gate copy is deleted — not silently dropped.
