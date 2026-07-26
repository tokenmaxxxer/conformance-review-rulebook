#!/usr/bin/env bash
# PreToolUse(Bash matching 'git commit') sibling gate for the `review` role
# — §13. When a review unit is IN PROGRESS (review-record.md exists and its
# status is a non-terminal state) a `git commit` must carry review's declared
# trailer keys identifying the record: both `Subject:` and `Kind:`. A commit
# for an in-progress unit lacking either trailer is refused.
#
# review's declared trailer keys (this rulebook's own §13 declaration):
#   Subject: <subject>   Kind: <record-kind>
#
# FAILS CLOSED: unparseable payload, indeterminate root, an unreadable
# in-progress state, or a commit message this gate cannot extract while a
# unit is in progress all DENY (exit 2).
# Kill switch: export REVIEW_CYCLE_DISABLE=1
set -euo pipefail

case "${REVIEW_CYCLE_DISABLE:-}" in
  ""|0|false|no|off) ;;
  *) exit 0 ;;
esac

if ! command -v python3 >/dev/null 2>&1; then
  echo "review-cycle: refused — trailer-gate.sh requires python3, which is not on PATH; denying rather than allowing an uninspectable commit." >&2
  exit 2
fi

payload="$(cat 2>/dev/null || true)"
if [ -z "$payload" ]; then
  echo "review-cycle: refused — trailer-gate.sh got no readable payload on stdin; denying rather than allowing an uninspectable commit." >&2
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
        sys.stderr.write("review-cycle: refused \u2014 trailer-gate.sh: fail-closed: internal error: %r\n" % (_e,))
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
    deny("trailer-gate.sh: payload is not valid JSON; cannot judge a commit it cannot parse.")
if not isinstance(event, dict):
    deny("trailer-gate.sh: payload is not a JSON object; cannot judge a commit it cannot parse.")

if event.get("tool_name") != "Bash":
    allow()
tool_input = event.get("tool_input")
if not isinstance(tool_input, dict):
    deny("trailer-gate.sh: Bash tool_input missing or not an object; denying rather than allowing an uninspectable commit.")
command = tool_input.get("command")
if not isinstance(command, str) or not command:
    deny("trailer-gate.sh: Bash command missing; denying rather than allowing an uninspectable commit.")

if not re.search(r"\bgit\b(?:\s+-[^\s]+|\s+--[^\s]+(?:=\S+)?)*\s+commit\b", command):
    allow()

def plausible(r):
    return bool(r) and os.path.isdir(r) and (os.path.exists(os.path.join(r, ".git")) or os.path.isfile(os.path.join(r, "docs/specs/role-handoff-contract.md")))

cpd = os.environ.get("CLAUDE_PROJECT_DIR")
root = None
if cpd and plausible(cpd):
    root = posixpath.normpath(os.path.realpath(cpd).replace("\\", "/"))
if root is None:
    try:
        top = subprocess.run(["git", "-C", os.getcwd(), "rev-parse", "--show-toplevel"],
                             capture_output=True, text=True)
        if top.returncode == 0 and top.stdout.strip():
            root = posixpath.normpath(os.path.realpath(top.stdout.strip()).replace("\\", "/"))
    except Exception:
        root = None
if root is None:
    deny("trailer-gate.sh: no git project root could be determined for the commit; denying rather than allowing an indeterminate-root commit.")

# --- Is a review unit in progress? ---
# terminal states = states appearing as a `to` but never as a `from`.
rules_file = os.environ.get("REVIEW_RULES_FILE") or ""
froms, tos = set(), set()
try:
    with open(rules_file, encoding="utf-8-sig") as fh:
        for line in fh:
            line = line.strip()
            if not line or "|" not in line or line.startswith("#"):
                continue
            parts = [p.strip() for p in line.strip("|").split("|")]
            if len(parts) != 4 or (parts[0].lower() == "from" and parts[1].lower() == "to"):
                continue
            if set(parts[0]) <= {"-"} or set(parts[1]) <= {"-"}:
                continue
            froms.add(parts[0]); tos.add(parts[1])
