---
status: proposed
files:
  - tests/lib/test_env_resolve.py
  - review-severity/tests/severity-gate-test.sh
  - review-record-norm/tests/closed-checks-gate-test.sh
  - review-traceability/tests/traceability-gate-test.sh
  - review-proposal-completeness/tests/proposal-completeness-gate-test.sh
  - tests/run-gate-tests.sh
---

## Request
Adopt the canonical test-env resolution convention landed at on-the-record
`docs/specs/test-env-resolution.md` (issue #551) in this rulebook's four
gate-test scripts and their aggregate runner, so that on a plain checkout
without `CLAUDE_PLUGIN_ROOT_CORE` set (and no `../../core` sibling on disk)
they SKIP with the convention's explicit message and exit code instead of
printing dozens of misleading `FAIL` lines. No assertion that runs when core
IS reachable may weaken.

## Constraints
- The convention's resolution order and SKIP contract (env var -> caller
  candidates -> SKIP, stderr message, exit 75/EX_TEMPFAIL) are already
  frozen upstream; this proposal does not redesign them, only wires them in.
- The existing `missing-core -> deny` case in each of the four scripts
  (issue-75/issue-45 provenance) tests the *gate's* own fail-closed
  contract, not the test runner's environment — it must keep running,
  unchanged, in both regimes (core reachable or not), never itself skipped.
- The on-the-record sibling checkout on this machine is read-only
  (`git pull`/`fetch` fail: read-only filesystem) — cross-repo `import` of
  its `gates/test_env_resolve.py` is not viable; the module must be vendored.
- No change to any `hooks/*-gate.sh` gate script itself — the bug is in the
  test scripts' blindness to environment, not in gate behavior.

## Rationale
Considered making each `*-gate-test.sh` do its own ad hoc env-var check
(e.g. `[ -z "${CLAUDE_PLUGIN_ROOT_CORE:-}" ] && [ ! -d ../../core ] && exit
0`) inline, without vendoring the reference module. Rejected: that would
re-implement (and likely drift from) the convention's own resolution
order and its explicit distinction between "SKIP" (exit 75) and a gate's
real pass/fail/deny exits (0/1/2) — exactly the kind of hand-rolled
resolution the convention doc says it exists to stop ("consumers stop
hand-rolling their own"). Vendoring the verbatim reference module and
invoking it as the spec's documented Bash-test-runner CLI shape
(`python3 -m ...`-equivalent) keeps this repo's adoption byte-identical to
the upstream contract and auditable by diff against the spec doc, at the
cost of one small vendored file needing a manual re-sync if the upstream
module changes (acceptable: the module is small, stable, and the spec doc
itself says adoption is "separate work per repo").

## What will be done
1. Add `tests/lib/test_env_resolve.py`: verbatim copy of the reference
   resolver from `docs/specs/test-env-resolution.md` (issue #551), with a
   comment noting its upstream source and the vendoring rationale above.
2. In each of the four `*-gate-test.sh` scripts, add a preamble (after the
   existing `set -uo pipefail` / `HERE`/`HOOKS` setup, before the case
   list) that:
   - Calls the vendored resolver with candidate `"$HERE/../../core"` (the
     same sibling path each gate already guesses at line 2).
   - On exit 0: `export CLAUDE_PLUGIN_ROOT_CORE="<resolved path>"` so every
     subsequent gate subprocess call inherits it, then proceeds to the
     existing case list unchanged.
   - On exit 75: print the convention's SKIP message, then skip every case
     that needs real core reachability and exit 75 — except the
     script's own `missing-core -> deny` case, which stays self-contained
     (it points `CLAUDE_PLUGIN_ROOT_CORE` at its own nonexistent path and
     asserts the gate's fail-closed behavior) and must run in BOTH regimes:
     it is exactly the regression check that matters most in a CI
     environment that never has real core reachable, so silencing it there
     would remove coverage precisely where it is needed (warrant hunt,
     after-proposal, stance 0: caught this originally proposing to skip it
     unconditionally). Concretely: run `missing-core` before the SKIP
     branch's early exit, tally it normally, then exit 75 with the SKIP
     message covering only the remaining, core-dependent cases.
   - References `docs/specs/test-env-resolution.md` in a comment so `grep
     test-env-resolution` finds every adopting script (acceptance check).
3. In `tests/run-gate-tests.sh`, change the per-suite exit-code branch so
   `bash "$t"` exiting `75` increments a new `skip` tally (not `fail`),
   prints `SKIP: $t`, and the final tally line and exit code reflect
   `fail` only — a run where every suite is 0/75 and none is a real
   failure exits 0.

## Out of scope
- Any change to `hooks/*-gate.sh` gate scripts' own core-sourcing line.
- Adopting the convention in any other rulebook repo (per the spec doc's
  own Out of scope: each repo tracks its own adoption).
- The convention doc's optional network-fetch extension — not adopted;
  canonical SKIP-on-unreachable only, per the spec's own recommendation.
- Any new test cases beyond wiring the resolution/SKIP preamble.

## How you'll know it worked
- With `CLAUDE_PLUGIN_ROOT_CORE` unset and no `../../core` sibling present:
  running `tests/run-gate-tests.sh` (and each `*-gate-test.sh` directly)
  prints the SKIP message per suite, still runs and passes each script's
  self-contained `missing-core -> deny` case, exits 75 per script and 0
  overall — zero misleading `FAIL` lines, and no dropped coverage of the
  fail-closed regression check.
- With `CLAUDE_PLUGIN_ROOT_CORE` set to a real core checkout (this
  session's actual spawn env): running the same commands produces the
  identical pass/fail tally as on the pre-change branch (no assertion
  weakened, `missing-core` cases still assert `deny`).
- `grep -rl test-env-resolution review-*/tests tests/` lists all five
  changed files.
