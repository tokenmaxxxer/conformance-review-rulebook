#!/usr/bin/env bash
# --- fail-closed trap-at-top (installed before any source/set/other code) ---
# A PreToolUse gate that aborts before its verdict logic runs must still DENY:
# Claude Code treats any non-2 exit as NON-BLOCKING (fail-open). This EXIT trap
# forces exit 2 (DENY) for any exit code that is neither 0 (allow) nor 2 (deny).
# Preserves legitimate terminal exit 0 / exit 2 verdicts unchanged.
__fc(){ rc=$?; if [ "$rc" != 0 ] && [ "$rc" != 2 ]; then echo "fail-closed: gate aborted (rc=$rc)" >&2; exit 2; fi; }
trap __fc EXIT
# PreToolUse(Write|Edit|MultiEdit) sibling gate for the `review` role's
# `review-severity` plugin. On a write to a phase-2 conformance/review
# record, inspect any `severity:` field in the PROPOSED content: its value
# must be drawn from a closed severity-table vocabulary (Chromium 5-band or
# Microsoft 4-level bug-bar) rather than a DREAD-style averaged numeric
# score. Issue #30 (c) names DREAD's abandonment as the specific reason this
# table-lookup methodology, not that one, was adopted.
#
# If the proposed content carries no `severity:` field at all, this gate has
# nothing to check and allows the write — severity is optional/conditional.
#
# Kill switch: export REVIEW_SEVERITY_GATE_OFF=1
set -euo pipefail

case "${REVIEW_SEVERITY_GATE_OFF:-}" in
  ""|0|false|no|off) ;;
  *) exit 0 ;;
esac

if ! command -v python3 >/dev/null 2>&1; then
  echo "review-severity: refused — severity-gate.sh requires python3, which is not on PATH; denying rather than allowing an uninspectable write." >&2
  exit 2
fi

payload="$(cat 2>/dev/null || true)"
if [ -z "$payload" ]; then
  echo "review-severity: refused — severity-gate.sh got no readable payload on stdin; denying rather than allowing an uninspectable write." >&2
  exit 2
fi

set +e
REVIEW_PAYLOAD="$payload" python3 <<'PY'
import json, os, posixpath, re, sys, subprocess

import os as _fc_os
def _fc_excepthook(_t, _e, _tb):
    if issubclass(_t, SystemExit):
        sys.__excepthook__(_t, _e, _tb); return
    try:
        sys.stderr.write("review-severity: refused — severity-gate.sh: fail-closed: internal error: %r\n" % (_e,))
        sys.stderr.flush()
    except Exception:
        pass
    _fc_os._exit(2)
sys.excepthook = _fc_excepthook
def deny(msg):
    sys.stderr.write("review-severity: refused — " + msg + "\n")
    sys.exit(2)

def allow():
    sys.exit(0)

try:
    event = json.loads(os.environ.get("REVIEW_PAYLOAD", ""))
except ValueError:
    deny("severity-gate.sh: payload is not valid JSON; cannot judge a write it cannot parse.")
if not isinstance(event, dict):
    deny("severity-gate.sh: payload is not a JSON object; cannot judge a write it cannot parse.")

tool = event.get("tool_name")
if tool not in ("Write", "Edit", "MultiEdit"):
    allow()

tool_input = event.get("tool_input")
if not isinstance(tool_input, dict):
    deny("severity-gate.sh: tool_input missing or not an object on a %s call; denying rather than allowing an uninspectable write." % tool)

path = tool_input.get("file_path")
if not isinstance(path, str) or not path:
    deny("severity-gate.sh: no usable file_path on a %s call; denying rather than allowing an unidentifiable write." % tool)

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
    deny("severity-gate.sh: no project root could be determined; denying rather than allowing an indeterminate-root write.")

absu = posixpath.normpath(norm if posixpath.isabs(norm) else posixpath.join(root, norm))
real = posixpath.normpath(os.path.realpath(absu).replace("\\", "/"))
rel = real[len(root) + 1:] if (real == root or real.startswith(root + "/")) else None

if rel is None or not re.match(r'^docs/issue-[0-9]+/reports/(conformance-)?review\.md$', rel):
    allow()

if tool == "Write":
    content = tool_input.get("content")
elif tool == "Edit":
    content = tool_input.get("new_string")
    old = tool_input.get("old_string")
    try:
        with open(real, encoding="utf-8-sig") as fh:
            cur = fh.read(1 << 20)
        if isinstance(old, str) and isinstance(content, str) and old and old in cur:
            content = cur.replace(old, content, 1)
    except OSError:
        pass
else:
    edits = tool_input.get("edits")
    content = None
    try:
        with open(real, encoding="utf-8-sig") as fh:
            text = fh.read(1 << 20)
    except OSError:
        text = ""
    if isinstance(edits, list):
        ok = True
        for e in edits:
            if not isinstance(e, dict):
                ok = False; break
            o, n = e.get("old_string"), e.get("new_string")
            if not isinstance(o, str) or not isinstance(n, str):
                ok = False; break
            if o == "":
                text = n
            elif o in text:
                text = text.replace(o, n, 1)
            else:
                ok = False; break
        if ok:
            content = text
if not isinstance(content, str):
    deny("severity-gate.sh: could not read the attempted new content of this write to the review record; denying rather than allowing an uninspectable write.")

# Extract severity field values. Nothing to check if none present.
values = re.findall(r"^\s*severity\s*:\s*(.+?)\s*$", content, re.M)
if not values:
    allow()

CHROMIUM = re.compile(r"^(critical|high|medium|low|unknown)\b(\s*\(s[0-4]\))?$", re.I)
MSFT = re.compile(r"^(critical|important|moderate|low)\b$", re.I)
NUMERIC = re.compile(r"^\d+(\.\d+)?(/\d+(\.\d+)?)?$")

for v in values:
    val = v.strip()
    if CHROMIUM.match(val) or MSFT.match(val):
        continue
    if NUMERIC.match(val):
        deny("severity-gate.sh: severity value %r looks like a DREAD-style numeric/averaged score. "
             "Issue #30 (c) names DREAD's abandonment as the specific reason this role adopted "
             "deterministic severity-table lookup instead — cite a Chromium 5-band "
             "(Critical/High/Medium/Low/Unknown) or Microsoft 4-level bug-bar "
             "(Critical/Important/Moderate/Low) value, not an averaged score." % val)
    deny("severity-gate.sh: severity value %r is not drawn from either closed vocabulary "
         "(Chromium 5-band: Critical/High/Medium/Low/Unknown, optionally with an (S0)-(S4) suffix; "
         "or Microsoft 4-level bug-bar: Critical/Important/Moderate/Low)." % val)
allow()
PY
rc=$?
set -e
if [ "$rc" -ne 0 ] && [ "$rc" -ne 2 ]; then
  echo "review-severity: refused -- severity-gate.sh: fail-closed: internal error (judge exited $rc; mapping non-0/2 to DENY)." >&2
  exit 2
fi
exit "$rc"
