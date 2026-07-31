# issue-34 current-state survey (implementation)

Scout skip: pure recovery of an already-canon-decided policy (core #69) with
no design decision open — this is a mechanical vendoring rollback, not a
build. Skip condition: "spec literally leaves no design decision open."

## Vendored copy found

- `review/hooks/tests/stub-check.sh` — tracked, committed in a80bbfb
  (issue-31 delivery). Header comment states it is "copied verbatim from
  `core/hooks/tests/stub-check.sh`" (source: `tokenmaxxxer-core` repo).
  This is exactly the pattern core #69 now forbids: rulebooks reference
  core's installed copy at run time, never vendor their own.

## hooks.json registration

- `review/hooks/hooks.json` has exactly two entries: `SessionStart` →
  `directive.sh`, `PreToolUse` (Write|Edit|MultiEdit|NotebookEdit) →
  `closed-checks-gate.sh`. **No entry invokes `stub-check.sh`.** It is not
  hooked to fire automatically; issue-31's report shows it was run manually
  (`bash review/hooks/tests/stub-check.sh review/hooks`) and the pass
  recorded by hand. So removal needs no hooks.json edit — only doc/README
  cleanup plus the file deletion.

## Other references to the vendored copy

- `README.md:30` — describes `review/hooks/tests/stub-check.sh` as
  "core canon, copied verbatim."
- `docs/handbooks/review-hooks.md:17-21` — same "copied verbatim from
  `core/hooks/tests/stub-check.sh`" description, under the hooks-inventory
  section.
- `docs/issue-31/reports/implementation.md` and
  `docs/issue-31/proposals/implementation.md` — historical record of the
  original copy-in decision; left as-is (history, not current state).

## What "reference execution" means here

`core/hooks/tests/stub-check.sh` does not exist in this repo — it ships
with the separately-installed `core` plugin, resolved at run time via
`${CLAUDE_PLUGIN_ROOT}` (same pattern `directive.sh` already uses to source
`core/hooks/lib/role-directive.sh`). Passing stub-check going forward means
running the core plugin's installed copy against `review/hooks` — no local
file to invoke.

## Scope of the fix

1. Delete `review/hooks/tests/stub-check.sh`.
2. Update `README.md` and `docs/handbooks/review-hooks.md` to describe
   stub-check as core-canon reference execution, not a vendored file.
3. Record the reference-execution pass in
   `docs/issue-34/reports/implementation.md` (phase 2, post-Approve).
4. No `hooks.json` change needed (confirmed above).
