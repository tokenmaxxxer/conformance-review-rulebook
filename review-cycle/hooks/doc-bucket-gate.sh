#!/usr/bin/env bash
# PreToolUse(Write|Edit|MultiEdit|NotebookEdit) sibling gate for the `review`
# role — §21 bucket half. Refuses any write under docs/ that would land
# outside the six doctrine buckets. Replicates coding's placement-gate.sh
# shape as an additive sibling; never edits state-gate.sh.
#
# FAILS CLOSED: missing python3, unparseable payload, non-dict event/
# tool_input, or missing path all DENY (exit 2). Only a genuinely-determined
# out-of-scope (outside repo) or in-bucket write allows.
#
# Kill switch: export REVIEW_CYCLE_DISABLE=1
set -euo pipefail

case "${REVIEW_CYCLE_DISABLE:-}" in
  ""|0|false|no|off) ;;
  *) exit 0 ;;
esac

if ! command -v python3 >/dev/null 2>&1; then
  echo "review-cycle: refused — doc-bucket-gate.sh requires python3, which is not on PATH; denying rather than guessing." >&2
  exit 2
fi

payload="$(cat 2>/dev/null || true)"
if [ -z "$payload" ]; then
  echo "review-cycle: refused — doc-bucket-gate.sh got no readable payload on stdin; denying rather than allowing an uninspectable write." >&2
  exit 2
fi

set +e
REVIEW_PAYLOAD="$payload" python3 <<'PY'
import json, os, posixpath, sys, subprocess

BUCKETS = ("decisions", "handbooks", "reports", "specs", "proposals", "_assets")
SKIP_DIRS = ("node_modules", "vendor", "dist", "build", "target", "out",
             "venv", ".venv", "site-packages", "coverage")

import os as _fc_os
def _fc_excepthook(_t, _e, _tb):
    if issubclass(_t, SystemExit):
        sys.__excepthook__(_t, _e, _tb); return
    try:
        sys.stderr.write("review-cycle: refused \u2014 doc-bucket-gate.sh: fail-closed: internal error: %r\n" % (_e,))
        sys.stderr.flush()
    except Exception:
        pass
    _fc_os._exit(2)
sys.excepthook = _fc_excepthook
def allow():
    sys.exit(0)

def deny(msg):
    sys.stderr.write("review-cycle: refused — " + msg + "\n")
    sys.exit(2)

try:
    event = json.loads(os.environ.get("REVIEW_PAYLOAD", ""))
except ValueError:
    deny("doc-bucket-gate.sh: payload is not valid JSON; cannot judge a write it cannot parse.")
if not isinstance(event, dict):
    deny("doc-bucket-gate.sh: payload is not a JSON object; cannot judge a write it cannot parse.")

tool = event.get("tool_name")
if tool not in ("Write", "Edit", "MultiEdit", "NotebookEdit"):
    allow()

tool_input = event.get("tool_input")
if not isinstance(tool_input, dict):
    deny("doc-bucket-gate.sh: tool_input missing or not an object on a %s call; denying rather than allowing an uninspectable write." % tool)

path = tool_input.get("file_path") or tool_input.get("notebook_path")
if not isinstance(path, str) or not path:
    deny("doc-bucket-gate.sh: no usable file_path/notebook_path; denying rather than allowing an unidentifiable write.")

def plausible(r):
    return bool(r) and os.path.isdir(r) and (os.path.exists(os.path.join(r, ".git")) or os.path.isfile(os.path.join(r, "docs/specs/role-handoff-contract.md")))

normalized = path.replace("\\", "/")
cpd = os.environ.get("CLAUDE_PROJECT_DIR")
root = None
if cpd and plausible(cpd):
    root = cpd.replace("\\", "/")
if root is None:
    base = normalized if posixpath.isabs(normalized) else os.getcwd()
    d = base if os.path.isdir(base) else posixpath.dirname(base)
    try:
        top = subprocess.run(["git", "-C", d, "rev-parse", "--show-toplevel"],
                             capture_output=True, text=True)
        if top.returncode == 0 and top.stdout.strip():
            root = top.stdout.strip().replace("\\", "/")
    except Exception:
        root = None
if root is None:
    deny("doc-bucket-gate.sh: no project root could be determined; denying rather than allowing an indeterminate-root write.")

absolute = posixpath.normpath(normalized if posixpath.isabs(normalized) else posixpath.join(root, normalized))
root = posixpath.normpath(root)

if absolute != root and not absolute.startswith(root + "/"):
    allow()

resolved = posixpath.normpath(os.path.realpath(absolute).replace("\\", "/"))
real_root = posixpath.normpath(os.path.realpath(root).replace("\\", "/"))
if absolute != resolved:
    if resolved != real_root and not resolved.startswith(real_root + "/"):
        allow()
    absolute, root = resolved, real_root

relative = absolute[len(root) + 1:]
segments = [s for s in relative.split("/") if s not in ("", ".")]
if not segments:
    allow()

directories, name = segments[:-1], segments[-1]

if "docs" not in directories:
    allow()

for extra in (os.environ.get("DOCTRINE_ALLOW") or "").split(","):
    extra = extra.strip().strip("/")
    if extra and (extra in directories or relative == extra or relative.startswith(extra + "/")):
        allow()

if directories[-1] == "docs" and name == "README.md":
    allow()

scaffolding = None
for i, directory in enumerate(directories):
    if directory == "docs" or "docs" not in directories[:i]:
        continue
    if directory in BUCKETS:
        allow()
    if directory in SKIP_DIRS or directory.startswith("."):
        if os.path.isdir(posixpath.join(root, *directories[:i + 1])):
            allow()
        scaffolding = "/".join(directories[:i + 1])
    break

buckets = ", ".join(b + "/" for b in BUCKETS)
if scaffolding:
    reason = ("`%s` would create `%s`, a new directory under docs/ that is not one of the six "
              "buckets." % (relative, scaffolding))
else:
    reason = ("`%s` is under docs/ but not in one of the six buckets. Every file under docs/ "
              "belongs to a bucket — images and attachments go in _assets/." % relative)
deny("doc-bucket-gate.sh: %s\nThe buckets are: %s.\nClassify by lifetime, not topic. "
     "Only docs/README.md may sit at the top of docs/; paths in DOCTRINE_ALLOW are exempt." % (reason, buckets))
PY
rc=$?
set -e
if [ "$rc" -ne 0 ] && [ "$rc" -ne 2 ]; then
  echo "review-cycle: refused -- doc-bucket-gate.sh: fail-closed: internal error (judge exited $rc; mapping non-0/2 to DENY)." >&2
  exit 2
fi
exit "$rc"
