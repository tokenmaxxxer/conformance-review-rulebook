#!/usr/bin/env bash
. "${CLAUDE_PLUGIN_ROOT_CORE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../core" && pwd -P)}/hooks/lib/gate-lib.sh" || { echo "traceability-gate.sh: cannot source gate-lib.sh" >&2; exit 2; }
gate_trap_fail_closed
# ^ fail-closed trap-at-top, from gate-lib.sh (issue-72): any abnormal
#   termination (failed source, set -u abort, unbound var, etc.) before the
#   verdict logic runs is forced to exit 2 (DENY), since a PreToolUse hook
#   treats any non-2 exit as NON-BLOCKING (fail-open). Installed as the FIRST
#   executable statement, above set -uo pipefail.
#
# PreToolUse(Write|Edit|MultiEdit|NotebookEdit|Bash) gate for the `review-traceability`
# plugin — migrated to the gate-house standard (core issue #72) per
# docs/issue-42/proposals/conformance-review.md.
#
# On a write to a phase-1 proposal (docs/issue-<n>/proposals/review.md) or a
# phase-2 record (docs/issue-<n>/reports/(conformance-)?review.md), inspect
# the PROPOSED content (reconstructed via gate_lib.gate_reconstruct_write,
# which honors Edit/MultiEdit's own replace_all flag):
#   - phase 1: require a requirement list (numbered/bulleted enumeration) or
#     an explicit "sampling derivation" statement.
#   - phase 2: every genuine verdict — a `verdict:`-labeled field line, never
#     a bare word-boundary match anywhere in prose (issue #42: eliminates the
#     "surface area"/"no test data present" false-positive class) — must sit
#     in a block that also carries a spec_ref: field, and — unless the
#     verdict is Unverifiable — an evidence: field.
# A Bash tool call whose command string names this role's own proposal/
# record path is refused outright: this gate cannot reconstruct a Bash
# command's effect on file content, so it cannot judge such a write and does
# not silently let it through uninspected (issue #42; the deny-only-check.sh
# incident this rulebook already guards against — a Bash write bypassing a
# Write/Edit/MultiEdit-scoped gate).
# Never judges the correctness of a verdict or evidence argument, or reviewer
# independence — structural field-copresence only.
#
# Kill switch: export REVIEW_TRACEABILITY_GATE_OFF=1 (any value other than a
# recognized on-spelling 1/true/yes/on leaves the gate ACTIVE, including an
# unrecognized/garbage value — gate_kill_switch_active's fixed default).
set -uo pipefail

deny() { echo "review-traceability: refused — $*" >&2; exit 2; }

gate_kill_switch_active "${REVIEW_TRACEABILITY_GATE_OFF:-}" || { trap - EXIT; exit 0; }

command -v python3 >/dev/null 2>&1 || deny "traceability-gate.sh requires python3, which is not on PATH; denying rather than allowing an uninspectable write."

payload="$(cat 2>/dev/null || true)"

_plausible() { [ -n "$1" ] && [ -d "$1" ] && { [ -e "$1/.git" ] || [ -f "$1/docs/specs/role-handoff-contract.md" ]; }; }
root=""
if [ -n "${CLAUDE_PROJECT_DIR:-}" ] && _plausible "$CLAUDE_PROJECT_DIR"; then
  root="$(cd "$CLAUDE_PROJECT_DIR" 2>/dev/null && pwd -P)"
fi
[ -z "$root" ] && root="$(git -C "$(pwd -P)" rev-parse --show-toplevel 2>/dev/null || true)"
[ -z "$root" ] && deny "no project root could be determined; denying rather than allowing an indeterminate-root write."

