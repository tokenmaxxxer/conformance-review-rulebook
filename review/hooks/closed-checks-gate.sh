#!/usr/bin/env bash
# --- fail-closed trap-at-top (installed before any source/set/other code) ---
# A PreToolUse gate that aborts before its verdict logic runs must still DENY:
# Claude Code treats any non-2 exit as NON-BLOCKING (fail-open). This EXIT trap
# forces exit 2 (DENY) for any exit code that is neither 0 (allow) nor 2 (deny).
# Preserves legitimate terminal exit 0 / exit 2 verdicts unchanged.
__fc(){ rc=$?; if [ "$rc" != 0 ] && [ "$rc" != 2 ]; then echo "fail-closed: gate aborted (rc=$rc)" >&2; exit 2; fi; }
trap __fc EXIT
# PreToolUse(Write|Edit|MultiEdit) sibling gate for the `review` role — §16.
# On a write to review's own record, inspect any `closed_checks:` entries in
# the PROPOSED content: each entry's `code_sha` must equal the code sha
# currently under review. A check closed on a different sha does not count as
# closed (§16) — refuse the write; it must be re-derived, not cited.
#
# Current code sha resolution order:
#   1. a `code_under_review:` field in the proposed content, else
#   2. an `upstream:`/`upstream_code_sha:` field naming the code sha, else
#   3. `git rev-parse HEAD` at the resolved project root.
# If closed_checks entries exist but no current sha can be determined, FAIL
# CLOSED (refuse) — never allow an uncomparable cite-and-skip.
#
# Kill switch: export REVIEW_CYCLE_DISABLE=1
set -euo pipefail

case "${REVIEW_CYCLE_DISABLE:-}" in
  ""|0|false|no|off) ;;
  *) exit 0 ;;
esac

if ! command -v python3 >/dev/null 2>&1; then
  echo "review-cycle: refused — closed-checks-gate.sh requires python3, which is not on PATH; denying rather than allowing an uninspectable write." >&2
  exit 2
fi

payload="$(cat 2>/dev/null || true)"
if [ -z "$payload" ]; then
  echo "review-cycle: refused — closed-checks-gate.sh got no readable payload on stdin; denying rather than allowing an uninspectable write." >&2
  exit 2
fi

state_name="${REVIEW_RECORD_NAME:-review-record.md}"

set +e
REVIEW_PAYLOAD="$payload" REVIEW_STATE_NAME="$state_name" python3 <<'PY'
import json, os, posixpath, re, sys, subprocess

import os as _fc_os
def _fc_excepthook(_t, _e, _tb):
    if issubclass(_t, SystemExit):
        sys.__excepthook__(_t, _e, _tb); return
    try:
        sys.stderr.write("review-cycle: refused \u2014 closed-checks-gate.sh: fail-closed: internal error: %r\n" % (_e,))
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
    deny("closed-checks-gate.sh: payload is not valid JSON; cannot judge a write it cannot parse.")
if not isinstance(event, dict):
    deny("closed-checks-gate.sh: payload is not a JSON object; cannot judge a write it cannot parse.")

tool = event.get("tool_name")
if tool not in ("Write", "Edit", "MultiEdit"):
    allow()

tool_input = event.get("tool_input")
if not isinstance(tool_input, dict):
    deny("closed-checks-gate.sh: tool_input missing or not an object on a %s call; denying rather than allowing an uninspectable write." % tool)

path = tool_input.get("file_path")
if not isinstance(path, str) or not path:
    deny("closed-checks-gate.sh: no usable file_path on a %s call; denying rather than allowing an unidentifiable write." % tool)

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
    deny("closed-checks-gate.sh: no project root could be determined; denying rather than allowing an indeterminate-root write.")

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
    deny("closed-checks-gate.sh: could not read the attempted new content of this write to review's record; denying rather than allowing an uninspectable §16 write.")

# Extract closed_checks code_sha values. Only care if any exist.
cited = re.findall(r"^\s*(?:-\s*)?code_sha:\s*([0-9A-Za-z]+)\s*$", content, re.M)
# Require the cited sha to sit under a closed_checks block: heuristic — a
# code_sha field is only meaningful here if the record mentions closed_checks.
if not cited or not re.search(r"closed_checks\s*:", content):
    allow()

# Determine current code sha under review.
current = None
mcur = re.findall(r"^\s*(?:code_under_review|upstream_code_sha):\s*([0-9A-Za-z]+)\s*$", content, re.M)
if len(mcur) >= 1:
    current = mcur[0].strip()
if current is None:
    mup = re.findall(r"^\s*upstream:\s*([0-9A-Fa-f]{7,40})\s*$", content, re.M)
    if len(mup) >= 1:
        current = mup[0].strip()
if current is None:
    deny("closed-checks-gate.sh: record carries closed_checks entries but no "
         "code_under_review:/upstream_code_sha:/upstream: field naming the code sha under "
         "review. Under per-role issue branches the working HEAD is a docs commit, never the "
         "code under review, so the record must name the sha explicitly. Refusing an "
         "uncomparable cite-and-skip, per s16.")

def eqsha(a, b):
    a, b = a.strip(), b.strip()
    n = min(len(a), len(b))
    return n >= 7 and a[:n] == b[:n]

for c in cited:
    if not eqsha(c, current):
        deny("closed-checks-gate.sh: a closed_checks entry cites code_sha %s, but the code currently "
             "under review is at %s. A check closed on a different sha does not count as closed per "
             "contract §16 — re-derive it instead of citing." % (c, current))
allow()
PY
rc=$?
set -e
if [ "$rc" -ne 0 ] && [ "$rc" -ne 2 ]; then
  echo "review-cycle: refused -- closed-checks-gate.sh: fail-closed: internal error (judge exited $rc; mapping non-0/2 to DENY)." >&2
  exit 2
fi
exit "$rc"
