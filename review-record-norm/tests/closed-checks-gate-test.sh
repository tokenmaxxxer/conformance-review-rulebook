#!/usr/bin/env bash
# Dedicated test for review-record-norm's closed-checks-gate.sh, exercised as
# a real subprocess. Mirrors tests/run-gate-tests.sh's cc-* cases plus a
# kill-switch-alias case for REVIEW_RECORD_NORM_GATE_OFF.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
HOOKS="$HERE/../hooks"
pass=0; fail=0
report() { if [ "$2" = "$1" ]; then pass=$((pass+1)); printf 'ok     %-34s %s\n' "$3" "$2"; else fail=$((fail+1)); printf 'FAIL   %-34s want=%s got=%s\n' "$3" "$1" "$2"; fi; }

REC=docs/issue-7/reports/review.md
run() { # want name gate file content [extra_env...]
  td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"; mkdir -p "$td/docs/issue-7/reports"
  pf="$td/.payload.json"
  printf '{"tool_name":"Write","tool_input":{"file_path":"%s","content":%s},"cwd":"%s"}' \
    "$4" "$(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$5")" "$td" > "$pf"
  env CLAUDE_PROJECT_DIR="$td" ${6:-} /bin/bash "$HOOKS/$3" < "$pf" >/dev/null 2>&1
  rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
  rm -rf "$td"; report "$1" "$got" "$2"
}

CC_OK='closed_checks:
  - check: input-validation
    code_sha: abc1234def
code_under_review: abc1234def'
CC_MISMATCH='closed_checks:
  - check: input-validation
    code_sha: 9999999
code_under_review: abc1234def'
CC_NOFIELD='closed_checks:
  - check: input-validation
    code_sha: abc1234def'

# --- test-env resolution (docs/specs/test-env-resolution.md, issue #551) ---
# 7. missing-core -> guarded source must deny, not allow (issue-75/issue-45).
# Runs unconditionally, in both regimes: asserts the *gate's* own
# fail-closed contract, not the test runner's environment.
td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"; mkdir -p "$td/docs/issue-7/reports"
printf '%s' "$CC_MISMATCH" > "$td/$REC"
pf="$td/.payload.json"
python3 -c 'import json,sys; d={"tool_name":"Edit","tool_input":{"file_path":sys.argv[1],"old_string":"9999999","new_string":"abc1234def","replace_all":False},"cwd":sys.argv[2]}; print(json.dumps(d))' \
  "$REC" "$td" > "$pf"
env CLAUDE_PROJECT_DIR="$td" CLAUDE_PLUGIN_ROOT_CORE="$td/no-such-core" /bin/bash "$HOOKS/closed-checks-gate.sh" < "$pf" >/dev/null 2>&1
rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
rm -rf "$td"; report deny "$got" missing-core

resolved="$(python3 "$HERE/../../tests/lib/test_env_resolve.py" "$HERE/../../core")"
rc=$?
if [ "$rc" -eq 75 ]; then
  printf '\n== %d passed, %d failed (SKIP: remaining core-dependent cases) ==\n' "$pass" "$fail"
  exit 75
fi
export CLAUDE_PLUGIN_ROOT_CORE="$resolved"

run allow cc-sha-match    closed-checks-gate.sh "$REC" "$CC_OK"
run deny  cc-sha-mismatch closed-checks-gate.sh "$REC" "$CC_MISMATCH"
run deny  cc-no-field     closed-checks-gate.sh "$REC" "$CC_NOFIELD"
run allow cc-kill-switch-alias closed-checks-gate.sh "$REC" "$CC_MISMATCH" "REVIEW_RECORD_NORM_GATE_OFF=1"

# --- gate-house standard mandatory cases (core issue #72, via docs/issue-42) ---

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

CC_DOUBLE='closed_checks:
  - check: a
    code_sha: PLACEHOLDER
  - check: b
    code_sha: PLACEHOLDER
code_under_review: abc1234def'
# 1. Edit replace_all:true against a multiply-occurring old_string — both
# citations still track code_under_review, so this must allow.
run_edit allow edit-replace-all-multi-occurrence closed-checks-gate.sh "$REC" "$CC_DOUBLE" "PLACEHOLDER" "abc1234def" true

