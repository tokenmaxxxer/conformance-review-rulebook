#!/usr/bin/env bash
. "${CLAUDE_PLUGIN_ROOT_CORE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../core" && pwd -P)}/hooks/lib/gate-lib.sh"
gate_trap_fail_closed
# ^ fail-closed trap-at-top, from gate-lib.sh (issue-72): any abnormal
#   termination before the verdict logic runs is forced to exit 2 (DENY).
#   Installed as the FIRST executable statement, above set -uo pipefail.
#
# PreToolUse(Write|Edit|MultiEdit|Bash) sibling gate for the `review` role —
# §16 — migrated to the gate-house standard (core issue #72) per
# docs/issue-42/proposals/conformance-review.md. On a write to review's own
# record, inspect any `closed_checks:` entries in the PROPOSED content
# (reconstructed via gate_lib.gate_reconstruct_write, which honors
# Edit/MultiEdit's own replace_all flag): each entry's `code_sha` must equal
# the code sha currently under review. A check closed on a different sha
# does not count as closed (§16) — refuse the write; it must be re-derived,
# not cited. This value check is already an exact-value (sha-prefix)
# comparison, not a substring scan — out of scope for issue #42's
# semantic-upgrade requirement; only the kill-switch/reconstruct/path
# plumbing below migrated.
#
# Current code sha resolution order:
#   1. a `code_under_review:` field in the proposed content, else
#   2. an `upstream:`/`upstream_code_sha:` field naming the code sha, else
# If closed_checks entries exist but no current sha can be determined, FAIL
# CLOSED (refuse) — never allow an uncomparable cite-and-skip.
# A Bash tool call whose command string names this role's own record path is
# refused outright — this gate cannot reconstruct a Bash command's effect on
# file content, so it does not silently let such a write through
# uninspected.
#
# Kill switch: export REVIEW_CYCLE_DISABLE=1 (alias: REVIEW_RECORD_NORM_GATE_OFF=1).
# Either variable holding a recognized on-spelling (1/true/yes/on) disables
# the gate; any other value on either — including unrecognized garbage —
# leaves it ACTIVE.
set -uo pipefail

deny() { echo "review-cycle: refused — $*" >&2; exit 2; }

{ gate_kill_switch_active "${REVIEW_CYCLE_DISABLE:-}" && gate_kill_switch_active "${REVIEW_RECORD_NORM_GATE_OFF:-}"; } || { trap - EXIT; exit 0; }

command -v python3 >/dev/null 2>&1 || deny "closed-checks-gate.sh requires python3, which is not on PATH; denying rather than allowing an uninspectable write."

payload="$(cat 2>/dev/null || true)"

state_name="${REVIEW_RECORD_NAME:-review-record.md}"

_plausible() { [ -n "$1" ] && [ -d "$1" ] && { [ -e "$1/.git" ] || [ -f "$1/docs/specs/role-handoff-contract.md" ]; }; }
root=""
if [ -n "${CLAUDE_PROJECT_DIR:-}" ] && _plausible "$CLAUDE_PROJECT_DIR"; then
  root="$(cd "$CLAUDE_PROJECT_DIR" 2>/dev/null && pwd -P)"
fi
[ -z "$root" ] && root="$(git -C "$(pwd -P)" rev-parse --show-toplevel 2>/dev/null || true)"
[ -z "$root" ] && deny "no project root could be determined; denying rather than allowing an indeterminate-root write."

