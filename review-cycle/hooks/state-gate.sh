#!/usr/bin/env bash
# PreToolUse hook for the `review` role. Two independent rules, both
# evaluated against the TARGET PATH (or, for Bash, the resolved operand of
# the command string) rather than against which tool performs the action —
# named directly in docs/specs/agent-roles.md Part 3: "a rejection rule is
# evaluated against the path being written, never against which tool
# performs the write." The same treatment extends here to reads, because
# rule 2 below is a read refusal, not a write refusal.
#
#   Rule 1 (write gate): a write that reaches review-record.md, judged by
#   RESOLVED TARGET PATH, is checked against transition-rules.md — the
#   single source of truth for legal transitions, also read by
#   inject-transition-rules.sh. This gate no longer consults approval
#   tokens or any other side-channel; it only answers (a) does this write
#   reach the state file, and (b) if so, is the resulting transition a row
#   in transition-rules.md. This gate has no hardcoded state or verdict
#   list of its own — the known-states set is whatever appears in
#   transition-rules.md's `from`/`to` columns, currently `idle`, `scoped`,
#   `auditing`, `draft-reported`, `reported`, plus the `(none)` bootstrap
#   (which is never itself a row's `from`/`to` target other than as the
#   synthetic starting state). Adding `draft-reported` therefore required
#   no change to this script's logic, only to transition-rules.md.
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
# tool_input, or any input this script does not recognize the shape of
# denies the tool call (exit 2). Allow (exit 0) is reached only when this
# gate affirmatively determines the call is outside both rules, or (for
# Rule 1) that the resulting transition is a listed row.
#
# NOTE ON RESOLVED-PATH SCOPING: for a Bash command whose write target
# cannot be determined statically (variable, expansion, command
# substitution, glob, indirection, `eval`, or a heredoc into a computed
# name), this gate treats the call as reaching the state file and applies
# rule 1's transition check to it. That scoping applies ONLY to deciding
# whether the state file is reached — a command that is not write-shaped
# toward the state file's directory at all is never denied just because
# some unrelated operand in it happens to be unresolvable.
#
# Kill switch: export REVIEW_CYCLE_DISABLE=1 — deliberate operator override,
# exits 0 before any of the refuse-by-default logic below runs.
set -euo pipefail

case "${REVIEW_CYCLE_DISABLE:-}" in
  ""|0|false|no|off) ;;
  *) exit 0 ;;
esac

# Fail closed even when the interpreter this gate needs is missing.
if ! command -v python3 >/dev/null 2>&1; then
  echo "review-cycle: refused — python3 is not available, so this gate cannot verify the attempted tool call. Refusing rather than allowing an uninspectable action." >&2
  exit 2
fi

payload="$(cat 2>/dev/null || true)"
if [ -z "$payload" ]; then
  echo "review-cycle: refused — no readable hook payload on stdin. The transition rules could not be loaded against an uninspectable call. Refusing rather than allowing it." >&2
  exit 2
fi

root="${CLAUDE_PROJECT_DIR:-$PWD}"
state_name="${REVIEW_RECORD_NAME:-review-record.md}"
HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd -P)"
rules_file="${REVIEW_TRANSITION_RULES:-$HOOK_DIR/transition-rules.md}"

REVIEW_GATE_PAYLOAD="$payload" REVIEW_GATE_ROOT="$root" REVIEW_GATE_STATE_NAME="$state_name" REVIEW_GATE_RULES_FILE="$rules_file" python3 <<'PY'
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
    refuse("review-cycle: refused — the transition rules could not be loaded: the hook payload on stdin could not be parsed as JSON. Refusing rather than allowing a tool call this gate cannot inspect.")
if not isinstance(event, dict):
    refuse("review-cycle: refused — the transition rules could not be loaded: the hook payload did not parse to a JSON object. Refusing rather than allowing a tool call this gate cannot inspect.")

tool = event.get("tool_name")
if not isinstance(tool, str) or not tool:
    refuse("review-cycle: refused — the transition rules could not be loaded: the hook payload names no tool. Refusing rather than allowing an unidentified tool call.")

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
        refuse("review-cycle: refused — the transition rules could not be loaded: a %s call arrived with no readable tool_input. Refusing rather than allowing an uninspectable action." % tool)
    allow()

