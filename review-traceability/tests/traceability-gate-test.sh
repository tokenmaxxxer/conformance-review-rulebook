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

# --- gate-house standard mandatory cases (core issue #72, via docs/issue-42) ---

# 1. Edit with replace_all:true against a multiply-occurring old_string.
run_edit() { # want name gate file base_content old new replace_all extra_env
  want="$1"; name="$2"; gate="$3"; file="$4"; base="$5"; old="$6"; new="$7"; ra="$8"; extra_env="${9:-}"
  td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"; mkdir -p "$td/$(dirname "$file")"
  printf '%s' "$base" > "$td/$file"
  pf="$td/.payload.json"
  python3 -c 'import json,sys; d={"tool_name":"Edit","tool_input":{"file_path":sys.argv[1],"old_string":sys.argv[2],"new_string":sys.argv[3],"replace_all":sys.argv[4]=="true"},"cwd":sys.argv[5]}; print(json.dumps(d))' \
    "$file" "$old" "$new" "$ra" "$td" > "$pf"
  env CLAUDE_PROJECT_DIR="$td" $extra_env /bin/bash "$HOOKS/$gate" < "$pf" >/dev/null 2>&1
  rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
  rm -rf "$td"; report "$want" "$got" "$name"
}

V_DOUBLE='## R1
spec_ref: contract.md#s3
evidence: file.py:10
Verdict: TBD

## R2
spec_ref: contract.md#s4
evidence: file.py:20
Verdict: TBD
'
run_edit allow edit-replace-all-multi-occurrence traceability-gate.sh "$P2" "$V_DOUBLE" "Verdict: TBD" "Verdict: Present" true

# 2. MultiEdit with a mix of replace_all true/false edits in one call.
run_multiedit() { # want name gate file base_content edits_json extra_env
  want="$1"; name="$2"; gate="$3"; file="$4"; base="$5"; edits="$6"; extra_env="${7:-}"
  td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"; mkdir -p "$td/$(dirname "$file")"
  printf '%s' "$base" > "$td/$file"
  pf="$td/.payload.json"
  python3 -c 'import json,sys; print(json.dumps({"tool_name":"MultiEdit","tool_input":{"file_path":sys.argv[1],"edits":json.loads(sys.argv[2])},"cwd":sys.argv[3]}))' \
    "$file" "$edits" "$td" > "$pf"
  env CLAUDE_PROJECT_DIR="$td" $extra_env /bin/bash "$HOOKS/$gate" < "$pf" >/dev/null 2>&1
  rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
  rm -rf "$td"; report "$want" "$got" "$name"
}

run_multiedit deny multiedit-mixed-replace-all traceability-gate.sh "$P2" "$V_DOUBLE" \
  '[{"old_string":"Verdict: TBD","new_string":"Verdict: Present","replace_all":true},{"old_string":"spec_ref: contract.md#s3","new_string":"","replace_all":false}]'

# 3. malformed/empty/non-object JSON (malformed already covered above).
run_raw deny empty-payload        traceability-gate.sh ""
run_raw deny non-object-json      traceability-gate.sh "[1,2,3]"

# 4. Kill-switch set to an unrecognized value — gate must stay ACTIVE.
run deny kill-switch-unrecognized-value-stays-active traceability-gate.sh "$P2" "$V_MISSING_SPEC" "REVIEW_TRACEABILITY_GATE_OFF=banana"

# 5. Absolute + ./-prefixed file_path matching the same scope as relative.
run_abs() { # want name gate abs_or_dot_file content
  want="$1"; name="$2"; gate="$3"; file="$4"; content="$5"
  td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"; mkdir -p "$td/docs/issue-7/reports"
  path="$file"
  case "$file" in
    /ABS/*) path="$td/${file#/ABS/}" ;;
  esac
  printf '{"tool_name":"Write","tool_input":{"file_path":"%s","content":%s},"cwd":"%s"}' \
    "$path" "$(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$content")" "$td" \
    | env CLAUDE_PROJECT_DIR="$td" /bin/bash "$HOOKS/$gate" >/dev/null 2>&1
  rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
  rm -rf "$td"; report "$want" "$got" "$name"
}
run_abs deny absolute-path-same-scope   traceability-gate.sh "/ABS/$P2" "$V_MISSING_SPEC"
run_abs deny dot-prefixed-path-same-scope traceability-gate.sh "./$P2" "$V_MISSING_SPEC"

# 6. A Bash-tool file write reaching the same target a Write call would hit.
run_bash_write() { # want name gate command
  want="$1"; name="$2"; gate="$3"; cmd="$4"
  td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"; mkdir -p "$td/docs/issue-7/reports"
  printf '{"tool_name":"Bash","tool_input":{"command":%s},"cwd":"%s"}' \
    "$(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$cmd")" "$td" \
    | env CLAUDE_PROJECT_DIR="$td" /bin/bash "$HOOKS/$gate" >/dev/null 2>&1
  rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
  rm -rf "$td"; report "$want" "$got" "$name"
}
run_bash_write deny bash-write-same-target-as-write traceability-gate.sh "echo 'Verdict: Present' >> $P2"
run_bash_write allow bash-write-unrelated-target    traceability-gate.sh "echo hi >> README.md"

# --- semantic-upgrade cases (issue #42: label/adjacency, not bare word) ---
FALSE_POSITIVE_PROSE='## Notes

This change covers a broad surface area of the code, and there is no test
data present in the fixtures directory. Neither word is a labeled verdict
field, so this must not be treated as a phase-2 verdict block.
'
run allow verdict-word-in-prose-not-a-field traceability-gate.sh "$P2" "$FALSE_POSITIVE_PROSE"

printf '\n== %d passed, %d failed ==\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