RC_PAYLOAD="$payload" RC_ROOT="$root" RC_STATE_NAME="$state_name" GATE_LIB_PY="$GATE_LIB_PY" python3 <<'PY'
import sys as _fc_sys  # fail-closed-on-internal-error
try:
    import importlib.util, os, posixpath, re, sys

    def deny(m):
        sys.stderr.write("review-cycle: refused — " + m + "\n"); sys.exit(2)

    _spec = importlib.util.spec_from_file_location("gate_lib", os.environ["GATE_LIB_PY"])
    gate_lib = importlib.util.module_from_spec(_spec)
    _spec.loader.exec_module(gate_lib)

    raw = os.environ.get("RC_PAYLOAD", "")
    ev = gate_lib.gate_parse_json_or_deny(raw, deny)

    root = os.path.realpath(os.environ["RC_ROOT"]).replace("\\", "/")
    state_name = os.environ.get("RC_STATE_NAME") or "review-record.md"
    OWN_RECORD_RE = re.compile(r'^docs/issue-[0-9]+/reports/review\.md$')

    def is_own_record(rel):
        if rel is None:
            return False
        if OWN_RECORD_RE.match(rel):
            return True
        return posixpath.basename(rel) == state_name

    tool = ev.get("tool_name")

    if tool == "Bash":
        ti_bash = ev.get("tool_input")
        cmd = ti_bash.get("command") if isinstance(ti_bash, dict) else None
        if not isinstance(cmd, str):
            sys.exit(0)
        for tok in re.findall(r'[\w./~-]+', cmd):
            rel_tok = gate_lib.gate_normalize_path(root, tok)
            if is_own_record(rel_tok):
                deny("a Bash command appears to target %s directly; this gate can only "
                     "judge Write/Edit/MultiEdit content, so a Bash-authored write to "
                     "this role's own record is refused rather than silently passed "
                     "through uninspected." % rel_tok)
        sys.exit(0)

    if tool not in ("Write", "Edit", "MultiEdit"):
        sys.exit(0)

    ti = ev.get("tool_input")
    if not isinstance(ti, dict):
        deny("tool_input missing or not an object on a %s call; denying rather than allowing an uninspectable write." % tool)

    path = ti.get("file_path")
    if not isinstance(path, str) or not path:
        deny("no usable file_path on a %s call; denying rather than allowing an unidentifiable write." % tool)

    rel = gate_lib.gate_normalize_path(root, path)
    if not is_own_record(rel):
        sys.exit(0)

    abs_path = root + "/" + rel if rel else root
    current = None
    if os.path.isfile(abs_path):
        try:
            with open(abs_path, encoding="utf-8-sig") as fh:
                current = fh.read(1 << 20)
        except OSError:
            deny("%s exists but cannot be read; failing closed." % rel)

    content, ok = gate_lib.gate_reconstruct_write(tool, ti, current)
    if not ok:
        deny(
            "this write targets %s but the gate cannot determine the resulting content from "
            "the tool input (tool=%r); denying rather than allowing an uninspectable §16 write."
            % (rel, tool)
        )

    cited = re.findall(r"^\s*(?:-\s*)?code_sha:\s*([0-9A-Za-z]+)\s*$", content, re.M)
    if not cited or not re.search(r"closed_checks\s*:", content):
        sys.exit(0)

    current_sha = None
    mcur = re.findall(r"^\s*(?:code_under_review|upstream_code_sha):\s*([0-9A-Za-z]+)\s*$", content, re.M)
    if len(mcur) >= 1:
        current_sha = mcur[0].strip()
    if current_sha is None:
        mup = re.findall(r"^\s*upstream:\s*([0-9A-Fa-f]{7,40})\s*$", content, re.M)
        if len(mup) >= 1:
            current_sha = mup[0].strip()
    if current_sha is None:
        deny("record carries closed_checks entries but no "
             "code_under_review:/upstream_code_sha:/upstream: field naming the code sha under "
             "review. Under per-role issue branches the working HEAD is a docs commit, never "
             "the code under review, so the record must name the sha explicitly. Refusing an "
             "uncomparable cite-and-skip, per §16.")

    def eqsha(a, b):
        a, b = a.strip(), b.strip()
        n = min(len(a), len(b))
        return n >= 7 and a[:n] == b[:n]

    for c in cited:
        if not eqsha(c, current_sha):
            deny("a closed_checks entry cites code_sha %s, but the code currently under "
                 "review is at %s. A check closed on a different sha does not count as "
                 "closed per contract §16 — re-derive it instead of citing." % (c, current_sha))
    sys.exit(0)
except SystemExit:
    raise
except Exception as _fc_e:  # fail-closed-on-internal-error
    _fc_sys.stderr.write("review-cycle: refused — fail-closed: internal error: %r\n" % (_fc_e,))
    _fc_sys.exit(2)
PY
_rc=$?
if [ "$_rc" -ne 0 ] && [ "$_rc" -ne 2 ]; then
  echo "review-cycle: refused — fail-closed: internal error (judge exited $_rc; mapping non-0/2 to DENY)." >&2
  exit 2
fi
exit "$_rc"
