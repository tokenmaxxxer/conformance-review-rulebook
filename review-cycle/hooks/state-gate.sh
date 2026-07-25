#!/usr/bin/env bash
# PreToolUse hook for the `review` role. Two independent rules, both
# evaluated against the TARGET PATH (or, for Bash, the resolved operand of
# the command string) rather than against which tool performs the action —
# mirroring coding-agent-rulebook/warrant/hooks/scope-gate.sh's own design,
# named directly in docs/specs/agent-roles.md Part 3: "a rejection rule is
# evaluated against the path being written, never against which tool
# performs the write." The same treatment extends here to reads, because
# rule 2 below is a read refusal, not a write refusal.
#
#   Rule 1 (write gate): a write that would change review-record.md's
#   `status` to `reported` is refused unless (a) every requirement block in
#   the file carries exactly one verdict of Present/Surface/Absent/Incorrect,
#   and (b) a matching, unconsumed approval token minted by
#   capture-approval.sh from the user's OWN turn is present. Content alone
#   never passes.
#
#   Rule 2 (read refusal): in EVERY state, a tool call whose target names a
#   proposal/intent/scratch path — docs/proposals/**, or a path whose name
#   contains "proposal", "intent", "notes", or "scratch" in any casing — is
#   refused outright. This role is handed only the change and the
#   specification (docs/specs/agent-roles.md, `review`'s "Given to start"),
#   deliberately without the building agent's proposal prose; a path is the
#   only thing this gate can check mechanically, so it refuses on path shape
#   regardless of tool: Read, Grep, Glob, NotebookEdit's notebook_path, and
#   Bash commands (cat, less, grep, sed -n, head, tail, ...) that name such a
#   path as an operand are all covered the same way.
#
# FAILS CLOSED: malformed stdin, an unparseable payload, an unreadable
# review-record.md, or any input this script does not recognize the shape of
# denies the tool call (exit 2). Allow (exit 0) is reached only when this
# gate affirmatively determines the call is outside both rules, or (for
# Rule 1) that both conditions are met.
#
# Kill switch: export REVIEW_CYCLE_DISABLE=1 — deliberate operator override,
# exits 0 before any of the refuse-by-default logic below runs.
set -euo pipefail

case "${REVIEW_CYCLE_DISABLE:-}" in
  ""|0|false|no|off) ;;
  *) exit 0 ;;
esac

# Fail closed even when the interpreter this gate needs is missing — unlike
# doctrine's placement-gate.sh (which fails OPEN because it is the only
# thing protecting docs/ layout and a broken interpreter must not stall a
# session), this gate protects a human-approval boundary, and the frozen
# contract for this repository family requires fail-closed on malformed
# input, not fail-open on a missing interpreter.
if ! command -v python3 >/dev/null 2>&1; then
  echo "review-cycle: refused — python3 is not available, so this gate cannot verify the attempted tool call. Refusing rather than allowing an uninspectable action." >&2
  exit 2
fi

payload="$(cat 2>/dev/null || true)"
if [ -z "$payload" ]; then
  echo "review-cycle: refused — no readable hook payload on stdin. Refusing rather than allowing an uninspectable tool call." >&2
  exit 2
fi

root="${CLAUDE_PROJECT_DIR:-$PWD}"
state_name="${REVIEW_RECORD_NAME:-review-record.md}"

REVIEW_GATE_PAYLOAD="$payload" REVIEW_GATE_ROOT="$root" REVIEW_GATE_STATE_NAME="$state_name" python3 <<'PY'
import json
import os
import posixpath
import re
import sys

def allow(reason=""):
    if reason:
        print(json.dumps({"hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "allow",
            "permissionDecisionReason": reason,
        }}))
    sys.exit(0)

def refuse(msg):
    print(msg, file=sys.stderr)
    sys.exit(2)

try:
    event = json.loads(os.environ.get("REVIEW_GATE_PAYLOAD", ""))
except ValueError:
    refuse("review-cycle: refused — the hook payload on stdin could not be parsed as JSON. Refusing rather than allowing a tool call this gate cannot inspect.")
if not isinstance(event, dict):
    refuse("review-cycle: refused — the hook payload did not parse to a JSON object. Refusing rather than allowing a tool call this gate cannot inspect.")

tool = event.get("tool_name")
if not isinstance(tool, str) or not tool:
    refuse("review-cycle: refused — the hook payload names no tool. Refusing rather than allowing an unidentified tool call.")

