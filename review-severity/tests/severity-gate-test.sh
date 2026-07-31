#!/usr/bin/env bash
# review-severity's own gate (severity-gate.sh), exercised as a real
# subprocess. Mirrors tests/run-gate-tests.sh's harness shape.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
HOOKS="$HERE/../hooks"
pass=0; fail=0
report() { if [ "$2" = "$1" ]; then pass=$((pass+1)); printf 'ok     %-34s %s\n' "$3" "$2"; else fail=$((fail+1)); printf 'FAIL   %-34s want=%s got=%s\n' "$3" "$1" "$2"; fi; }

REC=docs/issue-7/reports/review.md
run() { # want name gate file content [extra_env...]
  want="$1"; name="$2"; gate="$3"; file="$4"; content="$5"; shift 5
  td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"; mkdir -p "$td/docs/issue-7/reports"
  payload="$(printf '{"tool_name":"Write","tool_input":{"file_path":"%s","content":%s},"cwd":"%s"}' \
    "$file" "$(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$content")" "$td")"
  printf '%s' "$payload" | env CLAUDE_PROJECT_DIR="$td" "$@" /bin/bash "$HOOKS/$gate" >/dev/null 2>&1
  rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
  rm -rf "$td"; report "$want" "$got" "$name"
}

run allow table-value           severity-gate.sh "$REC" $'severity: High\n'
run allow table-value-with-band severity-gate.sh "$REC" $'severity: Critical (S0)\n'
run allow table-value-msft      severity-gate.sh "$REC" $'severity: Important\n'
run deny  numeric-decimal       severity-gate.sh "$REC" $'severity: 7.5\n'
run deny  numeric-fraction      severity-gate.sh "$REC" $'severity: 18/25\n'
run allow no-severity-field     severity-gate.sh "$REC" $'no field here at all\n'
run allow kill-switch-numeric   severity-gate.sh "$REC" $'severity: 7.5\n' env REVIEW_SEVERITY_GATE_OFF=1
run deny  unrecognized-token    severity-gate.sh "$REC" $'severity: Sev-Zero\n'

# malformed stdin -> deny
td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"; mkdir -p "$td/docs/issue-7/reports"
printf 'not json at all' | env CLAUDE_PROJECT_DIR="$td" /bin/bash "$HOOKS/severity-gate.sh" >/dev/null 2>&1
rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
rm -rf "$td"; report deny "$got" malformed-stdin

printf '\n== %d passed, %d failed ==\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
