#!/usr/bin/env bash
# Gate tests for review-cycle/hooks/state-gate.sh.
#
# Covers, per docs/proposals/2026-07-29-same-state-gate-and-state-file-policy.md:
#  (a) a same-state write to the state file on a state with NO self-loop
#      row must be DENIED.
#  (b) a same-state write to the state file on a state that DOES have a
#      self-loop row (auditing|auditing, draft-reported|draft-reported)
#      must be ALLOWED.
#  (c) a normal table-legal transition must be ALLOWED.
#  (d) a transition absent from the table must be DENIED.
#  (e) a Bash-shaped write whose target resolves to the state file is
#      judged the same as the Write-shaped one.
#  (f) malformed hook JSON is DENIED with visible output, never a silent
#      exit 0.
set -uo pipefail

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
GATE="$HOOK_DIR/state-gate.sh"

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

pass=0
fail=0

run_gate() {
  # $1 = root dir, $2 = payload json
  CLAUDE_PROJECT_DIR="$1" bash "$GATE" <<<"$2"
}

expect_deny() {
  local name="$1" root="$2" payload="$3"
  local out rc
  out="$(run_gate "$root" "$payload" 2>&1)"
  rc=$?
  if [ "$rc" -eq 0 ]; then
    echo "FAIL: $name — expected deny (non-zero exit), got exit 0. Output: $out"
    fail=$((fail+1))
  else
    echo "PASS: $name (exit $rc)"
    pass=$((pass+1))
  fi
}

expect_allow() {
  local name="$1" root="$2" payload="$3"
  local out rc
  out="$(run_gate "$root" "$payload" 2>&1)"
  rc=$?
  if [ "$rc" -ne 0 ]; then
    echo "FAIL: $name — expected allow (exit 0), got exit $rc. Output: $out"
    fail=$((fail+1))
  else
    echo "PASS: $name"
    pass=$((pass+1))
  fi
}

write_contract() {
  # $1 = root. Creates a present-but-minimal
  # docs/specs/role-handoff-contract.md so Rule 0 (contract-presence)
  # does not itself refuse the call — needed for tests that exercise
  # something OTHER than Rule 0, notably the §11 owned-path tests below.
  mkdir -p "$1/docs/specs"
  printf '# role-handoff-contract\n\n## 11. NEVER-OVERWRITE\n\nA role owns exactly its own docs/reports/records/<subject>/<role>.md slot.\n' > "$1/docs/specs/role-handoff-contract.md"
}

new_root() {
  local d
  d="$(mktemp -d -p "$WORKDIR")"
  # Rule 0 needs the contract in the repo under test. Before the gate
  # anchored on the project being worked in, this passed because root
  # resolved to the RULEBOOK repo, which carries one — the fixtures were
  # never exercising Rule 0 against themselves.
  write_contract "$d"
  echo "$d"
}

write_state() {
  # $1 = root, $2 = status
  printf 'status: %s\n' "$2" > "$1/review-record.md"
}

# --- (a) same-state write, no self-loop row (idle | idle) -> DENY --------
root="$(new_root)"
write_state "$root" "idle"
payload=$(cat <<JSON
{"tool_name":"Write","tool_input":{"file_path":"$root/review-record.md","content":"status: idle\n"}}
JSON
)
expect_deny "(a) same-state idle->idle, no self-loop row" "$root" "$payload"

# --- (b) same-state write, HAS self-loop row (auditing | auditing) -> ALLOW
root="$(new_root)"
write_state "$root" "auditing"
payload=$(cat <<JSON
{"tool_name":"Write","tool_input":{"file_path":"$root/review-record.md","content":"status: auditing\nnote: evidence requested\n"}}
JSON
)
expect_allow "(b) same-state auditing->auditing, has self-loop row" "$root" "$payload"