# 2. MultiEdit with a mix of replace_all true/false edits in one call.
run_multiedit() { # want name gate file base_content edits_json
  want="$1"; name="$2"; gate="$3"; file="$4"; base="$5"; edits="$6"
  td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"; mkdir -p "$td/$(dirname "$file")"
  printf '%s' "$base" > "$td/$file"
  pf="$td/.payload.json"
  python3 -c 'import json,sys; print(json.dumps({"tool_name":"MultiEdit","tool_input":{"file_path":sys.argv[1],"edits":json.loads(sys.argv[2])},"cwd":sys.argv[3]}))' \
    "$file" "$edits" "$td" > "$pf"
  env CLAUDE_PROJECT_DIR="$td" /bin/bash "$HOOKS/$gate" < "$pf" >/dev/null 2>&1
  rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
  rm -rf "$td"; report "$want" "$got" "$name"
}
run_multiedit deny multiedit-mixed-replace-all closed-checks-gate.sh "$REC" "$CC_DOUBLE" \
  '[{"old_string":"code_sha: PLACEHOLDER\n  - check: b","new_string":"code_sha: abc1234def\n  - check: b","replace_all":false},{"old_string":"code_sha: PLACEHOLDER","new_string":"code_sha: 9999999","replace_all":true}]'

# 3. malformed/empty/non-object JSON.
td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"
printf '' | env CLAUDE_PROJECT_DIR="$td" /bin/bash "$HOOKS/closed-checks-gate.sh" >/dev/null 2>&1
rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
rm -rf "$td"; report deny "$got" empty-payload

td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"
printf '[1,2,3]' | env CLAUDE_PROJECT_DIR="$td" /bin/bash "$HOOKS/closed-checks-gate.sh" >/dev/null 2>&1
rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
rm -rf "$td"; report deny "$got" non-object-json

# 4. Kill-switch set to an unrecognized value — gate must stay ACTIVE (both
# REVIEW_CYCLE_DISABLE and its alias REVIEW_RECORD_NORM_GATE_OFF).
run deny kill-switch-unrecognized-value-stays-active closed-checks-gate.sh "$REC" "$CC_MISMATCH" "REVIEW_CYCLE_DISABLE=banana"
run deny kill-switch-alias-unrecognized-value-stays-active closed-checks-gate.sh "$REC" "$CC_MISMATCH" "REVIEW_RECORD_NORM_GATE_OFF=banana"

# 5. Absolute + ./-prefixed file_path matching the same scope as relative.
run_variant_path() { # want name gate file_variant content
  want="$1"; name="$2"; gate="$3"; file="$4"; content="$5"
  td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"; mkdir -p "$td/docs/issue-7/reports"
  path="$file"
  case "$file" in /ABS/*) path="$td/${file#/ABS/}" ;; esac
  printf '{"tool_name":"Write","tool_input":{"file_path":"%s","content":%s},"cwd":"%s"}' \
    "$path" "$(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$content")" "$td" \
    | env CLAUDE_PROJECT_DIR="$td" /bin/bash "$HOOKS/$gate" >/dev/null 2>&1
  rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
  rm -rf "$td"; report "$want" "$got" "$name"
}
run_variant_path deny absolute-path-same-scope     closed-checks-gate.sh "/ABS/$REC" "$CC_MISMATCH"
run_variant_path deny dot-prefixed-path-same-scope closed-checks-gate.sh "./$REC"   "$CC_MISMATCH"

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
run_bash_write deny bash-write-same-target-as-write closed-checks-gate.sh "echo 'code_sha: x' >> $REC"
run_bash_write allow bash-write-unrelated-target    closed-checks-gate.sh "echo hi >> README.md"

# 8. NotebookEdit reaches the same content check a Write would (issue-45 (b)).
run_notebookedit() { # want name gate file new_source edit_mode
  want="$1"; name="$2"; gate="$3"; file="$4"; src="$5"; mode="$6"
  td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"; mkdir -p "$td/docs/issue-7/reports"
  python3 -c 'import json,sys; d={"tool_name":"NotebookEdit","tool_input":{"notebook_path":sys.argv[1],"new_source":sys.argv[2],"edit_mode":sys.argv[3]},"cwd":sys.argv[4]}; print(json.dumps(d))' \
    "$file" "$src" "$mode" "$td" \
    | env CLAUDE_PROJECT_DIR="$td" /bin/bash "$HOOKS/$gate" >/dev/null 2>&1
  rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
  rm -rf "$td"; report "$want" "$got" "$name"
}
run_notebookedit deny  notebookedit-sha-mismatch closed-checks-gate.sh "$REC" "$CC_MISMATCH" replace
run_notebookedit allow notebookedit-sha-match    closed-checks-gate.sh "$REC" "$CC_OK" replace

printf '\n== %d passed, %d failed ==\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
