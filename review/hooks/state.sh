#!/usr/bin/env bash
# SessionStart, informing only — never blocks or denies. Reports which phase
# the current review subject appears to be in, based on which report files
# already exist. Any failure here just skips output; it never fails closed.
set -uo pipefail

main() {
  payload="$(cat 2>/dev/null || true)"
  cwd="$(printf '%s' "$payload" | grep -o '"cwd"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed -E 's/.*:[[:space:]]*"([^"]*)"/\1/')"
  [ -n "$cwd" ] || cwd="$(pwd -P)"
  cd "$cwd" 2>/dev/null || return 0

  branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
  issue="$(printf '%s' "$branch" | grep -oE 'issue-[0-9]+' | head -1 | grep -oE '[0-9]+' || true)"
  if [ -z "$issue" ]; then
    dir="$(find docs -maxdepth 1 -type d -name 'issue-*' 2>/dev/null | sort -V | tail -1 || true)"
    issue="$(printf '%s' "$dir" | grep -oE '[0-9]+' || true)"
  fi
  [ -n "$issue" ] || return 0

  proposal="docs/issue-${issue}/proposals/review.md"
  record1="docs/issue-${issue}/reports/review.md"
  record2="docs/issue-${issue}/reports/conformance-review.md"

  if [ -f "$record1" ] || [ -f "$record2" ]; then
    context="review resume-state: issue-${issue} appears to be in phase 2 (verdicts) — live plugins: review + review-traceability (phase-2 mode) + review-record-norm + review-severity (conditional)."
  elif [ -f "$proposal" ]; then
    context="review resume-state: issue-${issue} appears to be in phase 1 (requirement extraction) — live plugins: review + review-proposal-completeness + review-traceability (phase-1 mode)."
  else
    return 0
  fi

  printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"%s"}}\n' "$context"
  return 0
}

main 2>/dev/null || true
exit 0
