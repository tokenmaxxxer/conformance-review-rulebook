#!/usr/bin/env bash
# Exercises review-traceability/hooks/traceability-gate.sh as a real subprocess.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
HOOKS="$HERE/../hooks"
pass=0; fail=0
report() { if [ "$2" = "$1" ]; then pass=$((pass+1)); printf 'ok     %-34s %s\n' "$3" "$2"; else fail=$((fail+1)); printf 'FAIL   %-34s want=%s got=%s\n' "$3" "$1" "$2"; fi; }

run() { # want name gate file content [extra_env=...]
  want="$1"; name="$2"; gate="$3"; file="$4"; content="$5"; extra_env="${6:-}"
  td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"
  mkdir -p "$td/$(dirname "$file")"
  pf="$td/.payload.json"
  printf '{"tool_name":"Write","tool_input":{"file_path":"%s","content":%s},"cwd":"%s"}' \
    "$file" "$(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$content")" "$td" \
    > "$pf"
  env CLAUDE_PROJECT_DIR="$td" $extra_env /bin/bash "$HOOKS/$gate" < "$pf" >/dev/null 2>&1
  rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
  rm -rf "$td"; report "$want" "$got" "$name"
}

run_raw() { # want name gate raw_payload_string extra_env
  want="$1"; name="$2"; gate="$3"; payload="$4"; extra_env="${5:-}"
  td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"
  pf="$td/.payload.json"
  printf '%s' "$payload" > "$pf"
  env CLAUDE_PROJECT_DIR="$td" $extra_env /bin/bash "$HOOKS/$gate" < "$pf" >/dev/null 2>&1
  rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
  rm -rf "$td"; report "$want" "$got" "$name"
}

P1=docs/issue-7/proposals/review.md
P2=docs/issue-7/reports/review.md
CONF=docs/issue-7/reports/conformance-review.md

LIST_OK='## Requirements
- requirement one
- requirement two
'
LIST_MISSING='## Requirements
No enumeration here, just prose describing the plan in general terms.
'
SAMPLING='## Sampling derivation

We derived the sample as follows: N=20 of 200, per stratified random draw.
'

V_OK='## R1
spec_ref: contract.md#s3
evidence: file.py:10-14
Verdict: Present
'
V_MISSING_SPEC='## R1
evidence: file.py:10-14
Verdict: Present
'
V_UNVERIFIABLE_OK='## R1
spec_ref: contract.md#s3
Verdict: Unverifiable
'

run allow phase1-list-present     traceability-gate.sh "$P1" "$LIST_OK"
run deny  phase1-list-absent      traceability-gate.sh "$P1" "$LIST_MISSING"
run allow phase1-sampling-derivation traceability-gate.sh "$P1" "$SAMPLING"
run allow phase2-verdict-ok       traceability-gate.sh "$P2" "$V_OK"
run allow phase2-conformance-name-ok traceability-gate.sh "$CONF" "$V_OK"
run deny  phase2-missing-spec-ref traceability-gate.sh "$P2" "$V_MISSING_SPEC"
run allow phase2-unverifiable-no-evidence traceability-gate.sh "$P2" "$V_UNVERIFIABLE_OK"
run allow unrelated-path          traceability-gate.sh "README.md" "$V_MISSING_SPEC"
run allow kill-switch-on-bad-write traceability-gate.sh "$P2" "$V_MISSING_SPEC" "REVIEW_TRACEABILITY_GATE_OFF=1"
run_raw deny malformed-json       traceability-gate.sh "not json at all"

printf '\n== %d passed, %d failed ==\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