except OSError:
    deny("trailer-gate.sh: transition-rules.md could not be read to determine terminal states; denying rather than guessing whether a unit is in progress.")
if not tos and not froms:
    deny("trailer-gate.sh: transition-rules.md has no parseable rows; denying rather than guessing.")
terminal = (tos | froms) - froms

state_name = os.environ.get("REVIEW_STATE_NAME") or "review-record.md"
state_path = posixpath.join(root, state_name)
in_progress = False
if os.path.isfile(state_path):
    try:
        with open(state_path, encoding="utf-8-sig") as fh:
            stext = fh.read(1 << 20)
    except (OSError, UnicodeDecodeError):
        deny("trailer-gate.sh: %s exists but could not be read to determine unit progress; denying rather than allowing an uninspectable commit." % state_name)
    sm = re.findall(r"^(?:status|loop_state):\s*(.*?)\s*(?:#.*)?$", stext, re.M)
    if len(sm) != 1 or not sm[0].strip():
        deny("trailer-gate.sh: %s status field is missing, duplicated, or unparseable; denying rather than guessing whether a unit is in progress." % state_name)
    status = sm[0].strip()
    in_progress = status not in terminal

if not in_progress:
    # No in-progress unit: §13 trailer requirement does not bind this commit.
    allow()

# --- Extract the commit message and check for the required trailers ---
# Support -m/-F and --message=/--file=. If a unit is in progress and the
# message cannot be statically extracted, FAIL CLOSED.
msgs = []
for m in re.finditer(r"(?:^|\s)(?:-m|--message)(?:=|\s+)(\"(?:[^\"\\]|\\.)*\"|'(?:[^']|'\\'')*'|\S+)", command):
    tok = m.group(1)
    if len(tok) >= 2 and tok[0] == tok[-1] and tok[0] in "\"'":
        tok = tok[1:-1]
    msgs.append(tok)

file_msg = None
fm = re.search(r"(?:^|\s)(?:-F|--file)(?:=|\s+)(\"[^\"]*\"|'[^']*'|\S+)", command)
if fm:
    ftok = fm.group(1)
    if len(ftok) >= 2 and ftok[0] == ftok[-1] and ftok[0] in "\"'":
        ftok = ftok[1:-1]
    fpath = ftok if posixpath.isabs(ftok) else posixpath.join(root, ftok)
    try:
        with open(fpath, encoding="utf-8-sig") as fh:
            file_msg = fh.read(1 << 20)
    except OSError:
        deny("trailer-gate.sh: commit message file %s could not be read while a review unit is in progress; denying rather than allowing an unverifiable trailer." % ftok)

if not msgs and file_msg is None:
    deny("trailer-gate.sh: a review unit is in progress but this git commit's message could not be "
         "extracted (no -m/--message or -F/--file found; an editor/heredoc message is not statically "
         "inspectable). Per §13 the commit must carry Subject:/Kind: trailers; refusing rather than "
         "allowing an unverifiable commit.")

full = "\n".join(msgs) + ("\n" + file_msg if file_msg else "")

has_subject = re.search(r"(?mi)^\s*Subject:\s*\S+", full) is not None
has_kind = re.search(r"(?mi)^\s*Kind:\s*\S+", full) is not None
if not (has_subject and has_kind):
    missing = []
    if not has_subject: missing.append("Subject:")
    if not has_kind: missing.append("Kind:")
    deny("trailer-gate.sh: a review unit is in progress but this commit lacks required trailer(s): %s. "
         "Per contract §13, a landing commit must carry review's declared trailers identifying the "
         "record (Subject: <subject> and Kind: <record-kind>)." % ", ".join(missing))
allow()
PY
rc=$?
set -e
if [ "$rc" -ne 0 ] && [ "$rc" -ne 2 ]; then
  echo "review-cycle: refused -- trailer-gate.sh: fail-closed: internal error (judge exited $rc; mapping non-0/2 to DENY)." >&2
  exit 2
fi
exit "$rc"
