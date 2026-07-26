#!/usr/bin/env bash
# --- fail-closed trap-at-top (installed before any source/set/other code) ---
# A PreToolUse gate that aborts before its verdict logic runs must still DENY:
# Claude Code treats any non-2 exit as NON-BLOCKING (fail-open). This EXIT trap
# forces exit 2 (DENY) for any exit code that is neither 0 (allow) nor 2 (deny).
# Preserves legitimate terminal exit 0 / exit 2 verdicts unchanged.
__fc(){ rc=$?; if [ "$rc" != 0 ] && [ "$rc" != 2 ]; then echo "fail-closed: gate aborted (rc=$rc)" >&2; exit 2; fi; }
trap __fc EXIT
# PreToolUse(Write|Edit|MultiEdit) sibling gate for the `review` role — §11.
# Refuses a Write/Edit whose resolved target falls under ANOTHER role's
# exclusive subject-scoped record slot
# (docs/reports/records/<subject>/<other-role>.md). Additive sibling to
# state-gate.sh; never edits it. Generalizes coding's scope-gate write-set
# shape to §11's static, role-permanent owned-path table.
#
# FAILS CLOSED: missing python3, unreadable/unparseable payload, missing
# tool_input, or indeterminate root all DENY (exit 2). Allow (exit 0) is
# reached only when the target is affirmatively determined to be outside any
# foreign role's owned record slot.
#
# Kill switch: export REVIEW_CYCLE_DISABLE=1
set -euo pipefail

case "${REVIEW_CYCLE_DISABLE:-}" in
  ""|0|false|no|off) ;;
  *) exit 0 ;;
esac

if ! command -v python3 >/dev/null 2>&1; then
  echo "review-cycle: refused — path-ownership-gate.sh requires python3, which is not on PATH; denying rather than allowing an uninspectable write." >&2
  exit 2
fi

payload="$(cat 2>/dev/null || true)"
if [ -z "$payload" ]; then
  echo "review-cycle: refused — path-ownership-gate.sh got no readable payload on stdin; denying rather than allowing an uninspectable write." >&2
  exit 2
fi

set +e
REVIEW_PAYLOAD="$payload" python3 <<'PY'
import json, os, posixpath, re, sys, subprocess

OWN_ROLE = "review"
RECORDS_RE = re.compile(r'^docs/reports/records/([^/]+)/([A-Za-z0-9_\-]+)\.md$')

import os as _fc_os
def _fc_excepthook(_t, _e, _tb):
    if issubclass(_t, SystemExit):
        sys.__excepthook__(_t, _e, _tb); return
    try:
        sys.stderr.write("review-cycle: refused \u2014 path-ownership-gate.sh: fail-closed: internal error: %r\n" % (_e,))
        sys.stderr.flush()
    except Exception:
        pass
    _fc_os._exit(2)
sys.excepthook = _fc_excepthook
def deny(msg):
    sys.stderr.write("review-cycle: refused — " + msg + "\n")
    sys.exit(2)

def allow():
    sys.exit(0)

try:
    event = json.loads(os.environ.get("REVIEW_PAYLOAD", ""))
except ValueError:
    deny("path-ownership-gate.sh: payload is not valid JSON; cannot judge a write it cannot parse.")
if not isinstance(event, dict):
    deny("path-ownership-gate.sh: payload is not a JSON object; cannot judge a write it cannot parse.")

tool = event.get("tool_name")
if tool not in ("Write", "Edit", "MultiEdit"):
    allow()

tool_input = event.get("tool_input")
if not isinstance(tool_input, dict):
    deny("path-ownership-gate.sh: tool_input missing or not an object on a %s call; denying rather than allowing an uninspectable write." % tool)

path = tool_input.get("file_path")
if not isinstance(path, str) or not path:
    deny("path-ownership-gate.sh: no usable file_path on a %s call; denying rather than allowing an unidentifiable write." % tool)

def plausible(r):
    return bool(r) and os.path.isdir(r) and (os.path.exists(os.path.join(r, ".git")) or os.path.isfile(os.path.join(r, "docs/specs/role-handoff-contract.md")))

norm = path.replace("\\", "/")
cpd = os.environ.get("CLAUDE_PROJECT_DIR")
root = None
if cpd and plausible(cpd):
    root = posixpath.normpath(os.path.realpath(cpd).replace("\\", "/"))
if root is None:
    base = norm if posixpath.isabs(norm) else os.getcwd()
    d = base if os.path.isdir(base) else posixpath.dirname(base)
    try:
        top = subprocess.run(["git", "-C", d, "rev-parse", "--show-toplevel"],
                             capture_output=True, text=True)
        if top.returncode == 0 and top.stdout.strip():
            root = posixpath.normpath(os.path.realpath(top.stdout.strip()).replace("\\", "/"))
    except Exception:
        root = None
if root is None:
    deny("path-ownership-gate.sh: no project root could be determined; denying rather than allowing an indeterminate-root write.")

absu = norm if posixpath.isabs(norm) else posixpath.join(root, norm)
absu = posixpath.normpath(absu)
real = posixpath.normpath(os.path.realpath(absu).replace("\\", "/"))
if real != root and not real.startswith(root + "/"):
    allow()
rel = real[len(root) + 1:]

m = RECORDS_RE.match(rel)
if not m:
    allow()
subject, record_role = m.group(1), m.group(2)
if record_role == OWN_ROLE:
    allow()
deny("path-ownership-gate.sh: path ownership conflict — '%s' is owned by role '%s' per "
     "docs/specs/role-handoff-contract.md §11 NEVER-OVERWRITE, not 'review'. Report the "
     "conflict; do not overwrite or merge into another role's record." % (rel, record_role))
PY
rc=$?
set -e
if [ "$rc" -ne 0 ] && [ "$rc" -ne 2 ]; then
  echo "review-cycle: refused -- path-ownership-gate.sh: fail-closed: internal error (judge exited $rc; mapping non-0/2 to DENY)." >&2
  exit 2
fi
exit "$rc"