root="$(new_root)"
write_state "$root" "draft-reported"
payload=$(cat <<JSON
{"tool_name":"Write","tool_input":{"file_path":"$root/review-record.md","content":"status: draft-reported\nnote: dispute logged\n"}}
JSON
)
expect_allow "(b) same-state draft-reported->draft-reported, has self-loop row" "$root" "$payload"

# --- (c) normal table-legal transition -> ALLOW ---------------------------
root="$(new_root)"
write_state "$root" "scoped"
payload=$(cat <<JSON
{"tool_name":"Write","tool_input":{"file_path":"$root/review-record.md","content":"status: auditing\n"}}
JSON
)
expect_allow "(c) legal transition scoped->auditing" "$root" "$payload"

# --- (d) transition absent from the table -> DENY -------------------------
root="$(new_root)"
write_state "$root" "idle"
payload=$(cat <<JSON
{"tool_name":"Write","tool_input":{"file_path":"$root/review-record.md","content":"status: reported\n"}}
JSON
)
expect_deny "(d) illegal transition idle->reported" "$root" "$payload"

# --- (e) Bash-shaped write resolving to the state file, judged the same --
# (e1) Bash write reaching a state with a legal outgoing transition -> ALLOW
root="$(new_root)"
write_state "$root" "scoped"
payload=$(cat <<JSON
{"tool_name":"Bash","tool_input":{"command":"printf 'status: auditing\\n' > $root/review-record.md"}}
JSON
)
expect_allow "(e1) Bash write reaching state file, legal outgoing transition exists" "$root" "$payload"

# (e2) Bash write reaching a state with NO legal outgoing transition -> DENY
root="$(new_root)"
write_state "$root" "reported"
payload=$(cat <<JSON
{"tool_name":"Bash","tool_input":{"command":"printf 'status: idle\\n' > $root/review-record.md"}}
JSON
)
expect_deny "(e2) Bash write reaching state file, no legal outgoing transition (terminal state)" "$root" "$payload"

# --- (f) malformed hook JSON -> DENY, visible output, never silent -------
root="$(new_root)"
out_f="$(run_gate "$root" '{not valid json' 2>&1)"
rc_f=$?
if [ "$rc_f" -eq 0 ]; then
  echo "FAIL: (f) malformed JSON — expected deny, got exit 0. Output: $out_f"
  fail=$((fail+1))
elif [ -z "$out_f" ]; then
  echo "FAIL: (f) malformed JSON — denied (exit $rc_f) but produced no visible output"
  fail=$((fail+1))
else
  echo "PASS: (f) malformed JSON denied with visible output (exit $rc_f)"
  pass=$((pass+1))
fi

# --- (g) existing state file with value "(none)" -> DENY, rules-not-loaded
root="$(new_root)"
write_state "$root" "(none)"
payload=$(cat <<JSON
{"tool_name":"Write","tool_input":{"file_path":"$root/review-record.md","content":"status: idle\n"}}
JSON
)
out_g="$(run_gate "$root" "$payload" 2>&1)"
rc_g=$?
if [ "$rc_g" -eq 0 ]; then
  echo "FAIL: (g) existing status:(none) — expected deny, got exit 0. Output: $out_g"
  fail=$((fail+1))
elif ! printf '%s' "$out_g" | grep -q "rules could not be loaded"; then
  echo "FAIL: (g) existing status:(none) — denied but wrong message. Output: $out_g"
  fail=$((fail+1))
else
  echo "PASS: (g) existing status:(none) denied with rules-could-not-be-loaded message"
  pass=$((pass+1))
fi

# --- (h) existing state file with empty status value -> DENY, rules-not-loaded
root="$(new_root)"
printf 'status:\n' > "$root/review-record.md"
payload=$(cat <<JSON
{"tool_name":"Write","tool_input":{"file_path":"$root/review-record.md","content":"status: idle\n"}}
JSON
)
out_h="$(run_gate "$root" "$payload" 2>&1)"
rc_h=$?
if [ "$rc_h" -eq 0 ]; then
  echo "FAIL: (h) existing empty status — expected deny, got exit 0. Output: $out_h"
  fail=$((fail+1))
