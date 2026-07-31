#!/usr/bin/env bash
# --- fail-closed trap-at-top (installed before any source/set/other code) ---
# A PreToolUse gate that aborts before its verdict logic runs must still DENY:
# Claude Code treats any non-2 exit as NON-BLOCKING (fail-open). This EXIT trap
# forces exit 2 (DENY) for any exit code that is neither 0 (allow) nor 2 (deny).
# Preserves legitimate terminal exit 0 / exit 2 verdicts unchanged.
__fc(){ rc=$?; if [ "$rc" != 0 ] && [ "$rc" != 2 ]; then echo "fail-closed: gate aborted (rc=$rc)" >&2; exit 2; fi; }
trap __fc EXIT
# PreToolUse(Write|Edit|MultiEdit) sibling gate for the `review` role — issue
# #39 (b.5), matching the freelunch-grade structural completeness bar the
# `core` fan-out plugin holds a chunk to before accepting it as complete,
# applied here to this role's own phase-1 proposal
# (docs/issue-<n>/proposals/review.md). Inspects the PROPOSED content for
# five structural requirements; any single missing requirement is refused,
# named in the deny message:
#
#   a. a Request heading
#   b. a Constraints heading with a non-trivial body
#   c. at least one "adopt(ed)" claim paragraph that also carries a
#      source-attribution pattern (link, docs/ path, issue-<n>/issue #<n>)
#   d. an explicit adopted-vs-skipped split (both sides present, each with
#      at least one line of content)
#   e. a closing "How this will be judged" section naming at least one
#      externally-verifiable condition
#
# This is a phase-1 structural probe only — it does not check the adoption
# claims for truth, only that the document's shape forces them to be made
# with a citable source and a judgeable, closing condition.
#
# Kill switch: export REVIEW_PROPOSAL_COMPLETENESS_GATE_OFF=1
set -euo pipefail

case "${REVIEW_PROPOSAL_COMPLETENESS_GATE_OFF:-}" in
  ""|0|false|no|off) ;;
  *) exit 0 ;;
esac

if ! command -v python3 >/dev/null 2>&1; then
  echo "review-proposal-completeness: refused — proposal-completeness-gate.sh requires python3, which is not on PATH; denying rather than allowing an uninspectable write." >&2
  exit 2
fi

payload="$(cat 2>/dev/null || true)"
if [ -z "$payload" ]; then
  echo "review-proposal-completeness: refused — proposal-completeness-gate.sh got no readable payload on stdin; denying rather than allowing an uninspectable write." >&2
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
        sys.stderr.write("review-proposal-completeness: refused — proposal-completeness-gate.sh: fail-closed: internal error: %r\n" % (_e,))
        sys.stderr.flush()
    except Exception:
        pass
    _fc_os._exit(2)
sys.excepthook = _fc_excepthook

def deny(msg):
    sys.stderr.write("review-proposal-completeness: refused — " + msg + "\n")
    sys.exit(2)

def allow():
    sys.exit(0)

try:
    event = json.loads(os.environ.get("REVIEW_PAYLOAD", ""))
except ValueError:
    deny("proposal-completeness-gate.sh: payload is not valid JSON; cannot judge a write it cannot parse.")
if not isinstance(event, dict):
    deny("proposal-completeness-gate.sh: payload is not a JSON object; cannot judge a write it cannot parse.")

tool = event.get("tool_name")
if tool not in ("Write", "Edit", "MultiEdit"):
    allow()

tool_input = event.get("tool_input")
if not isinstance(tool_input, dict):
    deny("proposal-completeness-gate.sh: tool_input missing or not an object on a %s call; denying rather than allowing an uninspectable write." % tool)

path = tool_input.get("file_path")
if not isinstance(path, str) or not path:
    deny("proposal-completeness-gate.sh: no usable file_path on a %s call; denying rather than allowing an unidentifiable write." % tool)

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
    deny("proposal-completeness-gate.sh: no project root could be determined; denying rather than allowing an indeterminate-root write.")

absu = posixpath.normpath(norm if posixpath.isabs(norm) else posixpath.join(root, norm))
real = posixpath.normpath(os.path.realpath(absu).replace("\\", "/"))
rel = real[len(root) + 1:] if (real == root or real.startswith(root + "/")) else None

if not (rel and re.match(r'^docs/issue-[0-9]+/proposals/review\.md$', rel)):
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
    deny("proposal-completeness-gate.sh: could not read the attempted new content of this write to the phase-1 proposal; denying rather than allowing an uninspectable write.")

missing = []

