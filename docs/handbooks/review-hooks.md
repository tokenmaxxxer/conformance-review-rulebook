# review/hooks — current state

Current state. Edited from now on to stay true.

`review/hooks/` ships two role-owned files. A third check, stub-check, is
core canon (core #69) and is run by reference against the installed `core`
plugin — never vendored as a local copy:

- `directive.sh` — SessionStart stub. Sources core canon's
  `core/hooks/lib/role-directive.sh` and calls `core_role_directive` with
  review's four role-unique values (YOU DECIDE / USE_WHEN / PRODUCES /
  HAND-OFF). No local boilerplate; core's `stub-check.sh`, run by
  reference, enforces this shape.
- `closed-checks-gate.sh` — PreToolUse (Write|Edit|MultiEdit|NotebookEdit).
  Role-specific: a `closed_checks` cite must match the record's
  `code_under_review:` sha, never the working branch HEAD. Has no core
  canon counterpart.
- `stub-check.sh` — core canon (`core/hooks/tests/stub-check.sh`), run by
  reference against the installed `core` plugin, not vendored under
  `review/hooks/`. Fails if a vendored copy of `trailer-gate.sh` /
  `record-fields-gate.sh` / `handbook-trigger-gate.sh` / `parse-check.sh`
  (or `stub-check.sh` itself) reappears under `review/hooks/` (depth ≤3),
  or if `directive.sh` regrows local boilerplate instead of staying a
  stub.

Commit-trailer enforcement (`Subject: issue-<n>`), §20 record-fields
minimum-content checks, and §21 same-turn handbook sync are **not**
vendored here — they are core canon (`core/hooks/hooks.json`, registered
core-side, matcher `.*`), fired for every plugin install once the `core`
plugin is present alongside `review` (issue-31, following core issues
#63/#66).

`tests/run-gate-tests.sh` (repo-level, never installed) exercises only
`closed-checks-gate.sh` now — the three promoted gates' test coverage
lives in core's own test suite.

## Known gap

Core's `record-fields-gate.sh` defaults `RECORD_FIELDS_TERMINAL_STATES` to
`{"landed"}` and, being registered core-side with a fixed command line,
exposes no per-rulebook override path. This role's own terminal states
(`review`'s `reported`, `implementation`'s `phase2_complete`) are not in
that default set, so a genuinely-terminal record here is currently treated
as still-open by core's gate until a per-rulebook override mechanism is
added core-side. See `docs/issue-31/reports/implementation.md`'s "Open
findings" for the full detail and the recommended core-side fix.