root = os.environ.get("REVIEW_GATE_ROOT") or os.getcwd()
root_real = posixpath.normpath(os.path.realpath(root).replace("\\", "/"))
state_name = os.environ.get("REVIEW_GATE_STATE_NAME") or "review-record.md"
rules_file = os.environ.get("REVIEW_GATE_RULES_FILE") or ""

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
        refuse("review-cycle: refused — the transition rules could not be loaded: a Bash call arrived with no readable command. Refusing rather than allowing an uninspectable action.")

    for token in re.split(r"[\s|;&<>()\"']+", command):
        if token and looks_like_intent(token):
            refuse(
                "review-cycle: refused — this Bash command references %r, which looks like the building agent's "
                "proposal, intent, notes, or scratch content. The review role never reads that, in any state, "
                "regardless of which tool or shell construct is used to get at it." % token
            )

# --- Rule 1: transition-table gate on writes reaching the state file ------
# Candidate write-target paths for this call, however they get there. Also
# tracks whether ANY write-shaped construct in a Bash command has an
# unresolvable target (see NOTE ON RESOLVED-PATH SCOPING above) — that flag
# only routes the call into the state-file check; it never denies a
# command outright by itself.
candidates = []
bash_unresolvable = False

if tool in ("Write", "Edit"):
    fp = tool_input.get("file_path")
    if isinstance(fp, str) and fp:
        candidates.append(fp)
elif tool == "NotebookEdit":
    pass  # notebooks are never the review record; nothing to add here.
elif tool == "Bash":
    command = tool_input.get("command")

    DYNAMIC_RE = re.compile(r"[$`*?\[\](){}~]")

    def is_dynamic(tok):
        return (not tok) or bool(DYNAMIC_RE.search(tok))

    def strip_quotes(tok):
        if len(tok) >= 2 and tok[0] == tok[-1] and tok[0] in "\"'":
            return tok[1:-1]
        return tok

    def non_flag_args(argstr):
        return [a for a in argstr.split() if a and not a.startswith("-")]

    bash_literal_targets = []
    bash_write_shaped = False

    if isinstance(command, str) and command:
        if re.search(r"\beval\b", command):
            # `eval` can construct and execute an arbitrary write at
            # runtime; its payload is not statically parseable here.
            bash_write_shaped = True
            bash_unresolvable = True
        else:
            for op_m in re.finditer(r"(>>|>\|?)\s*(\S+)", command):
                tok = strip_quotes(op_m.group(2))
                if tok.startswith("&"):
                    continue  # fd duplication (e.g. `2>&1`), not a path write
                bash_write_shaped = True
                if is_dynamic(tok):
                    bash_unresolvable = True
                else:
                    bash_literal_targets.append(tok)

            for tee_m in re.finditer(r"\btee\b((?:\s+-\S+)*)\s+([^\n;&|]+?)(?=(?:[;&|]|$))", command):
                bash_write_shaped = True
                for tok in non_flag_args(tee_m.group(2)):
                    tok = strip_quotes(tok)
                    if is_dynamic(tok):
                        bash_unresolvable = True
                    else:
                        bash_literal_targets.append(tok)

            for dd_m in re.finditer(r"\bdd\b[^\n;&|]*\bof=(\S+)", command):
                bash_write_shaped = True
                tok = strip_quotes(dd_m.group(1))
                if is_dynamic(tok):
                    bash_unresolvable = True
                else:
                    bash_literal_targets.append(tok)

            for cmv_m in re.finditer(r"\b(?:cp|mv|install|truncate)\b([^\n;&|]*)", command):
                args = non_flag_args(cmv_m.group(1))
                if args:
                    bash_write_shaped = True
                    tok = strip_quotes(args[-1])
                    if is_dynamic(tok):
                        bash_unresolvable = True
                    else:
                        bash_literal_targets.append(tok)

            for si_m in re.finditer(r"\b(?:sed|perl)\b([^\n;&|]*-i[^\n;&|]*)", command):
                bash_write_shaped = True
                for tok in non_flag_args(si_m.group(1)):
                    if tok == "-i":
                        continue
                    tok = strip_quotes(tok)
                    if is_dynamic(tok):
                        bash_unresolvable = True
                    else:
                        bash_literal_targets.append(tok)

    # An unresolvable target only matters (routes the call into the
    # state-file check) if the command was write-shaped at all. A command
    # with no write-shaped construct is never treated as reaching the state
    # file just because it contains some unrelated unresolvable token.
    bash_unresolvable = bash_unresolvable and bash_write_shaped
    candidates.extend(bash_literal_targets)

state_path_real = resolve(state_name)

touches_state = bash_unresolvable
if not touches_state:
    for c in candidates:
        c_real = resolve(c)
        if c_real is not None and state_path_real is not None and c_real == state_path_real:
            touches_state = True
            break

if not touches_state:
    allow()

# --- load transition rules -------------------------------------------------