tool_input = event.get("tool_input")
if not isinstance(tool_input, dict):
    # A tool call this gate cannot inspect at all is not "not our business" —
    # only a recognized, well-formed shape earns not_applicable below. An
    # unreadable tool_input on a tool this gate DOES care about (Bash,
    # Write, Edit, Read, Grep, Glob, NotebookEdit) is refused; other tools
    # (e.g. a pure reasoning/agent-dispatch tool with no file/command
    # surface) are allowed through since neither rule can ever apply to
    # them regardless of input shape.
    if tool in ("Bash", "Write", "Edit", "NotebookEdit", "Read", "Grep", "Glob"):
        refuse("review-cycle: refused — a %s call arrived with no readable tool_input. Refusing rather than allowing an uninspectable action." % tool)
    allow()

root = os.environ.get("REVIEW_GATE_ROOT") or os.getcwd()
root_real = posixpath.normpath(os.path.realpath(root).replace("\\", "/"))
state_name = os.environ.get("REVIEW_GATE_STATE_NAME") or "review-record.md"

def resolve(path_str):
    """Resolve a possibly-relative path string against root, then to its
    real (symlink-resolved) form. Returns the resolved absolute posix path,
    or None if path_str is not a usable string."""
    if not isinstance(path_str, str) or not path_str:
        return None
    norm = path_str.replace("\\", "/")
    absu = norm if posixpath.isabs(norm) else posixpath.join(root_real, norm)
    absu = posixpath.normpath(absu)
    real = posixpath.normpath(os.path.realpath(absu).replace("\\", "/"))
    return real

# --- Rule 2: standing refusal to read the building agent's intent --------
# Path-shape test, applied the same way regardless of which tool carries it.
# Patterns, and why each is here:
#   - docs/proposals/** — this org's own convention (doctrine, warrant) for
#     where a proposal/RFC lives; docs/specs/agent-roles.md names proposal
#     prose explicitly as off-limits to `review`.
#   - any path segment or filename containing "proposal", "intent",
#     "scratch", or "notes" (case-insensitive) — covers a coding agent's own
#     working/scratch files and intent notes wherever they live, since
#     `warrant`-style proposals and ad hoc "INTENT.md"/"notes.md" files are
#     not confined to one directory across every possible target repo.
INTENT_PATH_RE = re.compile(r"(^|/)docs/proposals(/|$)", re.I)
INTENT_NAME_RE = re.compile(r"(proposal|intent|scratch|notes)", re.I)

def looks_like_intent(path_str):
    if not isinstance(path_str, str) or not path_str:
        return False
    norm = path_str.replace("\\", "/")
    if INTENT_PATH_RE.search(norm):
        return True
    base = posixpath.basename(norm)
    return bool(INTENT_NAME_RE.search(base))

# Commands/tools that only ever read (never the write-gate's business, but
# fully in scope for the read refusal).
READ_PATH_KEYS = {
    "Read": ["file_path"],
    "Grep": ["path", "pattern"],
    "Glob": ["path", "pattern"],
    "NotebookEdit": ["notebook_path"],
}

if tool in READ_PATH_KEYS:
    for key in READ_PATH_KEYS[tool]:
        val = tool_input.get(key)
        if looks_like_intent(val):
            refuse(
                "review-cycle: refused — %s targets %r, which looks like the building agent's proposal, intent, "
                "notes, or scratch content. The review role works only from the change and the specification it "
                "was handed, never from the building agent's stated intent, in any state." % (tool, val)
            )

if tool == "Bash":
    command = tool_input.get("command")
    if not isinstance(command, str) or not command:
        refuse("review-cycle: refused — a Bash call arrived with no readable command. Refusing rather than allowing an uninspectable action.")

    # Read-refusal: any token in the command that looks like an intent path,
    # regardless of which command reads it (cat, less, grep, sed -n, head,
    # tail, awk, python, ...). This is intentionally broad: catching the
    # read is more important here than avoiding an occasional false refusal
    # on an unrelated command that happens to mention such a word.
    for token in re.split(r"[\s|;&<>()\"']+", command):
        if token and looks_like_intent(token):
            refuse(
                "review-cycle: refused — this Bash command references %r, which looks like the building agent's "
                "proposal, intent, notes, or scratch content. The review role never reads that, in any state, "
                "regardless of which tool or shell construct is used to get at it." % token
            )