elif ! printf '%s' "$out_h" | grep -q "rules could not be loaded"; then
  echo "FAIL: (h) existing empty status — denied but wrong message. Output: $out_h"
  fail=$((fail+1))
else
  echo "PASS: (h) existing empty status denied with rules-could-not-be-loaded message"
  pass=$((pass+1))
fi

# --- (i) existing state file with out-of-set value -> DENY, rules-not-loaded
root="$(new_root)"
write_state "$root" "totally-bogus-state"
payload=$(cat <<JSON
{"tool_name":"Write","tool_input":{"file_path":"$root/review-record.md","content":"status: idle\n"}}
JSON
)
out_i="$(run_gate "$root" "$payload" 2>&1)"
rc_i=$?
if [ "$rc_i" -eq 0 ]; then
  echo "FAIL: (i) existing out-of-set status — expected deny, got exit 0. Output: $out_i"
  fail=$((fail+1))
elif ! printf '%s' "$out_i" | grep -q "rules could not be loaded"; then
  echo "FAIL: (i) existing out-of-set status — denied but wrong message. Output: $out_i"
  fail=$((fail+1))
else
  echo "PASS: (i) existing out-of-set status denied with rules-could-not-be-loaded message"
  pass=$((pass+1))
fi

# --- (j) existing valid state with trailing whitespace/CRLF -> treated as
#     that valid state (normal table-legal transition allowed) ------------
root="$(new_root)"
printf 'status: scoped  \r\n' > "$root/review-record.md"
payload=$(cat <<JSON
{"tool_name":"Write","tool_input":{"file_path":"$root/review-record.md","content":"status: auditing\n"}}
JSON
)
expect_allow "(j) existing status with trailing whitespace/CRLF treated as valid state" "$root" "$payload"

# --- (k) state file genuinely absent -> (none)->X bootstrap row ALLOWED --
root="$(new_root)"
payload=$(cat <<JSON
{"tool_name":"Write","tool_input":{"file_path":"$root/review-record.md","content":"status: idle\n"}}
JSON
)
expect_allow "(k) genuinely absent state file, (none)->idle bootstrap row allowed" "$root" "$payload"

# --- (l) the gate follows the project, not its own location ---------------
# Where this hook sits on disk must not decide what it guards. Copy the whole
# hooks directory somewhere outside any project, run that copy with the
# project as cwd, and it must reach the same decision as the in-repo copy.
#
# Until 2026-07-26 root was the nearest `.git` ABOVE the hook itself. A
# rulebook loaded as a plugin from its own checkout — which is how an
# orchestrator swaps rulebooks per role — therefore guarded the rulebook's
# repo, and every write in the real project fell outside its owned paths and
# was allowed, silently, exit 0.
repo_root="$(cd "$HOOK_DIR/../.." && pwd -P)"
elsewhere="$(mktemp -d)"
cp -R "$HOOK_DIR" "$elsewhere/hooks"
payload_l='{"tool_name":"Write","tool_input":{"file_path":"review-record.md","content":"status: idle\\n"}}'
out_in="$(cd "$repo_root" && env -u CLAUDE_PROJECT_DIR bash -c 'printf "%s" "$1" | bash "$2"' _ "$payload_l" "$GATE" 2>&1)"
code_in=$?
out_out="$(cd "$repo_root" && env -u CLAUDE_PROJECT_DIR bash -c 'printf "%s" "$1" | bash "$2"' _ "$payload_l" "$elsewhere/hooks/$(basename "$GATE")" 2>&1)"
code_out=$?
rm -rf "$elsewhere"
if [ "$code_in" -eq "$code_out" ]; then
  echo "PASS: (l) a copy of the gate outside the rulebook reaches the same decision as the in-repo gate (exit $code_out)"; pass=$((pass+1))
