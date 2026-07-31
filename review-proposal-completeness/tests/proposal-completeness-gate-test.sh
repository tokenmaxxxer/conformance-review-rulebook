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

printf '\n== %d passed, %d failed ==\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
