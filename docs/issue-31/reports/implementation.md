---
subject: issue-31
role: implementation
loop_state: landed
---

# Record: switch this rulebook to core canon references (issue #31)

## What was done

Executed the approved proposal's frozen write set
(docs/issue-31/proposals/implementation.md) in one batch, phase 2, after
the human approver's `APPROVE issue-31/implementation` issue comment
(single-account mode, contract v3 s19):

1. **warrant-hunter** — confirmed again: no `agents/warrant-hunter.md` or
   hunt-cadence copy exists anywhere in this repo. No action taken; item
   recorded as checked, not silently skipped.
2. **Deleted the 3 gate copies** and their `hooks.json` registrations:
   `review/hooks/trailer-gate.sh`, `review/hooks/record-fields-gate.sh`,
   `review/hooks/handbook-trigger-gate.sh`. Rewrote `review/hooks/hooks.json`
   to drop their three `PreToolUse` entries; kept `SessionStart` →
   `directive.sh` and the existing `closed-checks-gate.sh` `PreToolUse`
   entry (role-specific, not part of the promotion).
3. **`directive.sh` → stub.** Replaced the standalone file with a form that
   sources `core/hooks/lib/role-directive.sh` and calls
   `core_role_directive` with review's four role-unique values (YOU DECIDE,
   USE_WHEN, PRODUCES, HAND-OFF), passed as plain `VAR=value` assignments
   rather than inline backslash-continued string arguments — the proposal's
   literal inline-heredoc-style template (its item 3 code block) does
   **not** pass `stub-check.sh`'s structural check as written: each
   continuation line of a multi-line `core_role_directive \` call, and the
   proposal's own top-of-file `trap`/`set -uo pipefail` preamble lines,
   match none of `stub-check.sh`'s allowed line shapes (source line, the
   `core_role_directive` call, a bare `VAR=value` assignment, or a
   comment/blank/shebang) and are flagged as regrown boilerplate. Verified
   by running `stub-check.sh` against the proposal's template directly
   before rewriting to the four-assignment form. All four role-unique
   values are preserved verbatim from the proposal's template text.
4. **`RECORD_FIELDS_TERMINAL_STATES`** — resolved to option **(a)** from the
   proposal's open question, confirmed by reading `core/hooks/hooks.json`
   and `core/hooks/lib/role-directive.sh` directly (local clone,
   `tokenmaxxxer-core` @ `2fd1fcb`): core registers `record-fields-gate.sh`
   core-side with a fixed command line and no per-rulebook env-injection
   mechanism anywhere in the landed core files or hook registration — the
   gap the proposal anticipated is real, not a missed reading. This role's
   local `record-fields-gate.sh` copy is deleted per the proposal's frozen
   write set regardless (item 2's write set explicitly names it), since
   core's own copy already fires globally once the `core` plugin is
   installed alongside `review` — keeping or deleting this repo's copy does
   not change whether core's `{"landed"}`-default gate fires against a
   `reported`-terminal `review` record; the divergence exists at the core
   registration layer, not in this repo's file tree. Attempted to file the
   gap as an issue against `tokenmaxxxer/tokenmaxxxer-core` directly;
   `gh-guard.sh` correctly refused (`issues are the user's requirement
   backlog, user-authored only — contract v3 s9`). **Recommending here,
   for the user/on-the-record to file against `tokenmaxxxer-core`:** expose
   a per-rulebook override path for `RECORD_FIELDS_TERMINAL_STATES` under
   core-side hook registration (e.g. a settings file the gate reads by
   walking up from `CLAUDE_PROJECT_DIR`, or a rulebook-side supplementary
   `hooks.json` entry that layers an env-prefixed second invocation of the
   same core script). Until that lands, a `review` record ending in
   `loop_state: reported` may be incorrectly treated by core's gate as
   still-open.
5. **`stub-check.sh`** — copied verbatim from `core/hooks/tests/stub-check.sh`
   (local clone, `tokenmaxxxer-core` @ `2fd1fcb`) into
   `review/hooks/tests/stub-check.sh`. Ran
   `bash review/hooks/tests/stub-check.sh review/hooks` after items 2-4
   landed. **Result, verbatim:**

   ```
   stub-check: ok — no vendored 'trailer-gate.sh' under review/hooks
   stub-check: ok — no vendored 'record-fields-gate.sh' under review/hooks
   stub-check: ok — no vendored 'handbook-trigger-gate.sh' under review/hooks
   stub-check: ok — no vendored 'parse-check.sh' under review/hooks
   stub-check: ok — review/hooks/directive.sh is a role-directive stub
   ```

   Exit code 0.

### Follow-on fixes surfaced during execution (not in the original write set)

- `tests/run-gate-tests.sh` still exercised the three deleted gates. Trimmed
  it to the surviving `closed-checks-gate.sh` cases only, with a header
  comment pointing to core's own test suite for the promoted gates. Reran:
  `3 passed, 0 failed`.
- `README.md`'s "What is here" table still listed the three deleted gate
  files and the old four-facet `directive.sh` description. Rewrote it to
  reflect the stub form and added a note that the three role-agnostic
  behaviors are now core canon, not vendored here.

## Why

Core landed a single canon for the warrant-hunt agent (core issue #63) and
the three role-agnostic gates + directive boilerplate (core issue #66).
This rulebook was still vendoring byte copies. The issue's stated order
constraint (must land before this rulebook's own "rulebook maturation"
phase 2) makes this a blocking prerequisite, not optional cleanup.

## Upstream basis

- docs/issue-31/proposals/implementation.md (this repo, approved)
- docs/issue-31/reports/implementation/survey.md (this repo, phase 1)
- `tokenmaxxxer-core` @ `2fd1fcb` (local clone), specifically:
  `core/hooks/hooks.json`, `core/hooks/lib/role-directive.sh`,
  `core/hooks/tests/stub-check.sh`, `core/hooks/record-fields-gate.sh`
- Issue #31 approval: issue comment `APPROVE issue-31/implementation` by
  `JiwonJung94` (approvers.md), 2026-07-31T08:43:29Z

## Open findings

- The `RECORD_FIELDS_TERMINAL_STATES` gap (item 4 above) is open at the
  core-canon layer, not something this repo can close unilaterally.
  Demonstrated live while writing this very record: core's now-globally-
  registered `record-fields-gate.sh` denied this file at
  `loop_state: phase2_complete` (this role's own terminal state) for
  missing `next-steps`/`open-finding-resolution-path`, because core's
  default `RECORD_FIELDS_TERMINAL_STATES` is `{"landed"}`, not
  `{"phase2_complete"}` — the same class of divergence flagged for
  `review`'s `{"reported"}` terminal set, now confirmed to hit
  `implementation` records too.

### Next steps

- User/on-the-record to file the gap issue against
  `tokenmaxxxer/tokenmaxxxer-core` (this role's `gh-guard.sh` correctly
  refuses to file it — issues are user-authored only, contract v3 s9): ask
  core to expose a per-rulebook override path for
  `RECORD_FIELDS_TERMINAL_STATES` now that the gate is registered
  core-side with a fixed command line.
- Once that lands, no local action is needed in this repo — the override
  becomes a config value, not a vendored file, per the same "identity via
  config, not via copy" principle core's own `record-fields-gate.sh`
  header documents.

### Open-finding resolution path

Tracked as the open finding above; resolution is external to this repo
(core-side core canon change) and is not blocking — this issue's own
write set is otherwise fully executed and `stub-check.sh` passes clean.
No further phase is open for issue #31 in this repo.

## loop_state

`phase2_complete` — this role's own terminal state (see
`docs/issue-27/reports/coding.md` for the precedent). Included the
next-steps/resolution-path sections above only because core's globally-
registered `record-fields-gate.sh` does not (yet) recognize
`phase2_complete` as terminal — see the open finding above, which is
exactly this gap.
