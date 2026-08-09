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

# Test-env resolution convention (docs/specs/test-env-resolution.md, issue
# #551): a suite script exits 75 when core is unreachable outside the
# spawn env — that is a SKIP, not a suite FAIL.
pass=0; fail=0; skip=0
for t in \
  "$ROOT/review-traceability/tests/traceability-gate-test.sh" \
  "$ROOT/review-severity/tests/severity-gate-test.sh" \
  "$ROOT/review-record-norm/tests/closed-checks-gate-test.sh" \
  "$ROOT/review-proposal-completeness/tests/proposal-completeness-gate-test.sh" \
; do
  echo "== $t =="
  bash "$t"; rc=$?
  case "$rc" in
    0) pass=$((pass+1)) ;;
    75) skip=$((skip+1)); echo "SKIP: $t" ;;
    *) fail=$((fail+1)); echo "FAIL: $t" ;;
  esac
  echo
done

printf '\n== %d suites passed, %d suites skipped, %d suites failed ==\n' "$pass" "$skip" "$fail"
[ "$fail" -eq 0 ]
