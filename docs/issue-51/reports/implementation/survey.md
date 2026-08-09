# Survey — issue #51

## Skip condition
Scout does not apply: the spec (on-the-record docs/specs/test-env-resolution.md,
issue #551) already fixes the resolution order, the SKIP contract, and the
reference module verbatim. There is no product-shaped design decision open —
only how to wire an already-frozen convention into this repo's specific test
scripts. Design-decision scouting is skipped for that reason; the only open
question (vendor vs. fetch the reference module) is answered directly below,
not scouted.

## Convention (fetched from on-the-record, issue #551)
Resolution order: `$CLAUDE_PLUGIN_ROOT_CORE` (if it contains
`hooks/lib/gate-lib.sh`) -> first caller-supplied sibling candidate
containing it -> SKIP (stderr `SKIP: core plugin unreachable — unverifiable
outside spawn env`, exit `75`/EX_TEMPFAIL, distinct from a gate's own
0/1/2). No network fetch inside the canonical module. Reference resolver:
`gates/test_env_resolve.py` (verbatim in the spec doc), CLI usage
`python3 -m gates.test_env_resolve <candidates...>`; on-the-record repo is a
read-only sibling checkout here (git push/fetch blocked — read-only
filesystem), so the module must be vendored into this repo rather than
imported cross-repo.

## Current state — this repo's test scripts
Four self-contained gate-test scripts, aggregated by one runner:
- `review-severity/tests/severity-gate-test.sh` (133 lines)
- `review-record-norm/tests/closed-checks-gate-test.sh` (146 lines)
- `review-traceability/tests/traceability-gate-test.sh` (183 lines)
- `review-proposal-completeness/tests/proposal-completeness-gate-test.sh` (269 lines)
- `tests/run-gate-tests.sh` — invokes the four above as subprocesses, prints
  a suite tally, exits non-zero on any suite failure.

All four share one shape: a `run()`/`report()` harness that spawns the
matching `hooks/*.sh` gate as a real subprocess per case, in a fresh
`mktemp -d` + `git init`, and compares the gate's exit code
(0=allow/1=?/2=deny) against an expected verdict. None of the four scripts
set `CLAUDE_PLUGIN_ROOT_CORE` themselves before most cases — they rely on
whatever the invoking shell/session already has. Each gate script
(`hooks/*-gate.sh`) resolves core itself, independently, at line 2:
```
. "${CLAUDE_PLUGIN_ROOT_CORE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../core" && pwd -P)}/hooks/lib/gate-lib.sh" \
  || { echo "...: cannot source gate-lib.sh" >&2; exit 2; }
```
i.e. env var, then a hardcoded `../../core` sibling guess, then `exit 2`
(deny) if neither has `gate-lib.sh`. This exit-2-on-missing-core behavior is
intentional and tested directly: every one of the four scripts already
carries one `missing-core -> deny` case (issue-75/issue-45 provenance) that
sets `CLAUDE_PLUGIN_ROOT_CORE=$td/no-such-core` and asserts the gate denies
rather than allows — that assertion is about the gate's own fail-closed
contract, not about the test *runner's* environment, and must keep running
unchanged everywhere (with or without core reachable).

## The actual bug
On a plain checkout with `CLAUDE_PLUGIN_ROOT_CORE` unset and no `../../core`
sibling on disk, every *other* case in each script — dozens of
`allow`-expecting assertions — gets `deny` (exit 2) from the gate purely
because core is unreachable, and `report()` prints that as `FAIL`, not as an
environment problem. `tests/run-gate-tests.sh` then reports the whole suite
as failed. There is no message anywhere distinguishing "core unreachable"
from "the gate itself regressed" — exactly the ambiguity issue #551 names.
Verified reproducible: this session's env has `CLAUDE_PLUGIN_ROOT_CORE` set
to a real core checkout (spawn env), so the failure mode was confirmed by
inspection of the gate's sourcing line and the test harness's blind
subprocess-exit-code comparison, not by an unset-var repro run (would
require unsetting the session's own `CLAUDE_PLUGIN_ROOT_CORE`, which the
proposal will verify at build time instead).

## Exception carried over from the convention doc
The convention's own "Empty state" section names one enumerated exception:
a pytest suite with no core dependency at all is out of scope because it
never resolves core. This repo has no such script — all four gate-test
scripts here DO depend on core (every case shells out to a gate that
sources `gate-lib.sh`) — so no script in this repo qualifies for that
exception; all four are in scope.

## Write set implied
- `tests/lib/test_env_resolve.py` — new, vendored verbatim copy of the
  reference resolver (this repo cannot `import` cross-repo from
  on-the-record; the sibling checkout here is also read-only/unpushable).
- Each of the four `*-gate-test.sh` scripts — add a resolution+SKIP
  preamble that runs before the case list, doesn't touch the existing
  `missing-core` case (which deliberately points `CLAUDE_PLUGIN_ROOT_CORE`
  at a nonexistent path and must still run and pass in both regimes), and
  exports the resolved `CLAUDE_PLUGIN_ROOT_CORE` for the rest of the script
  when core is reachable so every subprocess call inherits it without each
  `run()`/`run_edit()`/etc. helper needing an edit.
- `tests/run-gate-tests.sh` — must not report a SKIP (exit 75 from a
  sub-script) as a suite FAIL; needs a case arm for that exit code,
  distinct tally, and the aggregate exit code must stay 0 when every suite
  either passed or explicitly skipped (never silently green a real
  failure).
