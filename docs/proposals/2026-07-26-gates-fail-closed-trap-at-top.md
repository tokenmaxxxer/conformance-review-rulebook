---
status: proposed
files:
  - review-agent-rulebook/review-cycle/hooks/state-gate.sh
  - review-agent-rulebook/review-cycle/hooks/path-ownership-gate.sh
  - review-agent-rulebook/review-cycle/hooks/doc-bucket-gate.sh
  - review-agent-rulebook/review-cycle/hooks/record-fields-gate.sh
  - review-agent-rulebook/review-cycle/hooks/closed-checks-gate.sh
  - review-agent-rulebook/review-cycle/hooks/handbook-trigger-gate.sh
  - review-agent-rulebook/review-cycle/hooks/trailer-gate.sh
  - review-agent-rulebook/review-cycle/hooks/run-gate-tests.sh
---

# Fail-closed trap-at-top for every PreToolUse tool-gating gate

## Intent

Every PreToolUse tool-gating gate must establish fail-closed BEFORE anything
else in the script can fail. Claude Code PreToolUse hooks treat any non-2 exit
as NON-BLOCKING (fail-OPEN). A gate that aborts for any reason before its
verdict logic runs — a failed `source`, a `set -euo pipefail` abort, an unbound
variable, a syntax path — currently exits with a non-2 code and is therefore
silently allowed. This closes that entire class.

## Change

As the FIRST executable statement, immediately after the shebang and before any
`source`/`set`/other code, each PreToolUse gate installs an EXIT trap:

    __fc(){ rc=$?; if [ "$rc" != 0 ] && [ "$rc" != 2 ]; then echo "fail-closed: gate aborted (rc=$rc)" >&2; exit 2; fi; }
    trap __fc EXIT

The trap inspects the process exit code and, if it is neither 0 (allow) nor 2
(deny), re-exits 2 (DENY). Legitimate terminal `exit 0` (allow) and `exit 2`
(deny) verdicts are preserved exactly; only abnormal/other exits are forced to
2. No verdict-logic change on well-formed input.

This composes with the already-landed python try/except and shell exit-code
remap (docs/proposals/2026-07-26-gates-fail-closed-on-internal-error.md); those
are not removed. The trap is a belt-and-suspenders guarantee for the pre-logic
window those measures cannot reach.

### Gates changed (all PreToolUse tool-gating gates in this rulebook)

- state-gate.sh
- path-ownership-gate.sh
- doc-bucket-gate.sh
- record-fields-gate.sh
- closed-checks-gate.sh
- handbook-trigger-gate.sh
- trailer-gate.sh

Never-blocking hooks (inject-transition-rules.sh and any capture/directive/
report-style hooks) are intentionally untouched. None of these gates sources a
`_gate-common.sh`; none had a pre-existing EXIT trap to merge with, so the
trap-at-top is not at risk of being overwritten.

## Tests

`run-gate-tests.sh` gains two cases:

- (t0) asserts `trap __fc EXIT` is the first executable statement (before any
  `set`/`source`) in every PreToolUse gate — the trap-at-top invariant.
- (t) reproduces the real gate with a failing `source` of a non-existent file
  injected immediately after the installed trap line (still pre-verdict), and
  asserts the gate exits 2. Negative control: the same abort without the trap
  exits 1 (fail-open).

All pre-existing allow/deny cases continue to pass (33 passed, 0 failed), and
the procedure-gate harness is unaffected (24 passed, 0 failed).