else
  echo "FAIL: (l) the gate's own location changed its decision (in-repo exit $code_in, out-of-tree exit $code_out) — out: $out_out | in: $out_in"; fail=$((fail+1))
fi

# --- (m) §11 subject-scoped own-record write -> ALLOW ---------------------
# review writing its own docs/reports/records/<subject>/review.md slot is
# allowed, for two distinct subject values.
root="$(new_root)"
write_contract "$root"
payload=$(cat <<JSON
{"tool_name":"Write","tool_input":{"file_path":"$root/docs/reports/records/checkout-flow/review.md","content":"status: idle\n"}}
JSON
)
expect_allow "(m1) §11 own-record write, subject=checkout-flow -> allow" "$root" "$payload"

root="$(new_root)"
write_contract "$root"
payload=$(cat <<JSON
{"tool_name":"Write","tool_input":{"file_path":"$root/docs/reports/records/billing-retry/review.md","content":"status: idle\n"}}
JSON
)
expect_allow "(m2) §11 own-record write, subject=billing-retry -> allow" "$root" "$payload"

# --- (n) §11 subject-scoped foreign-record write -> DENY, cites §11 -------
# review writing another role's docs/reports/records/<subject>/<role>.md
# slot must be refused (exit 2) rather than silently allowed, for two
# distinct subject values, and the refusal must cite §11.
root="$(new_root)"
write_contract "$root"
payload=$(cat <<JSON
{"tool_name":"Write","tool_input":{"file_path":"$root/docs/reports/records/checkout-flow/product.md","content":"status: idle\n"}}
JSON
)
out_n1="$(run_gate "$root" "$payload" 2>&1)"
rc_n1=$?
if [ "$rc_n1" -eq 0 ]; then
  echo "FAIL: (n1) §11 foreign-record write, subject=checkout-flow — expected deny, got exit 0. Output: $out_n1"
  fail=$((fail+1))
elif ! printf '%s' "$out_n1" | grep -q "§11"; then
  echo "FAIL: (n1) §11 foreign-record write, subject=checkout-flow — denied but did not cite §11. Output: $out_n1"
  fail=$((fail+1))
else
  echo "PASS: (n1) §11 foreign-record write, subject=checkout-flow denied (exit $rc_n1), cites §11"
  pass=$((pass+1))
fi

root="$(new_root)"
write_contract "$root"
payload=$(cat <<JSON
{"tool_name":"Write","tool_input":{"file_path":"$root/docs/reports/records/billing-retry/qa.md","content":"status: idle\n"}}
JSON
)
out_n2="$(run_gate "$root" "$payload" 2>&1)"
rc_n2=$?
if [ "$rc_n2" -eq 0 ]; then
  echo "FAIL: (n2) §11 foreign-record write, subject=billing-retry — expected deny, got exit 0. Output: $out_n2"
  fail=$((fail+1))
elif ! printf '%s' "$out_n2" | grep -q "§11"; then
  echo "FAIL: (n2) §11 foreign-record write, subject=billing-retry — denied but did not cite §11. Output: $out_n2"
  fail=$((fail+1))
else
  echo "PASS: (n2) §11 foreign-record write, subject=billing-retry denied (exit $rc_n2), cites §11"
  pass=$((pass+1))
fi

# --- (o) write-detection bypass fix (docs/proposals/2026-07-26-fix-state-gate-writeop-bypass.md)
# Root resolution for this gate is always anchored to the hook's own git
# root (never CLAUDE_PROJECT_DIR), so these three cases operate directly
# against THIS repo's checkout with a scratch subject, cleaned up on exit.
REPO_ROOT="$(cd "$HOOK_DIR/../.." && pwd -P)"
SCRATCH_SUBJECT="gatefix-bypass-test"
SCRATCH_DIR="$REPO_ROOT/docs/reports/records/$SCRATCH_SUBJECT"
cleanup_scratch() { rm -rf "$SCRATCH_DIR"; }
trap 'cleanup_scratch; rm -rf "$WORKDIR"' EXIT
cleanup_scratch
mkdir -p "$SCRATCH_DIR"