# --- Rule 1: the auditing -> reported write gate --------------------------
# Candidate write-target paths for this call, however they get there.
candidates = []
if tool in ("Write", "Edit"):
    fp = tool_input.get("file_path")
    if isinstance(fp, str) and fp:
        candidates.append(fp)
elif tool == "NotebookEdit":
    pass  # notebooks are never the review record; nothing to add here.
elif tool == "Bash":
    command = tool_input.get("command")
    # This is deliberately name-based, not syntax-based: parsing arbitrary
    # shell for exact redirection targets is not reliable, and the
    # consequence of under-matching here is silently letting a state-file
    # write through a shell construct — exactly the hole
    # docs/specs/agent-roles.md's Part 3 rule exists to close. So: if the
    # review record's basename appears anywhere in the command string
    # alongside any write-shaped construct (redirection, tee, cp, mv,
    # sed -i, perl -i, dd, install, truncate, >|, printf ... >), treat this
    # as a candidate write to it and gate it — a false positive here only
    # costs an extra "state this transition's approval" turn; a false
    # negative would be a bypass.
    write_indicators = re.compile(
        r"(>>?|>\||\btee\b|\bcp\b|\bmv\b|\bsed\b[^\n]*-i|\bperl\b[^\n]*-i|\bdd\b|\binstall\b|\btruncate\b|\bmv\b)",
        re.I,
    )
    if isinstance(command, str) and state_name in command and write_indicators.search(command):
        candidates.append(state_name)

state_path_real = resolve(state_name)

touches_state = False
for c in candidates:
    c_real = resolve(c)
    if c_real is not None and state_path_real is not None and c_real == state_path_real:
        touches_state = True
        break
    # Bash candidates carry only the bare basename (see above); a literal
    # basename match against the resolved state path's own basename is the
    # best this gate can do without executing the shell, and — per the
    # comment above — erring toward gating is the safe direction.
    if tool == "Bash" and c == state_name:
        touches_state = True
        break

if not touches_state:
    allow()

# From here on, this call is a candidate write to review-record.md. Refuse
# unless we can affirmatively verify the two conditions.

def read_state_file():
    if not state_path_real or not os.path.exists(state_path_real):
        return None
    try:
        with open(state_path_real, encoding="utf-8-sig") as fh:
            return fh.read(1 << 20)
    except (OSError, UnicodeDecodeError):
        return None

def parse_blocks(text):
    return [m.group(1) for m in re.finditer(r"^---[ \t]*\r?\n(.*?)\r?\n---[ \t]*\r?\n?", text, re.M | re.S)]

def field(block, key):
    vals = re.findall(r"^%s:\s*(.*?)\s*(?:#.*)?$" % re.escape(key), block, re.M)
    return vals

VERDICTS = {"Present", "Surface", "Absent", "Incorrect"}

def current_status_and_verdicts(text):
    """Returns (status, verdicts_ok) from the given text. The first block
    that carries a `status:` key and no `requirement:` key is the header;
    every other block must carry exactly one `requirement:` and exactly one
    `verdict:` in VERDICTS for verdicts_ok to be True. A file with zero
    requirement blocks is never verdicts_ok=True — an empty audit proves
    nothing."""
    blocks = parse_blocks(text)
    status = None
    req_blocks = []
    for b in blocks:
        st = field(b, "status")
        rq = field(b, "requirement")
        if st and not rq:
            if len(st) == 1 and status is None:
                status = st[0].strip()
            else:
                return None, False
        else:
            req_blocks.append(b)
    if not req_blocks:
        return status, False
    for b in req_blocks:
        rq = field(b, "requirement")
        vd = field(b, "verdict")
        if len(rq) != 1 or not rq[0].strip():
            return status, False
        if len(vd) != 1 or vd[0].strip() not in VERDICTS:
            return status, False
    return status, True

cur_text = read_state_file()
if cur_text is None:
    refuse(
        "review-cycle: refused — %s could not be read (missing or unreadable). Refusing this write rather than "
        "adjudicating a transition against a state file this gate cannot verify." % state_name
    )

cur_status, verdicts_ok = current_status_and_verdicts(cur_text)

