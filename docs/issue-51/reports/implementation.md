---
kind: coding-record
subject: issue-51
produced_by: implementation
code_under_review: tests/lib/test_env_resolve.py, review-severity/tests/severity-gate-test.sh, review-record-norm/tests/closed-checks-gate-test.sh, review-traceability/tests/traceability-gate-test.sh, review-proposal-completeness/tests/proposal-completeness-gate-test.sh, tests/run-gate-tests.sh
type: test
breaking: false
verdict: pass
loop_state: landed
---

# implementation record — issue-51

## Summary of work

Adopted the on-the-record canonical test-env resolution convention
(`docs/specs/test-env-resolution.md`, issue #551) into this rulebook's
four gate-test scripts and their aggregate runner, per the approved phase-1
proposal `docs/issue-51/proposals/2026-08-09-adopt-test-env-resolution.md`:

1. Added `tests/lib/test_env_resolve.py` — verbatim vendored copy of the
   convention's reference resolver (env var -> caller-supplied sibling
   candidate -> SKIP, exit 75), with a header comment naming its upstream
   source and the vendoring rationale (read-only sibling checkout, no
   cross-repo import possible).
2. In each of `review-severity/tests/severity-gate-test.sh`,
   `review-record-norm/tests/closed-checks-gate-test.sh`,
   `review-traceability/tests/traceability-gate-test.sh`, and
   `review-proposal-completeness/tests/proposal-completeness-gate-test.sh`:
   relocated the script's existing `missing-core -> deny` case (issue-75/
   issue-45 provenance) to run first and unconditionally, then added a
   resolution preamble that calls the vendored resolver with the script's
   own sibling-core guess path as the candidate. On exit 75 (SKIP) the
   script prints the tally-so-far with a SKIP note and exits 75 before
   reaching any other case; on success it exports the resolved
   `CLAUDE_PLUGIN_ROOT_CORE` so every remaining subprocess call inherits
   it, then runs the full case list unchanged.
3. In `tests/run-gate-tests.sh`: changed the per-suite branch so a
   sub-script exiting 75 increments a new `skip` tally (printed as
   `SKIP: $t`) rather than `fail`, and the final tally/exit code reflect
   `fail` only.

## Why

Basis: `docs/issue-51/proposals/2026-08-09-adopt-test-env-resolution.md`,
approved via issue comment `APPROVE issue-51/implementation`
(JiwonJung94, on issue #51). Rationale for vendoring the reference module
verbatim rather than hand-rolling an inline env check per script is
recorded in that proposal's `## Rationale`.

## Acceptance checks (issue #51)

1. **SKIP contract with no core reachable** — ran with
   `CLAUDE_PLUGIN_ROOT_CORE` unset (`env -u CLAUDE_PLUGIN_ROOT_CORE bash
   tests/run-gate-tests.sh`): each of the four suites ran its
   `missing-core` case (passed, `deny`), printed
   `SKIP: core plugin unreachable — unverifiable outside spawn env` to
   stderr, and exited 75; the aggregate runner tallied all four as SKIP
   (not FAIL) and exited 0. Zero misleading FAIL lines. result: passed.
2. **No weakened assertions with core reachable** — ran with this
   session's real `CLAUDE_PLUGIN_ROOT_CORE` set: `bash
   tests/run-gate-tests.sh` ran every case in all four suites (17 + 22 +
   … all previously-existing cases), 4 suites passed, 0 skipped, 0
   failed — identical pass tally shape to the pre-change branch, no
   assertion dropped or weakened. result: passed.
3. **Convention doc referenced** — `grep -rl test-env-resolution
   review-*/tests tests/` lists all five changed/added files
   (`tests/lib/test_env_resolve.py`, the four `*-gate-test.sh` scripts,
   `tests/run-gate-tests.sh`). result: passed.
4. **Empty-state check** — no script's failure traced to a real defect;
   all four scripts' non-missing-core cases pass unchanged when core is
   reachable, so no finding needed masking behind SKIP.

## closed_checks

- check: skip-contract-no-core — `env -u CLAUDE_PLUGIN_ROOT_CORE bash
  tests/run-gate-tests.sh` → 4 suites skipped, 0 failed, exit 0.
  code_under_review: tests/run-gate-tests.sh. result: passed.
- check: full-pass-core-reachable — `bash tests/run-gate-tests.sh` (real
  spawn env) → 4 suites passed, 0 skipped, 0 failed.
  code_under_review: tests/lib/test_env_resolve.py, review-severity/tests/severity-gate-test.sh, review-record-norm/tests/closed-checks-gate-test.sh, review-traceability/tests/traceability-gate-test.sh, review-proposal-completeness/tests/proposal-completeness-gate-test.sh.
  result: passed.
- check: convention-doc-referenced — `grep -rl test-env-resolution
  review-*/tests tests/` lists all 5 changed files. result: passed.

## What did not work

None.

## Open findings

None.

## Doc placement

- No new env var, dependency, migration, or setup step introduced — the
  vendored module is a test-only Python script invoked via `python3`,
  already a repo dependency (used throughout the existing test harnesses).
  No doctrine-ladder placement beyond this record and the phase-1
  proposal/survey already on disk was required.