payload_o1=$(cat <<JSON
{"tool_name":"Bash","tool_input":{"command":"python3 -c \"open('docs/reports/records/$SCRATCH_SUBJECT/coding.md','w').write('x')\""}}
JSON
)
out_o1="$(cd "$REPO_ROOT" && printf '%s' "$payload_o1" | bash "$GATE" 2>&1)"
rc_o1=$?
if [ "$rc_o1" -ne 0 ]; then
  echo "PASS: (o1) Bash python3-open write to a foreign role's record is refused (exit $rc_o1)"
  pass=$((pass+1))
else
  echo "FAIL: (o1) Bash python3-open write to a foreign role's record was ALLOWED (exit 0): $out_o1"
  fail=$((fail+1))
fi

payload_o2=$(cat <<JSON
{"tool_name":"Write","tool_input":{"file_path":"docs/reports/records/$SCRATCH_SUBJECT/review.md","content":"status: idle\n"}}
JSON
)
out_o2="$(cd "$REPO_ROOT" && printf '%s' "$payload_o2" | bash "$GATE" 2>&1)"
rc_o2=$?
if [ "$rc_o2" -eq 0 ]; then
  echo "PASS: (o2) legal write to review's own record slot is allowed (exit 0)"
  pass=$((pass+1))
else
  echo "FAIL: (o2) legal write to review's own record slot was DENIED (exit $rc_o2): $out_o2"
  fail=$((fail+1))
fi

payload_o3=$(cat <<JSON
{"tool_name":"Bash","tool_input":{"command":"python3 -c \"import sys; open('docs/reports/records/' + sys.argv[1] + '/coding.md','w').write('x')\" $SCRATCH_SUBJECT"}}
JSON
)
out_o3="$(cd "$REPO_ROOT" && printf '%s' "$payload_o3" | bash "$GATE" 2>&1)"
rc_o3=$?
if [ "$rc_o3" -ne 0 ]; then
  echo "PASS: (o3) Bash python3-open write with indeterminate target in the owned record tree is refused (exit $rc_o3)"
  pass=$((pass+1))
else
  echo "FAIL: (o3) Bash python3-open write with indeterminate target in the owned record tree was ALLOWED (exit 0): $out_o3"
  fail=$((fail+1))
fi


# --- path-reference default-deny (docs/proposals/2026-07-26-gate-nested-shell-default-deny.md)
# Each of these targets a FOREIGN role's record slot via a write idiom this
# gate never enumerated by name (write_text/write_bytes/os.write) or via a
# nested shell / command substitution wrapper around a plain write. The
# rule is not "match this idiom" — it is "default-deny any reference into
# the owned record tree this gate cannot prove is read-only" — so all five
# must be refused regardless of the specific idiom used.
payload_p1=$(cat <<JSON
{"tool_name":"Bash","tool_input":{"command":"python3 -c \"import pathlib; pathlib.Path('docs/reports/records/$SCRATCH_SUBJECT/coding.md').write_text('x')\""}}
JSON
)
out_p1="$(cd "$REPO_ROOT" && printf '%s' "$payload_p1" | bash "$GATE" 2>&1)"
rc_p1=$?
if [ "$rc_p1" -ne 0 ]; then
  echo "PASS: (p1) Bash pathlib.Path(...).write_text(...) write to a foreign role's record is refused (exit $rc_p1)"
  pass=$((pass+1))
else
  echo "FAIL: (p1) Bash pathlib.Path(...).write_text(...) write to a foreign role's record was ALLOWED (exit 0): $out_p1"
  fail=$((fail+1))
fi