# For Write/Edit we can additionally check the ATTEMPTED content directly —
# more precise than falling back to the on-disk state. For Bash we cannot
# read the resulting content before the shell executes, so the resulting
# status is UNKNOWN — and unknown is treated as "could be `reported`", the
# conservative (fail-closed) assumption, rather than assuming it is safe.
# Concretely: attempted_status is forced to "reported" for any Bash call
# that touches the state file, which routes every such call through the
# same auditing-> reported checks below (current status must already be
# auditing with complete verdicts, and a valid token must be present) —
# there is no way for a Bash-mediated write to this file to skip the gate.
attempted_status = cur_status
attempted_verdicts_ok = verdicts_ok
if tool == "Bash":
    attempted_status = "reported"
    attempted_verdicts_ok = verdicts_ok
elif tool in ("Write", "Edit"):
    content = tool_input.get("content") if tool == "Write" else tool_input.get("new_string")
    if isinstance(content, str):
        attempted_status, attempted_verdicts_ok = current_status_and_verdicts(content)
    else:
        refuse("review-cycle: refused — could not read the attempted new content of this write, so the resulting state cannot be determined.")

# Only auditing -> reported is a gated transition this rule governs; any
# other resulting status from a write touching this file is out of this
# rule's scope UNLESS it is an illegal jump into `reported` from something
# other than `auditing`, which is refused outright (the state machine has
# exactly one legal predecessor of `reported`).
if attempted_status != "reported":
    allow()

if cur_status != "auditing":
    refuse(
        "review-cycle: refused — %s only permits entering `reported` from `auditing`; the file's current status is "
        "%r. docs/specs/state-machine.md names no other legal predecessor." % (state_name, cur_status)
    )

if not attempted_verdicts_ok:
    refuse(
        "review-cycle: refused — auditing -> reported requires every requirement block in %s to carry exactly one "
        "verdict of Present, Surface, Absent, or Incorrect, and at least one requirement block to exist. A file "
        "with an empty, missing, malformed, or out-of-set verdict on any requirement fails this transition." % state_name
    )

# --- token check ----------------------------------------------------------
tokens_dir = posixpath.join(root_real, ".review", "tokens")
tokens_dir_real = posixpath.normpath(os.path.realpath(tokens_dir).replace("\\", "/"))
if not (tokens_dir_real == root_real or tokens_dir_real.startswith(root_real + "/")):
    refuse("review-cycle: refused — the resolved token directory escapes the project root. Refusing rather than reading a token outside it.")

token_path = posixpath.join(tokens_dir_real, "report.token")
if not (token_path == tokens_dir_real or token_path.startswith(tokens_dir_real + "/")):
    refuse("review-cycle: refused — the resolved token path escapes the token directory. Refusing rather than reading it.")

def read_token():
    try:
        with open(token_path, encoding="utf-8-sig") as fh:
            ttext = fh.read(8192)
    except (OSError, UnicodeDecodeError):
        return None
    fm = re.search(r"^file:\s*(.+?)\s*(?:#.*)?$", ttext, re.M)
    tm = re.search(r"^transition:\s*(.+?)\s*(?:#.*)?$", ttext, re.M)
    if not fm or not tm:
        return None
    return fm.group(1).strip(), tm.group(1).strip()

token = read_token()
if token is None:
    refuse(
        "review-cycle: refused — auditing -> reported requires a matching approval token at %s and none is "
        "present. A person must approve the transition in their own turn (capture-approval.sh mints the token "
        "from that turn); the content of %s being complete is not, by itself, consent." % (token_path, state_name)
    )

t_file, t_transition = token
if t_file != state_name or t_transition != "auditing -> reported":
    refuse(
        "review-cycle: refused — the token at %s authorizes a different file or transition, so it does not cover "
        "auditing -> reported for %s. Treated as absent; a fresh, matching approval is required." % (token_path, state_name)
    )

# Single-use: consume the token now that it has authorized this call. If the
# underlying write never lands (the tool call errors after this point), the
# transition simply needs a fresh approval — same trade-off the frozen
# contract's sibling repositories make, favoring "never double-spend a
# token" over "never require re-approval after a failed write".
try:
    os.remove(token_path)
except OSError:
    refuse("review-cycle: refused — the approval token at %s could not be consumed. Refusing rather than allowing a write whose token would remain reusable." % token_path)

allow("review-cycle: auditing -> reported permitted — every requirement carries a valid verdict and a matching approval token was consumed.")
PY

exit $?