RT_PAYLOAD="$payload" RT_ROOT="$root" GATE_LIB_PY="$GATE_LIB_PY" python3 <<'PY'
import sys as _fc_sys  # fail-closed-on-internal-error
try:
    import importlib.util, os, re, sys

    def deny(m):
        sys.stderr.write("review-traceability: refused — " + m + "\n"); sys.exit(2)

    _spec = importlib.util.spec_from_file_location("gate_lib", os.environ["GATE_LIB_PY"])
    gate_lib = importlib.util.module_from_spec(_spec)
    _spec.loader.exec_module(gate_lib)

    raw = os.environ.get("RT_PAYLOAD", "")
    ev = gate_lib.gate_parse_json_or_deny(raw, deny)

    root = os.path.realpath(os.environ["RT_ROOT"]).replace("\\", "/")
    PHASE1_RE = re.compile(r'^docs/issue-[0-9]+/proposals/review\.md$')
    PHASE2_RE = re.compile(r'^docs/issue-[0-9]+/reports/(conformance-)?review\.md$')

    tool = ev.get("tool_name")

    if tool == "Bash":
        ti_bash = ev.get("tool_input")
        cmd = ti_bash.get("command") if isinstance(ti_bash, dict) else None
        if not isinstance(cmd, str):
            sys.exit(0)
        for tok in gate_lib.gate_bash_write_targets(cmd) if hasattr(gate_lib, "gate_bash_write_targets") else re.findall(r'[\w./~-]+', cmd):
            rel_tok = gate_lib.gate_normalize_path(root, tok)
            if rel_tok and (PHASE1_RE.match(rel_tok) or PHASE2_RE.match(rel_tok)):
                deny("a Bash command appears to target %s directly; this gate can only judge "
                     "Write/Edit/MultiEdit content, so a Bash-authored write to this role's own "
                     "proposal/record is refused rather than silently passed through "
                     "uninspected." % rel_tok)
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
    if rel is None:
        sys.exit(0)  # resolves outside the project root — not this gate's business

    phase1 = bool(PHASE1_RE.match(rel))
    phase2 = bool(PHASE2_RE.match(rel))
    if not (phase1 or phase2):
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
            "the tool input (tool=%r). Write the full document with Write, or use an "
            "Edit/MultiEdit whose old_string(s) match the file on disk, so it can be checked."
            % (rel, tool)
        )

    if phase1:
        bullet_hits = len(re.findall(r'^\s*[-*]\s+\S', content, re.M))
        numbered_hits = len(re.findall(r'^\s*\d+[.)]\s+\S', content, re.M))
        has_list = (bullet_hits + numbered_hits) >= 2
        has_sampling = bool(re.search(r'sampling derivation', content, re.I))
        if not (has_list or has_sampling):
            deny("phase-1 mode (proposals/review.md) requires a "
                 "requirement list (numbered or bulleted enumeration) or a stated "
                 "sampling derivation; neither was found in the proposed content.")
        sys.exit(0)

    # phase 2 — structural upgrade (issue #42): a verdict only counts when it
    # sits ON a `verdict:`-labeled field line, never a bare word-boundary
    # match anywhere in prose ("a broad surface area", "no test data
    # present").
    VERDICT_LINE = re.compile(r'(?im)^[ \t]*verdict:[ \t]*(Present|Surface|Absent|Incorrect|Unverifiable)\b')
    matches = list(VERDICT_LINE.finditer(content))
    if not matches:
        sys.exit(0)

    # Split content into blocks on blank lines or markdown headers.
    blocks = re.split(r'(?:\n\s*\n)|(?=^#{1,6}\s)', content, flags=re.M)
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
            deny("phase-2 verdict '%s' (on a verdict: field) found without a spec_ref: "
                 "field in its surrounding block; every requirement's verdict must "
                 "name the spec locator it was checked against (issues #30/#37/#38)."
                 % verdict)
        if verdict.lower() != "unverifiable":
            has_evidence = bool(re.search(r'evidence\s*:', block))
            if not has_evidence:
                deny("phase-2 verdict '%s' (on a verdict: field) found without an "
                     "evidence: field in its surrounding block; every non-Unverifiable "
                     "verdict must name the artifact pointer it was checked against "
                     "(issues #30/#37/#38)." % verdict)

    sys.exit(0)
except SystemExit:
    raise
except Exception as _fc_e:  # fail-closed-on-internal-error
    _fc_sys.stderr.write("review-traceability: refused — fail-closed: internal error: %r\n" % (_fc_e,))
    _fc_sys.exit(2)
PY
_rc=$?
if [ "$_rc" -ne 0 ] && [ "$_rc" -ne 2 ]; then
  echo "review-traceability: refused — fail-closed: internal error (judge exited $_rc; mapping non-0/2 to DENY)." >&2
  exit 2
fi
exit "$_rc"
