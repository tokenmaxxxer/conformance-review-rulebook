#!/usr/bin/env bash
# PreToolUse(Bash matching 'git commit') sibling gate for the `review` role
# — §21 handbook half. If the staged changed-file set (what this commit will
# land) introduces or changes an OPERATIONAL SURFACE (a dependency manifest,
# Dockerfile, *.env.example, a migration, or a run/setup/deploy workflow
# script) AND the same staged set does NOT also touch a
# docs/handbooks/<component>.md, refuse the commit.
#
# Only fires on a `git commit` Bash invocation. Reads the whole changed-file
# set via `git diff --cached --name-only`, which is why this is a commit-time
# gate rather than a per-Write gate.
#
# FAILS CLOSED: unparseable payload, indeterminate root, or an unreadable
# staged set on a commit that is otherwise in scope all DENY (exit 2).
# Kill switch: export REVIEW_CYCLE_DISABLE=1
set -euo pipefail

case "${REVIEW_CYCLE_DISABLE:-}" in
  ""|0|false|no|off) ;;
  *) exit 0 ;;
esac

if ! command -v python3 >/dev/null 2>&1; then
  echo "review-cycle: refused — handbook-trigger-gate.sh requires python3, which is not on PATH; denying rather than allowing an uninspectable commit." >&2
  exit 2
fi

payload="$(cat 2>/dev/null || true)"
if [ -z "$payload" ]; then
  echo "review-cycle: refused — handbook-trigger-gate.sh got no readable payload on stdin; denying rather than allowing an uninspectable commit." >&2
  exit 2
fi

REVIEW_PAYLOAD="$payload" python3 <<'PY'
import json, os, posixpath, re, sys, subprocess

def deny(msg):
    sys.stderr.write("review-cycle: refused — " + msg + "\n")
    sys.exit(2)

def allow():
    sys.exit(0)

try:
    event = json.loads(os.environ.get("REVIEW_PAYLOAD", ""))
except ValueError:
    deny("handbook-trigger-gate.sh: payload is not valid JSON; cannot judge a commit it cannot parse.")
if not isinstance(event, dict):
    deny("handbook-trigger-gate.sh: payload is not a JSON object; cannot judge a commit it cannot parse.")

if event.get("tool_name") != "Bash":
    allow()
tool_input = event.get("tool_input")
if not isinstance(tool_input, dict):
    deny("handbook-trigger-gate.sh: Bash tool_input missing or not an object; denying rather than allowing an uninspectable commit.")
command = tool_input.get("command")
if not isinstance(command, str) or not command:
    deny("handbook-trigger-gate.sh: Bash command missing; denying rather than allowing an uninspectable commit.")

# Only a git commit invocation is in scope.
if not re.search(r"\bgit\b(?:\s+-[^\s]+|\s+--[^\s]+(?:=\S+)?)*\s+commit\b", command):
    allow()

def plausible(r):
    return bool(r) and os.path.isdir(r) and (os.path.exists(os.path.join(r, ".git")) or os.path.isfile(os.path.join(r, "docs/specs/role-handoff-contract.md")))

cpd = os.environ.get("CLAUDE_PROJECT_DIR")
root = None
if cpd and plausible(cpd):
    root = cpd
if root is None:
    try:
        top = subprocess.run(["git", "-C", os.getcwd(), "rev-parse", "--show-toplevel"],
                             capture_output=True, text=True)
        if top.returncode == 0 and top.stdout.strip():
            root = top.stdout.strip()
    except Exception:
        root = None
if root is None:
    deny("handbook-trigger-gate.sh: no git project root could be determined for the commit; denying rather than allowing an indeterminate-root commit.")

try:
    diff = subprocess.run(["git", "-C", root, "diff", "--cached", "--name-only"],
                          capture_output=True, text=True)
except Exception:
    deny("handbook-trigger-gate.sh: could not run git diff --cached to read the staged file set; denying rather than allowing an uninspectable commit.")
if diff.returncode != 0:
    deny("handbook-trigger-gate.sh: git diff --cached failed (%s); denying rather than allowing an uninspectable commit."
         % (diff.stderr.strip() or "unknown error"))

files = [f for f in diff.stdout.splitlines() if f.strip()]
if not files:
    # Nothing staged: this gate has no changed-file set to judge. Allow —
    # other gates / git itself will handle an empty commit.
    allow()

MANIFESTS = re.compile(
    r'(^|/)(package\.json|pyproject\.toml|setup\.py|setup\.cfg|requirements[^/]*\.txt|'
    r'Pipfile|poetry\.lock|package-lock\.json|yarn\.lock|go\.mod|go\.sum|Cargo\.toml|'
    r'Gemfile|pom\.xml|build\.gradle|Dockerfile|docker-compose[^/]*\.ya?ml)$', re.I)
ENVEX = re.compile(r'(^|/)[^/]*\.env(\.example|\.sample|\.template)?$', re.I)
MIGRATIONS = re.compile(r'(^|/)(migrations?|migrate|alembic|db/migrate)/', re.I)
WORKFLOWS = re.compile(r'(^|/)(\.github/workflows/|\.gitlab-ci\.yml$|deploy|Makefile$|'
                       r'scripts?/(setup|install|run|deploy|start)[^/]*$)', re.I)

def is_op_surface(f):
    return bool(MANIFESTS.search(f) or ENVEX.search(f) or MIGRATIONS.search(f) or WORKFLOWS.search(f))

op = [f for f in files if is_op_surface(f)]
touches_handbook = any(re.match(r'docs/handbooks/.+\.md$', f) for f in files)

if op and not touches_handbook:
    deny("handbook-trigger-gate.sh: this commit changes operational surface (%s) but does not touch "
         "any docs/handbooks/<component>.md. Per contract §21, the surface-changer must create or "
         "update the component's handbook in the same unit of work (same-turn-sync)."
         % ", ".join(op[:5]))
allow()
PY
exit $?
