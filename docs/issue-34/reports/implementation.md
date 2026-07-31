---
subject: issue-34
role: implementation
loop_state: phase2_complete
---

# Record: recover vendored stub-check.sh copy (issue #34)

## What was done

Executed the approved proposal (`docs/issue-34/proposals/implementation.md`)
after human approval, per core #69's canon that rulebooks reference core's
installed `stub-check.sh` at run time and never vendor their own copy:

1. **Deleted** `review/hooks/tests/stub-check.sh` (`git rm`) — the vendored
   copy tracked since a80bbfb (issue-31 delivery).
2. **`hooks.json`** — no change. Survey
   (`docs/issue-34/reports/implementation/survey.md`) confirmed
   `review/hooks/hooks.json` never registered `stub-check.sh`; it only
   hooks `directive.sh` (SessionStart) and `closed-checks-gate.sh`
   (PreToolUse).
3. **Doc updates** — `README.md` and `docs/handbooks/review-hooks.md`
   rewritten to describe stub-check as a core-canon drift detector run by
   reference against the installed `core` plugin, not a locally vendored
   file.
4. **Ran the core-canon stub-check by reference** against
   `/home/jwjung/tokenmaxxxer/tokenmaxxxer-core/core/hooks/tests/stub-check.sh`
   (local clone of the `core` plugin, the path `${CLAUDE_PLUGIN_ROOT}`
   resolves to when the plugin is installed), targeting this repo's
   `review/hooks`, both before and after the deletion.

## Why

Issue #34 (core #69 canon rollout): stub-check itself became a core hook
(`core/hooks/hooks.json`), fired for every plugin install. Any rulebook
that still vendors its own copy is drift, not a stub — the vendored file
now fails core's own drift check (see the "before" run below), so removal
is required to bring this repo back in line with canon.

## Core reference-execution stub-check run

Before deletion (confirms the vendored copy was in fact drift core now
flags):

```
$ bash /home/jwjung/tokenmaxxxer/tokenmaxxxer-core/core/hooks/tests/stub-check.sh review/hooks
stub-check: ok — no vendored 'trailer-gate.sh' under .../review/hooks
stub-check: ok — no vendored 'record-fields-gate.sh' under .../review/hooks
stub-check: ok — no vendored 'handbook-trigger-gate.sh' under .../review/hooks
stub-check: ok — no vendored 'parse-check.sh' under .../review/hooks
stub-check: FAIL — vendored copy of core canon file 'stub-check.sh' found:
.../review/hooks/tests/stub-check.sh
  This file is now a core hook (core/hooks/hooks.json), fired for
  every plugin install. A local copy is drift, not a stub — delete
  it and drop the file's own hooks.json entry, if any (issue-66).
stub-check: ok — .../review/hooks/directive.sh is a role-directive stub
$ echo $?
1
```

After `git rm review/hooks/tests/stub-check.sh`:

```
$ bash /home/jwjung/tokenmaxxxer/tokenmaxxxer-core/core/hooks/tests/stub-check.sh review/hooks
stub-check: ok — no vendored 'trailer-gate.sh' under .../review/hooks
stub-check: ok — no vendored 'record-fields-gate.sh' under .../review/hooks
stub-check: ok — no vendored 'handbook-trigger-gate.sh' under .../review/hooks
stub-check: ok — no vendored 'parse-check.sh' under .../review/hooks
stub-check: ok — no vendored 'stub-check.sh' under .../review/hooks
stub-check: ok — .../review/hooks/directive.sh is a role-directive stub
$ echo $?
0
```

Clean pass (exit 0), core-canon script run by reference against this
repo's `review/hooks`, no vendored copy present.

## Open findings

None new. All items in the proposal's acceptance criteria are satisfied:
`review/hooks/tests/stub-check.sh` no longer exists, `hooks.json` is
unchanged (it never referenced the file), README/handbook describe
reference execution, and this record captures the clean pass. The two
sections below are included only because core's globally-registered
`record-fields-gate.sh` does not (yet) recognize `phase2_complete` as
terminal (same already-tracked gap noted in
`docs/issue-31/reports/implementation.md`).

### Next steps

None for this issue's own scope — the write set is fully executed and
stub-check passes clean by reference. The one open item is the
pre-existing, already-tracked `RECORD_FIELDS_TERMINAL_STATES` gap (see
`docs/issue-31/reports/implementation.md`'s "Open findings"), which is
external to this repo and not blocking here.

### Open-finding resolution path

No open finding specific to issue #34. The `RECORD_FIELDS_TERMINAL_STATES`
gap referenced above is tracked and resolved externally (core-side change
to `tokenmaxxxer-core`), not by any further action in this repo.

## loop_state

`phase2_complete` — this role's own terminal state (see
`docs/issue-31/reports/implementation.md` for the precedent, which also
notes core's globally-registered `record-fields-gate.sh` does not yet
recognize `phase2_complete` as terminal — a known, already-tracked gap,
not new to this record).
