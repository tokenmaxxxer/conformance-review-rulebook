#!/usr/bin/env bash
# proposal-completeness-gate.sh, exercised as a real subprocess.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
HOOKS="$HERE/../hooks"
pass=0; fail=0
report() { if [ "$2" = "$1" ]; then pass=$((pass+1)); printf 'ok     %-34s %s\n' "$3" "$2"; else fail=$((fail+1)); printf 'FAIL   %-34s want=%s got=%s\n' "$3" "$1" "$2"; fi; }

PROP=docs/issue-7/proposals/review.md
run() { # want name gate file content
  td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"; mkdir -p "$td/docs/issue-7/proposals"
  printf '{"tool_name":"Write","tool_input":{"file_path":"%s","content":%s},"cwd":"%s"}' \
    "$4" "$(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$5")" "$td" \
    | env CLAUDE_PROJECT_DIR="$td" /bin/bash "$HOOKS/$3" >/dev/null 2>&1
  rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
  rm -rf "$td"; report "$1" "$got" "$2"
}

FULL='## Request

We want the review role to enforce a structural completeness bar on its own
phase-1 proposals, mirroring the freelunch fan-out bar (issue #39).

## Constraints

This change only touches a new self-contained plugin directory; it must not
modify review/, marketplace.json, or install.sh.

## Adopted

- Adopted the freelunch structural bar from [core freelunch plugin](docs/issue-39/proposals/conformance-review.md),
  matching the source-grounding requirement in issue #30 (a).

## Skipped

- Skipped a full citation-graph check — deliberately out of scope, left as a
  human/approver judgment call.

## How this will be judged

- `bash review-proposal-completeness/tests/proposal-completeness-gate-test.sh` passes
- the gate exits with exit code 2 on an incomplete proposal
- `tests/deny-only-check.sh` reports no permissionDecision allow'

CONTENT_NO_REQUEST="${FULL/'## Request'/'## NotRequest'}"
CONTENT_NO_CONSTRAINTS='## Request

We want the review role to enforce a structural completeness bar.

## Adopted

- Adopted the freelunch structural bar from [core freelunch plugin](docs/issue-39/proposals/conformance-review.md).

## Skipped

- Skipped a full citation-graph check — deliberately out of scope.

## How this will be judged

- `bash review-proposal-completeness/tests/proposal-completeness-gate-test.sh` passes
- the gate exits with exit code 2 on an incomplete proposal'

CONTENT_NO_SOURCED_ADOPT='## Request

We want the review role to enforce a structural completeness bar.

## Constraints

This change only touches a new self-contained plugin directory.

## Adopted

- Adopted the freelunch structural bar because it seemed like a good idea.

## Skipped

- Skipped a full citation-graph check — deliberately out of scope.

## How this will be judged

- `bash review-proposal-completeness/tests/proposal-completeness-gate-test.sh` passes
- the gate exits with exit code 2 on an incomplete proposal'

CONTENT_NO_SKIP_SPLIT='## Request

We want the review role to enforce a structural completeness bar.

## Constraints

This change only touches a new self-contained plugin directory.

## Adopted

- Adopted the freelunch structural bar from [core freelunch plugin](docs/issue-39/proposals/conformance-review.md).

## How this will be judged

- `bash review-proposal-completeness/tests/proposal-completeness-gate-test.sh` passes
- the gate exits with exit code 2 on an incomplete proposal'

CONTENT_NO_JUDGED='## Request

We want the review role to enforce a structural completeness bar.

## Constraints

This change only touches a new self-contained plugin directory.

## Adopted

- Adopted the freelunch structural bar from [core freelunch plugin](docs/issue-39/proposals/conformance-review.md).

## Skipped

- Skipped a full citation-graph check — deliberately out of scope.'

run allow full-proposal              proposal-completeness-gate.sh "$PROP" "$FULL"
run deny  missing-request            proposal-completeness-gate.sh "$PROP" "$CONTENT_NO_REQUEST"
run deny  missing-constraints        proposal-completeness-gate.sh "$PROP" "$CONTENT_NO_CONSTRAINTS"
run deny  missing-sourced-adoption   proposal-completeness-gate.sh "$PROP" "$CONTENT_NO_SOURCED_ADOPT"
run deny  missing-adopt-skip-split   proposal-completeness-gate.sh "$PROP" "$CONTENT_NO_SKIP_SPLIT"
run deny  missing-how-judged         proposal-completeness-gate.sh "$PROP" "$CONTENT_NO_JUDGED"
run allow unrelated-path             proposal-completeness-gate.sh "README.md" "$CONTENT_NO_REQUEST"

# kill switch: an incomplete proposal is allowed through when disabled.
td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"; mkdir -p "$td/docs/issue-7/proposals"
pf="$td/payload.json"
printf '{"tool_name":"Write","tool_input":{"file_path":"%s","content":%s},"cwd":"%s"}' \
  "$PROP" "$(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$CONTENT_NO_REQUEST")" "$td" >"$pf"
env CLAUDE_PROJECT_DIR="$td" REVIEW_PROPOSAL_COMPLETENESS_GATE_OFF=1 /bin/bash "$HOOKS/proposal-completeness-gate.sh" <"$pf" >/dev/null 2>&1
rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
rm -rf "$td"; report allow "$got" kill-switch-off

# malformed stdin -> deny
td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"
pf="$td/payload.json"
printf 'not json' >"$pf"
env CLAUDE_PROJECT_DIR="$td" /bin/bash "$HOOKS/proposal-completeness-gate.sh" <"$pf" >/dev/null 2>&1
rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
rm -rf "$td"; report deny "$got" malformed-stdin

# empty content -> deny
run deny empty-content proposal-completeness-gate.sh "$PROP" ""

# --- gate-house standard mandatory cases (core issue #72, via docs/issue-42) ---

