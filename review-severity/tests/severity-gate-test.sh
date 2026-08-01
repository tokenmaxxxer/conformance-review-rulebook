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

SEV_DOUBLE=$'severity: PLACEHOLDER\nsome text\nseverity: PLACEHOLDER\n'
# 1. Edit replace_all:true against a multiply-occurring old_string.
run_edit deny edit-replace-all-multi-occurrence severity-gate.sh "$REC" "$SEV_DOUBLE" "PLACEHOLDER" "7.5" true

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
run_multiedit deny multiedit-mixed-replace-all severity-gate.sh "$REC" "$SEV_DOUBLE" \
  '[{"old_string":"severity: PLACEHOLDER\nsome text","new_string":"severity: High\nsome text","replace_all":false},{"old_string":"severity: PLACEHOLDER","new_string":"severity: 7.5","replace_all":true}]'

# 3. malformed/empty/non-object JSON.
td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"
printf '' | env CLAUDE_PROJECT_DIR="$td" /bin/bash "$HOOKS/severity-gate.sh" >/dev/null 2>&1
rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
rm -rf "$td"; report deny "$got" empty-payload

td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"
printf '[1,2,3]' | env CLAUDE_PROJECT_DIR="$td" /bin/bash "$HOOKS/severity-gate.sh" >/dev/null 2>&1
rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
rm -rf "$td"; report deny "$got" non-object-json

# 4. Kill-switch set to an unrecognized value — gate must stay ACTIVE.
run deny kill-switch-unrecognized-value-stays-active severity-gate.sh "$REC" $'severity: 7.5\n' env REVIEW_SEVERITY_GATE_OFF=banana

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
run_variant_path deny absolute-path-same-scope     severity-gate.sh "/ABS/$REC" $'severity: 7.5\n'
run_variant_path deny dot-prefixed-path-same-scope severity-gate.sh "./$REC"   $'severity: 7.5\n'

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
run_bash_write deny bash-write-same-target-as-write severity-gate.sh "echo 'severity: 7.5' >> $REC"
run_bash_write allow bash-write-unrelated-target    severity-gate.sh "echo hi >> README.md"

# 7. missing-core -> guarded source must deny, not allow (issue-75/issue-45).
td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"; mkdir -p "$td/docs/issue-7/reports"
printf '{"tool_name":"Write","tool_input":{"file_path":"%s","content":"severity: 7.5\\n"},"cwd":"%s"}' "$REC" "$td" \
  | env CLAUDE_PROJECT_DIR="$td" CLAUDE_PLUGIN_ROOT_CORE="$td/no-such-core" /bin/bash "$HOOKS/severity-gate.sh" >/dev/null 2>&1
rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
rm -rf "$td"; report deny "$got" missing-core

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
run_notebookedit deny  notebookedit-numeric-severity severity-gate.sh "$REC" $'severity: 7.5\n' replace
run_notebookedit allow notebookedit-table-severity   severity-gate.sh "$REC" $'severity: High\n' replace

printf '\n== %d passed, %d failed ==\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
