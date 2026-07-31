#!/usr/bin/env bash
# Aggregate runner: the `review` plugin set is now five self-contained
# plugins (issue #39), each owning its own gate test file under its own
# tests/ directory. closed-checks-gate.sh moved to review-record-norm/
# (was review/hooks/closed-checks-gate.sh). trailer-gate.sh,
# record-fields-gate.sh, and handbook-trigger-gate.sh are core canon
# (core/hooks/hooks.json, issue-31) — their tests live in core's own test
# suite, not here.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
ROOT="$HERE/.."

pass=0; fail=0
for t in \
  "$ROOT/review-traceability/tests/traceability-gate-test.sh" \
  "$ROOT/review-severity/tests/severity-gate-test.sh" \
  "$ROOT/review-record-norm/tests/closed-checks-gate-test.sh" \
  "$ROOT/review-proposal-completeness/tests/proposal-completeness-gate-test.sh" \
; do
  echo "== $t =="
  if bash "$t"; then
    pass=$((pass+1))
  else
    fail=$((fail+1))
    echo "FAIL: $t"
  fi
  echo
done

printf '\n== %d suites passed, %d suites failed ==\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
