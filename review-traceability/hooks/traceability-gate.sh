#!/usr/bin/env bash
# --- fail-closed trap-at-top (installed before any source/set/other code) ---
# A PreToolUse gate that aborts before its verdict logic runs must still DENY:
# Claude Code treats any non-2 exit as NON-BLOCKING (fail-open). This EXIT trap
# forces exit 2 (DENY) for any exit code that is neither 0 (allow) nor 2 (deny).
# Preserves legitimate terminal exit 0 / exit 2 verdicts unchanged.
__fc(){ rc=$?; if [ "$rc" != 0 ] && [ "$rc" != 2 ]; then echo "fail-closed: gate aborted (rc=$rc)" >&2; exit 2; fi; }
trap __fc EXIT
# PreToolUse(Write|Edit|MultiEdit) gate for the `review-traceability` plugin.
# On a write to a phase-1 proposal (docs/issue-<n>/proposals/review.md) or a
# phase-2 record (docs/issue-<n>/reports/(conformance-)?review.md), inspect
# the PROPOSED content:
#   - phase 1: require a requirement list (numbered/bulleted enumeration) or
#     an explicit "sampling derivation" statement.
#   - phase 2: every verdict token (Present|Surface|Absent|Incorrect|
#     Unverifiable, case-insensitive, word-boundary) must sit in a block that
#     also carries a spec_ref: field, and — unless the verdict is
#     Unverifiable — an evidence: field.
# Never judges the correctness of a verdict or evidence argument, or
# reviewer independence — structural field-copresence only.
#
# Kill switch: export REVIEW_TRACEABILITY_GATE_OFF=1
set -euo pipefail

case "${REVIEW_TRACEABILITY_GATE_OFF:-}" in
  ""|0|false|no|off) ;;
  *) exit 0 ;;
esac

if ! command -v python3 >/dev/null 2>&1; then
  echo "review-traceability: refused — traceability-gate.sh requires python3, which is not on PATH; denying rather than allowing an uninspectable write." >&2
  exit 2
fi

payload="$(cat 2>/dev/null || true)"
if [ -z "$payload" ]; then
  echo "review-traceability: refused — traceability-gate.sh got no readable payload on stdin; denying rather than allowing an uninspectable write." >&2
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
        sys.stderr.write("review-traceability: refused — traceability-gate.sh: fail-closed: internal error: %r\n" % (_e,))
        sys.stderr.flush()
    except Exception:
        pass
    _fc_os._exit(2)
sys.excepthook = _fc_excepthook
def deny(msg):
    sys.stderr.write("review-traceability: refused — " + msg + "\n")
    sys.exit(2)

def allow():
    sys.exit(0)

try:
    event = json.loads(os.environ.get("REVIEW_PAYLOAD", ""))
except ValueError:
    deny("traceability-gate.sh: payload is not valid JSON; cannot judge a write it cannot parse.")
if not isinstance(event, dict):
    deny("traceability-gate.sh: payload is not a JSON object; cannot judge a write it cannot parse.")

tool = event.get("tool_name")
if tool not in ("Write", "Edit", "MultiEdit"):
    allow()

tool_input = event.get("tool_input")
if not isinstance(tool_input, dict):
    deny("traceability-gate.sh: tool_input missing or not an object on a %s call; denying rather than allowing an uninspectable write." % tool)

path = tool_input.get("file_path")
if not isinstance(path, str) or not path:
    deny("traceability-gate.sh: no usable file_path on a %s call; denying rather than allowing an unidentifiable write." % tool)

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
    deny("traceability-gate.sh: no project root could be determined; denying rather than allowing an indeterminate-root write.")

absu = posixpath.normpath(norm if posixpath.isabs(norm) else posixpath.join(root, norm))
real = posixpath.normpath(os.path.realpath(absu).replace("\\", "/"))
rel = real[len(root) + 1:] if (real == root or real.startswith(root + "/")) else None

phase1 = bool(rel) and re.match(r'^docs/issue-[0-9]+/proposals/review\.md$', rel)
phase2 = bool(rel) and re.match(r'^docs/issue-[0-9]+/reports/(conformance-)?review\.md$', rel)
if not (phase1 or phase2):
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
    deny("traceability-gate.sh: could not read the attempted new content of this write; denying rather than allowing an uninspectable write.")

if phase1:
    bullet_hits = len(re.findall(r'^\s*[-*]\s+\S', content, re.M))
    numbered_hits = len(re.findall(r'^\s*\d+[.)]\s+\S', content, re.M))
    has_list = (bullet_hits + numbered_hits) >= 2
    has_sampling = bool(re.search(r'sampling derivation', content, re.I))
    if not (has_list or has_sampling):
        deny("traceability-gate.sh: phase-1 mode (proposals/review.md) requires a "
             "requirement list (numbered or bulleted enumeration) or a stated "
             "sampling derivation; neither was found in the proposed content.")
    allow()

# phase 2
verdict_re = re.compile(r'\b(Present|Surface|Absent|Incorrect|Unverifiable)\b', re.I)
matches = list(verdict_re.finditer(content))
if not matches:
    allow()

# Split content into blocks on blank lines or markdown headers.
blocks = re.split(r'(?:\n\s*\n)|(?=^#{1,6}\s)', content, flags=re.M)
# Precompute block spans by locating each block's start offset in content.
offsets = []
cursor = 0
for b in blocks:
    idx = content.find(b, cursor)
    if idx == -1:
        idx = cursor
    offsets.append((idx, idx + len(b), b))
    cursor = idx + len(b)

def block_for(pos):
    for start, end, b in offsets:
        if start <= pos < end:
            return b
    return content

for m in matches:
    verdict = m.group(1)
    block = block_for(m.start())
    has_spec_ref = bool(re.search(r'spec_ref\s*:', block))
    if not has_spec_ref:
        deny("traceability-gate.sh: phase-2 verdict '%s' found without a spec_ref: "
             "field in its surrounding block; every requirement's verdict must "
             "name the spec locator it was checked against (issues #30/#37/#38)."
             % verdict)
    if verdict.lower() != "unverifiable":
        has_evidence = bool(re.search(r'evidence\s*:', block))
        if not has_evidence:
            deny("traceability-gate.sh: phase-2 verdict '%s' found without an "
                 "evidence: field in its surrounding block; every non-Unverifiable "
                 "verdict must name the artifact pointer it was checked against "
                 "(issues #30/#37/#38)." % verdict)

allow()
PY
rc=$?
set -e
if [ "$rc" -ne 0 ] && [ "$rc" -ne 2 ]; then
  echo "review-traceability: refused -- traceability-gate.sh: fail-closed: internal error (judge exited $rc; mapping non-0/2 to DENY)." >&2
  exit 2
fi
exit "$rc"