payload_p2=$(cat <<JSON
{"tool_name":"Bash","tool_input":{"command":"python3 -c \"import pathlib; pathlib.Path('docs/reports/records/$SCRATCH_SUBJECT/coding.md').write_bytes(b'x')\""}}
JSON
)
out_p2="$(cd "$REPO_ROOT" && printf '%s' "$payload_p2" | bash "$GATE" 2>&1)"
rc_p2=$?
if [ "$rc_p2" -ne 0 ]; then
  echo "PASS: (p2) Bash pathlib.Path(...).write_bytes(...) write to a foreign role's record is refused (exit $rc_p2)"
  pass=$((pass+1))
else
  echo "FAIL: (p2) Bash pathlib.Path(...).write_bytes(...) write to a foreign role's record was ALLOWED (exit 0): $out_p2"
  fail=$((fail+1))
fi

payload_p3=$(cat <<JSON
{"tool_name":"Bash","tool_input":{"command":"python3 -c \"import os; fd = os.open('docs/reports/records/$SCRATCH_SUBJECT/coding.md', os.O_WRONLY | os.O_CREAT); os.write(fd, b'x')\""}}
JSON
)
out_p3="$(cd "$REPO_ROOT" && printf '%s' "$payload_p3" | bash "$GATE" 2>&1)"
rc_p3=$?
if [ "$rc_p3" -ne 0 ]; then
  echo "PASS: (p3) Bash os.write(...) write to a foreign role's record is refused (exit $rc_p3)"
  pass=$((pass+1))
else
  echo "FAIL: (p3) Bash os.write(...) write to a foreign role's record was ALLOWED (exit 0): $out_p3"
  fail=$((fail+1))
fi

payload_p4=$(cat <<JSON
{"tool_name":"Bash","tool_input":{"command":"sh -c \"echo x > docs/reports/records/$SCRATCH_SUBJECT/coding.md\""}}
JSON
)
out_p4="$(cd "$REPO_ROOT" && printf '%s' "$payload_p4" | bash "$GATE" 2>&1)"
rc_p4=$?
if [ "$rc_p4" -ne 0 ]; then
  echo "PASS: (p4) sh -c-wrapped write to a foreign role's record is refused (exit $rc_p4)"
  pass=$((pass+1))
else
  echo "FAIL: (p4) sh -c-wrapped write to a foreign role's record was ALLOWED (exit 0): $out_p4"
  fail=$((fail+1))
fi

payload_p5=$(cat <<JSON
{"tool_name":"Bash","tool_input":{"command":"echo x > \$(echo docs/reports/records/$SCRATCH_SUBJECT/coding.md)"}}
JSON
)
out_p5="$(cd "$REPO_ROOT" && printf '%s' "$payload_p5" | bash "$GATE" 2>&1)"
rc_p5=$?
if [ "$rc_p5" -ne 0 ]; then
  echo "PASS: (p5) command-substitution-wrapped write to a foreign role's record is refused (exit $rc_p5)"
  pass=$((pass+1))
else
  echo "FAIL: (p5) command-substitution-wrapped write to a foreign role's record was ALLOWED (exit 0): $out_p5"
  fail=$((fail+1))
fi

payload_p6=$(cat <<JSON
{"tool_name":"Bash","tool_input":{"command":"printf 'status: idle\\n' > docs/reports/records/$SCRATCH_SUBJECT/review.md"}}
JSON
)
out_p6="$(cd "$REPO_ROOT" && printf '%s' "$payload_p6" | bash "$GATE" 2>&1)"
rc_p6=$?
if [ "$rc_p6" -eq 0 ]; then
  echo "PASS: (p6) plain own-record Bash redirection at a legal state transition is still allowed (exit 0)"
  pass=$((pass+1))
else
  echo "FAIL: (p6) plain own-record Bash redirection at a legal state transition was DENIED (exit $rc_p6): $out_p6"
  fail=$((fail+1))
fi

cleanup_scratch

echo
echo "== $pass passed, $fail failed =="
[ "$fail" -eq 0 ]
