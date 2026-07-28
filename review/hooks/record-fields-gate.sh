#!/usr/bin/env bash
# --- fail-closed trap-at-top (installed before any source/set/other code) ---
# A PreToolUse gate that aborts before its verdict logic runs must still DENY:
# Claude Code treats any non-2 exit as NON-BLOCKING (fail-open). This EXIT trap
# forces exit 2 (DENY) for any exit code that is neither 0 (allow) nor 2 (deny).
# Preserves legitimate terminal exit 0 / exit 2 verdicts unchanged.
__fc(){ rc=$?; if [ "$rc" != 0 ] && [ "$rc" != 2 ]; then echo "fail-closed: gate aborted (rc=$rc)" >&2; exit 2; fi; }
trap __fc EXIT
# PreToolUse(Write|Edit|MultiEdit) sibling gate for the `review` role — §20.
# On a write targeting review's own record
# (docs/issue-<n>/reports/review.md, or the flat review-record.md),
# requires §20's minimum-content sections in the PROPOSED content:
#   always: a "what was done" section; the upstream basis (commit sha or
#           record path); the record's own current loop_state/status.
#   when the record leaves work OPEN (status not terminal): additionally a
#           next-steps backlog and an open-finding resolution path.
# "Why" (§20 item 2) is required only when a real choice was made — a
# non-mechanical property this gate deliberately does NOT heuristically
# check (per contract §14), matching state-gate.sh's stance.
#
# Terminal (work-not-open) states are those with no outgoing row in
# transition-rules.md; for review that is `reported`.
#
# FAILS CLOSED on every malformed/missing-input branch (exit 2).
# Kill switch: export REVIEW_CYCLE_DISABLE=1
set -euo pipefail

case "${REVIEW_CYCLE_DISABLE:-}" in
  ""|0|false|no|off) ;;
  *) exit 0 ;;
esac

if ! command -v python3 >/dev/null 2>&1; then
  echo "review-cycle: refused — record-fields-gate.sh requires python3, which is not on PATH; denying rather than allowing an uninspectable write." >&2
  exit 2
fi

payload="$(cat 2>/dev/null || true)"
if [ -z "$payload" ]; then
  echo "review-cycle: refused — record-fields-gate.sh got no readable payload on stdin; denying rather than allowing an uninspectable write." >&2
  exit 2
fi

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd -P)"
rules_file="${REVIEW_TRANSITION_RULES:-$HOOK_DIR/transition-rules.md}"
state_name="${REVIEW_RECORD_NAME:-review-record.md}"

set +e
REVIEW_PAYLOAD="$payload" REVIEW_RULES_FILE="$rules_file" REVIEW_STATE_NAME="$state_name" python3 <<'PY'
import json, os, posixpath, re, sys, subprocess

import os as _fc_os
def _fc_excepthook(_t, _e, _tb):
    if issubclass(_t, SystemExit):
        sys.__excepthook__(_t, _e, _tb); return
    try:
        sys.stderr.write("review-cycle: refused \u2014 record-fields-gate.sh: fail-closed: internal error: %r\n" % (_e,))
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
    deny("record-fields-gate.sh: payload is not valid JSON; cannot judge a write it cannot parse.")
if not isinstance(event, dict):
    deny("record-fields-gate.sh: payload is not a JSON object; cannot judge a write it cannot parse.")

tool = event.get("tool_name")
if tool not in ("Write", "Edit", "MultiEdit"):
    allow()

tool_input = event.get("tool_input")
if not isinstance(tool_input, dict):
    deny("record-fields-gate.sh: tool_input missing or not an object on a %s call; denying rather than allowing an uninspectable write." % tool)

path = tool_input.get("file_path")
if not isinstance(path, str) or not path:
    deny("record-fields-gate.sh: no usable file_path on a %s call; denying rather than allowing an unidentifiable write." % tool)

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
    deny("record-fields-gate.sh: no project root could be determined; denying rather than allowing an indeterminate-root write.")

absu = posixpath.normpath(norm if posixpath.isabs(norm) else posixpath.join(root, norm))
real = posixpath.normpath(os.path.realpath(absu).replace("\\", "/"))
rel = real[len(root) + 1:] if (real == root or real.startswith(root + "/")) else None

state_name = os.environ.get("REVIEW_STATE_NAME") or "review-record.md"
is_own_record = False
if rel is not None:
    if re.match(r'^docs/issue-[0-9]+/reports/review\.md$', rel):
        is_own_record = True
    elif posixpath.basename(rel) == state_name:
        is_own_record = True
if not is_own_record:
    allow()

if tool == "Write":
    content = tool_input.get("content")
elif tool == "Edit":
    content = tool_input.get("new_string")
    old = tool_input.get("old_string")
    try:
        with open(real, encoding="utf-8-sig") as fh:
            cur = fh.read(1 << 20)
        if isinstance(old, str) and isinstance(content, str):
            if old == "":
                content = content
            elif old in cur:
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
    deny("record-fields-gate.sh: could not read the attempted new content of this write to review's record; denying rather than allowing an uninspectable §20 record write.")

low = content.lower()

m = re.findall(r"^(?:status|loop_state):\s*(.*?)\s*(?:#.*)?$", content, re.M)
if len(m) != 1 or not m[0].strip():
    deny("record-fields-gate.sh: review record is missing a single parseable `status:`/`loop_state:` field (§20 item 3). Refusing.")
status = m[0].strip()

terminal = {"reported"}
work_open = status not in terminal

missing = []
def has(*pats):
    return any(re.search(p, low) for p in pats)

if not has(r"what was done", r"^\s*#+\s*done\b", r"work done", r"summary of work"):
    missing.append('"what was done"')
if not has(r"upstream", r"basis", r"commit sha", r"record path", r"rests on", r"based on"):
    missing.append('upstream basis (commit sha or record path)')
if work_open:
    if not has(r"next steps", r"next-steps", r"backlog", r"what.s next"):
        missing.append('next-steps backlog (required while work is open)')
    if not has(r"resolution path", r"resolution owner", r"owns resolving", r"open finding", r"open-finding", r"finding resolution"):
        missing.append('open-finding resolution path (required while work is open)')

VERDICTS = {"present", "surface", "absent", "incorrect", "unverifiable"}
for vm in re.finditer(r"^\s*verdict:\s*(\S+)\s*$", content, re.M):
    v = vm.group(1).strip().lower()
    if v not in VERDICTS:
        deny("record-fields-gate.sh: verdict '%s' is not in the sanctioned vocabulary "
             "(Present|Surface|Absent|Incorrect|Unverifiable). One verdict per requirement, "
             "from exactly this set." % vm.group(1))
if re.search(r"^\s*verdict:\s*incorrect\s*$", content, re.M | re.I) and \
   not re.search(r"^\s*spec_vs_built\s*:", content, re.M):
    deny("record-fields-gate.sh: a verdict of Incorrect requires a spec_vs_built field "
         "stating what the spec asked versus what was built (contract s2 finding schema).")

if missing:
    deny("record-fields-gate.sh: review record (status: %s) is missing required section(s): %s. "
         "Per contract §20 every role record must state what was done and the concrete upstream "
         "basis; open work additionally requires a next-steps backlog and an open-finding "
         "resolution path." % (status, ", ".join(missing)))
allow()
PY
rc=$?
set -e
if [ "$rc" -ne 0 ] && [ "$rc" -ne 2 ]; then
  echo "review-cycle: refused -- record-fields-gate.sh: fail-closed: internal error (judge exited $rc; mapping non-0/2 to DENY)." >&2
  exit 2
fi
exit "$rc"
