#!/usr/bin/env bash
. "${CLAUDE_PLUGIN_ROOT_CORE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../core" && pwd -P)}/hooks/lib/gate-lib.sh" || { echo "severity-gate.sh: cannot source gate-lib.sh" >&2; exit 2; }
gate_trap_fail_closed
# ^ fail-closed trap-at-top, from gate-lib.sh (issue-72): any abnormal
#   termination before the verdict logic runs is forced to exit 2 (DENY).
#   Installed as the FIRST executable statement, above set -uo pipefail.
#
# PreToolUse(Write|Edit|MultiEdit|NotebookEdit|Bash) sibling gate for the `review` role's
# `review-severity` plugin — migrated to the gate-house standard (core
# issue #72) per docs/issue-42/proposals/conformance-review.md. On a write to
# a phase-2 conformance/review record, inspect any `severity:` field in the
# PROPOSED content (reconstructed via gate_lib.gate_reconstruct_write, which
# honors Edit/MultiEdit's own replace_all flag): its value must be drawn from
# a closed severity-table vocabulary (Chromium 5-band or Microsoft 4-level
# bug-bar) rather than a DREAD-style averaged numeric score. Issue #30 (c)
# names DREAD's abandonment as the specific reason this table-lookup
# methodology, not that one, was adopted. This value check is already an
# exact-vocabulary comparison, not a substring scan — out of scope for
# issue #42's semantic-upgrade requirement; only the kill-switch/
# reconstruct/path plumbing below migrated.
#
# If the proposed content carries no `severity:` field at all, this gate has
# nothing to check and allows the write — severity is optional/conditional.
# A Bash tool call whose command string names this role's own record path is
# refused outright — this gate cannot reconstruct a Bash command's effect on
# file content, so it does not silently let such a write through
# uninspected.
#
# Kill switch: export REVIEW_SEVERITY_GATE_OFF=1 (any value other than a
# recognized on-spelling 1/true/yes/on leaves the gate ACTIVE).
set -uo pipefail

deny() { echo "review-severity: refused — $*" >&2; exit 2; }

gate_kill_switch_active "${REVIEW_SEVERITY_GATE_OFF:-}" || { trap - EXIT; exit 0; }

command -v python3 >/dev/null 2>&1 || deny "severity-gate.sh requires python3, which is not on PATH; denying rather than allowing an uninspectable write."

payload="$(cat 2>/dev/null || true)"

_plausible() { [ -n "$1" ] && [ -d "$1" ] && { [ -e "$1/.git" ] || [ -f "$1/docs/specs/role-handoff-contract.md" ]; }; }
root=""
if [ -n "${CLAUDE_PROJECT_DIR:-}" ] && _plausible "$CLAUDE_PROJECT_DIR"; then
  root="$(cd "$CLAUDE_PROJECT_DIR" 2>/dev/null && pwd -P)"
fi
[ -z "$root" ] && root="$(git -C "$(pwd -P)" rev-parse --show-toplevel 2>/dev/null || true)"
[ -z "$root" ] && deny "no project root could be determined; denying rather than allowing an indeterminate-root write."

RS_PAYLOAD="$payload" RS_ROOT="$root" GATE_LIB_PY="$GATE_LIB_PY" python3 <<'PY'
import sys as _fc_sys  # fail-closed-on-internal-error
try:
    import importlib.util, os, re, sys

    def deny(m):
        sys.stderr.write("review-severity: refused — " + m + "\n"); sys.exit(2)

    _spec = importlib.util.spec_from_file_location("gate_lib", os.environ["GATE_LIB_PY"])
    gate_lib = importlib.util.module_from_spec(_spec)
    _spec.loader.exec_module(gate_lib)

    raw = os.environ.get("RS_PAYLOAD", "")
    ev = gate_lib.gate_parse_json_or_deny(raw, deny)

    root = os.path.realpath(os.environ["RS_ROOT"]).replace("\\", "/")
    RECORD_RE = re.compile(r'^docs/issue-[0-9]+/reports/(conformance-)?review\.md$')

    tool = ev.get("tool_name")

    if tool == "Bash":
        ti_bash = ev.get("tool_input")
        cmd = ti_bash.get("command") if isinstance(ti_bash, dict) else None
        if not isinstance(cmd, str):
            sys.exit(0)
        for tok in re.findall(r'[\w./~-]+', cmd):
            rel_tok = gate_lib.gate_normalize_path(root, tok)
            if rel_tok and RECORD_RE.match(rel_tok):
                deny("a Bash command appears to target %s directly; this gate can only "
                     "judge Write/Edit/MultiEdit content, so a Bash-authored write to "
                     "this role's own record is refused rather than silently passed "
                     "through uninspected." % rel_tok)
        sys.exit(0)

    if tool not in ("Write", "Edit", "MultiEdit", "NotebookEdit"):
        sys.exit(0)

    ti = ev.get("tool_input")
    if not isinstance(ti, dict):
        deny("tool_input missing or not an object on a %s call; denying rather than allowing an uninspectable write." % tool)

    path = ti.get("file_path") if tool != "NotebookEdit" else ti.get("notebook_path")
    if not isinstance(path, str) or not path:
        deny("no usable file_path/notebook_path on a %s call; denying rather than allowing an unidentifiable write." % tool)

    rel = gate_lib.gate_normalize_path(root, path)
    if rel is None or not RECORD_RE.match(rel):
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
            "the tool input (tool=%r); denying rather than allowing an uninspectable write."
            % (rel, tool)
        )

    values = re.findall(r"^\s*severity\s*:\s*(.+?)\s*$", content, re.M)
    if not values:
        sys.exit(0)

    CHROMIUM = re.compile(r"^(critical|high|medium|low|unknown)\b(\s*\(s[0-4]\))?$", re.I)
    MSFT = re.compile(r"^(critical|important|moderate|low)\b$", re.I)
    NUMERIC = re.compile(r"^\d+(\.\d+)?(/\d+(\.\d+)?)?$")

    for v in values:
        val = v.strip()
        if CHROMIUM.match(val) or MSFT.match(val):
            continue
        if NUMERIC.match(val):
            deny("severity value %r looks like a DREAD-style numeric/averaged score. "
                 "Issue #30 (c) names DREAD's abandonment as the specific reason this role "
                 "adopted deterministic severity-table lookup instead — cite a Chromium "
                 "5-band (Critical/High/Medium/Low/Unknown) or Microsoft 4-level bug-bar "
                 "(Critical/Important/Moderate/Low) value, not an averaged score." % val)
        deny("severity value %r is not drawn from either closed vocabulary "
             "(Chromium 5-band: Critical/High/Medium/Low/Unknown, optionally with an "
             "(S0)-(S4) suffix; or Microsoft 4-level bug-bar: "
             "Critical/Important/Moderate/Low)." % val)
    sys.exit(0)
except SystemExit:
    raise
except Exception as _fc_e:  # fail-closed-on-internal-error
    _fc_sys.stderr.write("review-severity: refused — fail-closed: internal error: %r\n" % (_fc_e,))
    _fc_sys.exit(2)
PY
_rc=$?
if [ "$_rc" -ne 0 ] && [ "$_rc" -ne 2 ]; then
  echo "review-severity: refused — fail-closed: internal error (judge exited $_rc; mapping non-0/2 to DENY)." >&2
  exit 2
fi
exit "$_rc"