# Split into paragraphs (blank-line separated) and heading-bounded sections
# for the section-body checks below.
lines = content.splitlines()
heading_re = re.compile(r'^\s{0,3}#{1,6}\s+(.*\S)\s*$')
headings = []  # (line_index, level_text, title)
for i, ln in enumerate(lines):
    m = heading_re.match(ln)
    if m:
        headings.append((i, ln, m.group(1).strip()))

def section_body(title_pattern):
    """Return the body text following the first heading whose title matches
    title_pattern (case-insensitive), up to the next heading of any level."""
    rx = re.compile(title_pattern, re.I)
    for idx, (i, _ln, title) in enumerate(headings):
        if rx.search(title):
            end = headings[idx + 1][0] if idx + 1 < len(headings) else len(lines)
            return "\n".join(lines[i + 1:end])
    return None

# (a) Request heading present.
if section_body(r'^Request$') is None:
    missing.append("Request")

# (b) Constraints heading present, with a non-trivial body (>=20 non-ws chars).
constraints_body = section_body(r'^Constraints$')
if constraints_body is None:
    missing.append("Constraints")
else:
    if len(re.sub(r'\s+', '', constraints_body)) < 20:
        missing.append("Constraints (present but body is trivial/empty)")

# (c) At least one "adopt" paragraph co-located with a source-attribution
# pattern in the same paragraph.
paragraphs = re.split(r'\n\s*\n', content)
source_pat = re.compile(r'\[[^\]]+\]\([^)]+\)|https?://\S+|docs/\S+|issue[\s-]?#?\d+', re.I)
sourced_adopt = any(
    re.search(r'\badopt(?:ed|s|ion)?\b', p, re.I) and source_pat.search(p)
    for p in paragraphs
)
if not sourced_adopt:
    missing.append("sourced adoption claim (an \"adopt\"/\"adopted\" paragraph naming a source: link, docs/ path, or issue-<n>/issue #<n>)")

# (d) Explicit adopt-vs-skip split: an "adopted" list-like section AND a
# "skipped"/"out of scope" list-like section, each with >=1 content line.
def has_list_section(title_pattern):
    body = section_body(title_pattern)
    if body is None:
        # fall back to a loosely-labeled inline list: a line starting the
        # label followed by list items, without requiring a heading.
        m = re.search(title_pattern, content, re.I)
        if not m:
            return False
        tail = content[m.end():]
        tail_lines = tail.splitlines()[:20]
        return any(re.match(r'^\s*[-*]\s+\S', ln) for ln in tail_lines)
    return any(re.match(r'^\s*[-*]\s+\S', ln) or ln.strip() for ln in body.splitlines() if ln.strip())

adopted_ok = has_list_section(r'adopt(?:ed)?')
skipped_ok = has_list_section(r'skip(?:ped)?|out of scope|deliberately out of scope')
if not (adopted_ok and skipped_ok):
    parts = []
    if not adopted_ok:
        parts.append("an adopted list")
    if not skipped_ok:
        parts.append("a skipped/out-of-scope list")
    missing.append("adopt-vs-skip split (missing " + " and ".join(parts) + ")")

# (e) Closing "How this will be judged" section with a verifiable condition.
judged_body = section_body(r'How\s+this\s+will\s+be\s+judged')
if judged_body is None:
    missing.append('"How this will be judged" closing section')
else:
    verifiable_pat = re.compile(r'file exists|exit code|\bgate\b|field presence|\btest\b|\bpass\b', re.I)
    if not verifiable_pat.search(judged_body):
        missing.append('"How this will be judged" section (present but names no externally-verifiable condition: file exists/exit code/gate/field presence/test/pass)')
    else:
        # must close the document: no heading of equal-or-higher weight
        # appears after it with unrelated content following an empty judged
        # body is already covered above.
        pass

if missing:
    deny("proposal-completeness-gate.sh: phase-1 proposal at %s is missing required structure: %s. Per issue #39 (b.5)/#30 (a), a phase-1 proposal must carry Request, Constraints (non-trivial), a sourced adoption claim, an explicit adopt-vs-skip split, and a closing How-this-will-be-judged section with a verifiable condition." % (rel, "; ".join(missing)))

allow()
PY
rc=$?
set -e
if [ "$rc" -ne 0 ] && [ "$rc" -ne 2 ]; then
  echo "review-proposal-completeness: refused -- proposal-completeness-gate.sh: fail-closed: internal error (judge exited $rc; mapping non-0/2 to DENY)." >&2
  exit 2
fi
exit "$rc"
