#!/usr/bin/env bash
# Tests for the review-cycle procedure-enforcing gates added per
# docs/proposals/2026-07-26-implement-procedure-hooks-all-rulebooks.md.
# Each gate gets one REFUSE (crafted violation) and one PASS (compliant) case.
set -uo pipefail

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT
pass=0; fail=0

new_root() {
  local d; d="$(mktemp -d -p "$WORKDIR")"
  git init -q "$d" >/dev/null 2>&1
  git -C "$d" config user.email t@t >/dev/null 2>&1
  git -C "$d" config user.name t >/dev/null 2>&1
  mkdir -p "$d/docs/specs"
  printf '# contract\n' > "$d/docs/specs/role-handoff-contract.md"
  # provide a transition-rules.md next to the gate copies so terminal-state
  # derivation works; gates default to $HOOK_DIR/transition-rules.md.
  echo "$d"
}

run() { # $1 gate, $2 root, $3 payload
  CLAUDE_PROJECT_DIR="$2" bash "$HOOK_DIR/$1" <<<"$3"
}

expect_deny() { # name gate root payload
  local out rc; out="$(run "$2" "$3" "$4" 2>&1)"; rc=$?
  if [ "$rc" -eq 0 ]; then echo "FAIL: $1 — expected DENY, got exit 0. Out: $out"; fail=$((fail+1))
  elif [ -z "$out" ]; then echo "FAIL: $1 — denied but no visible output"; fail=$((fail+1))
  else echo "PASS: $1 (deny, exit $rc)"; pass=$((pass+1)); fi
}
expect_allow() { # name gate root payload
  local out rc; out="$(run "$2" "$3" "$4" 2>&1)"; rc=$?
  if [ "$rc" -ne 0 ]; then echo "FAIL: $1 — expected ALLOW, got exit $rc. Out: $out"; fail=$((fail+1))
  else echo "PASS: $1 (allow)"; pass=$((pass+1)); fi
}

# ---------------- path-ownership-gate (§11) ----------------
r="$(new_root)"
expect_deny "path-ownership: write to foreign product.md" "path-ownership-gate.sh" "$r" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$r/docs/reports/records/auth/product.md\",\"content\":\"x\"}}"
expect_allow "path-ownership: write to own review.md" "path-ownership-gate.sh" "$r" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$r/docs/reports/records/auth/review.md\",\"content\":\"x\"}}"

# ---------------- doc-bucket-gate (§21 bucket half) ----------------
r="$(new_root)"
expect_deny "doc-bucket: doc outside the six buckets" "doc-bucket-gate.sh" "$r" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$r/docs/random/note.md\",\"content\":\"x\"}}"
expect_allow "doc-bucket: doc inside reports/ bucket" "doc-bucket-gate.sh" "$r" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$r/docs/reports/2026-07-26-x.md\",\"content\":\"x\"}}"

# ---------------- record-fields-gate (§20) ----------------
r="$(new_root)"
OPEN_BAD='status: auditing\nsome text but no required sections\n'
expect_deny "record-fields: open record missing required sections" "record-fields-gate.sh" "$r" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$r/docs/reports/records/auth/review.md\",\"content\":\"$OPEN_BAD\"}}"
OPEN_OK='status: auditing\n## What was done\nreviewed the auth module\nupstream: 1234abc commit sha basis\n## Next steps\nfinish lens 3\n## Open-finding resolution path\nowner: review, resolution path: re-audit\n'
expect_allow "record-fields: open record with all required sections" "record-fields-gate.sh" "$r" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$r/docs/reports/records/auth/review.md\",\"content\":\"$OPEN_OK\"}}"

# ---------------- closed-checks-gate (§16) ----------------
r="$(new_root)"
BAD_SHA='status: auditing\ncode_under_review: aaaaaaa\nclosed_checks:\n  - check: lens1\n    code_sha: bbbbbbb\n'
expect_deny "closed-checks: cited sha != current sha" "closed-checks-gate.sh" "$r" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$r/docs/reports/records/auth/review.md\",\"content\":\"$BAD_SHA\"}}"
OK_SHA='status: auditing\ncode_under_review: aaaaaaa\nclosed_checks:\n  - check: lens1\n    code_sha: aaaaaaa\n'
expect_allow "closed-checks: cited sha == current sha" "closed-checks-gate.sh" "$r" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$r/docs/reports/records/auth/review.md\",\"content\":\"$OK_SHA\"}}"

# ---------------- handbook-trigger-gate (§21 handbook half) ----------------
r="$(new_root)"
printf 'flask\n' > "$r/requirements.txt"; git -C "$r" add requirements.txt >/dev/null 2>&1
expect_deny "handbook-trigger: op-surface staged, no handbook touched" "handbook-trigger-gate.sh" "$r" \
  "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"git commit -m 'add dep'\"}}"
r="$(new_root)"
printf 'flask\n' > "$r/requirements.txt"
mkdir -p "$r/docs/handbooks"; printf '# api\n' > "$r/docs/handbooks/api.md"
git -C "$r" add requirements.txt docs/handbooks/api.md >/dev/null 2>&1
expect_allow "handbook-trigger: op-surface staged, handbook also touched" "handbook-trigger-gate.sh" "$r" \
  "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"git commit -m 'add dep + handbook'\"}}"

# ---------------- trailer-gate (§13) ----------------
r="$(new_root)"
printf 'status: auditing\n' > "$r/review-record.md"
expect_deny "trailer: in-progress unit, commit without Subject/Kind" "trailer-gate.sh" "$r" \
  "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"git commit -m 'wip'\"}}"
r="$(new_root)"
printf 'status: auditing\n' > "$r/review-record.md"
expect_allow "trailer: in-progress unit, commit with Subject/Kind trailers" "trailer-gate.sh" "$r" \
  "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"git commit -m 'wip' -m 'Subject: auth' -m 'Kind: review-record'\"}}"

# ---------------- fail-closed smoke: malformed JSON denied on each gate ----
r="$(new_root)"
for g in path-ownership-gate.sh doc-bucket-gate.sh record-fields-gate.sh closed-checks-gate.sh handbook-trigger-gate.sh trailer-gate.sh; do
  out="$(run "$g" "$r" '{not json' 2>&1)"; rc=$?
  if [ "$rc" -ne 0 ] && [ -n "$out" ]; then echo "PASS: fail-closed malformed JSON — $g (exit $rc)"; pass=$((pass+1))
  else echo "FAIL: fail-closed malformed JSON — $g expected deny+output, got exit $rc out=$out"; fail=$((fail+1)); fi
done

echo "-----------------------------------------"
echo "procedure-gate tests: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