def load_rows():
    """Returns (rows, error). rows is a list of (frm, to, actor, precond)
    tuples; error is None on success or a human-readable reason string."""
    if not rules_file:
        return None, "no transition rules file is configured"
    try:
        with open(rules_file, encoding="utf-8-sig") as fh:
            text = fh.read(1 << 20)
    except OSError as e:
        return None, "transition-rules.md at %s could not be read (%s)" % (rules_file, e)
    if not text.strip():
        return None, "transition-rules.md at %s is empty" % rules_file
    rows = []
    for line in text.splitlines():
        line = line.strip()
        if not line or "|" not in line or line.startswith("#"):
            continue
        parts = [p.strip() for p in line.strip("|").split("|")]
        if len(parts) != 4:
            continue
        if parts[0].lower() == "from" and parts[1].lower() == "to":
            continue
        if set(parts[0]) <= {"-"} or set(parts[1]) <= {"-"}:
            continue
        rows.append(tuple(parts))
    if not rows:
        return None, "transition-rules.md at %s has no parseable rows" % rules_file
    return rows, None

rows, rows_err = load_rows()
if rows_err:
    refuse(
        "review-cycle: refused — the transition rules could not be loaded (%s). No transition may be made until "
        "this is fixed." % rows_err
    )

NONE_STATE = "(none)"

def read_state_file():
    """Returns (text, existed). text is None if the file could not be read
    despite existing (I/O error, decode error) — a real error condition.
    existed is False when the path simply does not exist — NOT an error;
    per the bootstrap convention, a missing state file means the current
    state is the synthetic literal "(none)"."""
    if not state_path_real or not os.path.exists(state_path_real):
        return None, False
    try:
        with open(state_path_real, encoding="utf-8-sig") as fh:
            return fh.read(1 << 20), True
    except (OSError, UnicodeDecodeError):
        return None, True

def current_status(text):
    m = re.findall(r"^status:\s*(.*?)\s*(?:#.*)?$", text, re.M)
    if len(m) != 1:
        return None
    val = m[0].strip()
    return val or None

cur_text, existed = read_state_file()
if not existed:
    # Missing state file: this is the synthetic initial state "(none)",
    # not an error. The write that creates the state file is allowed
    # exactly when "(none) -> <target>" is a row in transition-rules.md.
    cur_status = NONE_STATE
elif cur_text is None:
    refuse(
        "review-cycle: refused — the transition rules could not be loaded: %s could not be read (unreadable), "
        "so the current state is unknown. No transition may be made until this is fixed." % state_name
    )
else:
    cur_status = current_status(cur_text)
    if cur_status is None:
        refuse(
            "review-cycle: refused — the transition rules could not be loaded: %s's `status` field is missing, "
            "duplicated, or unparseable. No transition may be made until this is fixed." % state_name
        )

# For Write/Edit we can read the ATTEMPTED content directly. For Bash (or an
# unresolvable target), the resulting content is not knowable before the
# shell executes, so the attempted status is UNKNOWN and treated
# conservatively: every row whose `from` is the current state is a
# candidate, and the call is allowed only if the current state has at
# least one outgoing row — the write is not required to resolve to one
# specific `to` for this coarser case, since the gate cannot see it.
if tool in ("Write", "Edit"):
    content = tool_input.get("content") if tool == "Write" else tool_input.get("new_string")
    if not isinstance(content, str):
        refuse(
            "review-cycle: refused — this transition is not in the table: could not read the attempted new "
            "content of this write, so the resulting state cannot be determined."
        )
    attempted_status = current_status(content)
    if attempted_status is None:
        refuse(
            "review-cycle: refused — this transition is not in the table: the attempted content's `status` field "
            "is missing, duplicated, or unparseable."
        )
    match = [r for r in rows if r[0] == cur_status and r[1] == attempted_status]
    if not match:
        refuse(
            "review-cycle: refused — this transition is not in the table: %s -> %s is not a row in "
            "transition-rules.md." % (cur_status, attempted_status)
        )
    allow("review-cycle: %s -> %s permitted by transition-rules.md." % (cur_status, attempted_status))
else:
    # Bash (including unresolvable-target case): cannot see the resulting
    # status, so require at least one legal outgoing transition from the
    # current state.
    outgoing = [r for r in rows if r[0] == cur_status]
    if not outgoing:
        refuse(
            "review-cycle: refused — this transition is not in the table: %s has no legal outgoing transition "
            "from state %s, so a Bash-mediated write to it cannot be permitted." % (state_name, cur_status)
        )
    allow(
        "review-cycle: a Bash write reaching %s is permitted — state %s has at least one legal outgoing "
        "transition in transition-rules.md (resulting content not statically verifiable)." % (state_name, cur_status)
    )
PY

exit $?