run_edit() { # want name gate file base_content old new replace_all
  want="$1"; name="$2"; gate="$3"; file="$4"; base="$5"; old="$6"; new="$7"; ra="$8"
  td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"; mkdir -p "$td/$(dirname "$file")"
  printf '%s' "$base" > "$td/$file"
  pf="$td/.payload.json"
  python3 -c 'import json,sys; d={"tool_name":"Edit","tool_input":{"file_path":sys.argv[1],"old_string":sys.argv[2],"new_string":sys.argv[3],"replace_all":sys.argv[4]=="true"},"cwd":sys.argv[5]}; print(json.dumps(d))' \
    "$file" "$old" "$new" "$ra" "$td" > "$pf"
  env CLAUDE_PROJECT_DIR="$td" /bin/bash "$HOOKS/$gate" < "$pf" >/dev/null 2>&1
  rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
  rm -rf "$td"; report "$want" "$got" "$name"
}

# 1. Edit replace_all:true against a multiply-occurring old_string.
FULL_WITH_PLACEHOLDER="${FULL/'## Adopted'/'## Adopted PLACEHOLDER'}"
FULL_WITH_PLACEHOLDER="${FULL_WITH_PLACEHOLDER/'## Skipped'/'## Skipped PLACEHOLDER'}"
run_edit allow edit-replace-all-multi-occurrence proposal-completeness-gate.sh "$PROP" "$FULL_WITH_PLACEHOLDER" "PLACEHOLDER" "" true

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
run_multiedit deny multiedit-mixed-replace-all proposal-completeness-gate.sh "$PROP" "$FULL" \
  '[{"old_string":"## Request","new_string":"## NotRequest","replace_all":false},{"old_string":"## ","new_string":"## ","replace_all":true}]'

# 3. malformed/empty/non-object JSON.
td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"
printf '[1,2,3]' | env CLAUDE_PROJECT_DIR="$td" /bin/bash "$HOOKS/proposal-completeness-gate.sh" >/dev/null 2>&1
rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
rm -rf "$td"; report deny "$got" non-object-json

# 4. Kill-switch set to an unrecognized value — gate must stay ACTIVE.
td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"; mkdir -p "$td/docs/issue-7/proposals"
pf="$td/payload.json"
printf '{"tool_name":"Write","tool_input":{"file_path":"%s","content":%s},"cwd":"%s"}' \
  "$PROP" "$(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$CONTENT_NO_REQUEST")" "$td" >"$pf"
env CLAUDE_PROJECT_DIR="$td" REVIEW_PROPOSAL_COMPLETENESS_GATE_OFF=banana /bin/bash "$HOOKS/proposal-completeness-gate.sh" <"$pf" >/dev/null 2>&1
rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
rm -rf "$td"; report deny "$got" kill-switch-unrecognized-value-stays-active

# 5. Absolute + ./-prefixed file_path matching the same scope as relative.
run_variant_path() { # want name gate file_variant content
  want="$1"; name="$2"; gate="$3"; file="$4"; content="$5"
  td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"; mkdir -p "$td/docs/issue-7/proposals"
  path="$file"
  case "$file" in /ABS/*) path="$td/${file#/ABS/}" ;; esac
  printf '{"tool_name":"Write","tool_input":{"file_path":"%s","content":%s},"cwd":"%s"}' \
    "$path" "$(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$content")" "$td" \
    | env CLAUDE_PROJECT_DIR="$td" /bin/bash "$HOOKS/$gate" >/dev/null 2>&1
  rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
  rm -rf "$td"; report "$want" "$got" "$name"
}
run_variant_path deny absolute-path-same-scope     proposal-completeness-gate.sh "/ABS/$PROP" "$CONTENT_NO_REQUEST"
run_variant_path deny dot-prefixed-path-same-scope proposal-completeness-gate.sh "./$PROP"   "$CONTENT_NO_REQUEST"

# 6. A Bash-tool file write reaching the same target a Write call would hit.
run_bash_write() { # want name gate command
  want="$1"; name="$2"; gate="$3"; cmd="$4"
  td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"; mkdir -p "$td/docs/issue-7/proposals"
  printf '{"tool_name":"Bash","tool_input":{"command":%s},"cwd":"%s"}' \
    "$(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$cmd")" "$td" \
    | env CLAUDE_PROJECT_DIR="$td" /bin/bash "$HOOKS/$gate" >/dev/null 2>&1
  rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
  rm -rf "$td"; report "$want" "$got" "$name"
}
run_bash_write deny bash-write-same-target-as-write proposal-completeness-gate.sh "echo '## Request' >> $PROP"
run_bash_write allow bash-write-unrelated-target    proposal-completeness-gate.sh "echo hi >> README.md"

# --- semantic-upgrade case (issue #42: same-sentence/adjacent-item, not
# same-paragraph) ---
CONTENT_ADOPT_UNRELATED_SOURCE_SAME_PARAGRAPH='## Request

We want the review role to enforce a structural completeness bar.

## Constraints

This change only touches a new self-contained plugin directory.

## Adopted

- We adopted this approach because it felt right. See also
  [an unrelated changelog entry](docs/issue-1/reports/unrelated.md) mentioned
  here only in passing, with no other connection at all.

## Skipped

- Skipped a full citation-graph check — deliberately out of scope.

## How this will be judged

- `bash review-proposal-completeness/tests/proposal-completeness-gate-test.sh` passes
- the gate exits with exit code 2 on an incomplete proposal'
run deny adopt-and-source-same-paragraph-not-adjacent-now-denies proposal-completeness-gate.sh "$PROP" "$CONTENT_ADOPT_UNRELATED_SOURCE_SAME_PARAGRAPH"

printf '\n== %d passed, %d failed ==\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
