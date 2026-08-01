#!/usr/bin/env bash
. "${CLAUDE_PLUGIN_ROOT_CORE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../core" && pwd -P)}/hooks/lib/gate-lib.sh" || { echo "proposal-completeness-gate.sh: cannot source gate-lib.sh" >&2; exit 2; }
gate_trap_fail_closed
# ^ fail-closed trap-at-top, from gate-lib.sh (issue-72): any abnormal
#   termination before the verdict logic runs is forced to exit 2 (DENY).
#   Installed as the FIRST executable statement, above set -uo pipefail.
#
# PreToolUse(Write|Edit|MultiEdit|NotebookEdit|Bash) sibling gate for the `review` role —
# issue #39 (b.5), matching the freelunch-grade structural completeness bar
# the `core` fan-out plugin holds a chunk to before accepting it as complete,
# applied here to this role's own phase-1 proposal
# (docs/issue-<n>/proposals/review.md) — migrated to the gate-house standard
# (core issue #72) per docs/issue-42/proposals/conformance-review.md.
# Inspects the PROPOSED content (reconstructed via
# gate_lib.gate_reconstruct_write, which honors Edit/MultiEdit's own
# replace_all flag) for five structural requirements; any single missing
# requirement is refused, named in the deny message:
#
#   a. a Request heading
#   b. a Constraints heading with a non-trivial body
#   c. at least one "adopt(ed)" claim that also carries a source-attribution
#      pattern (link, docs/ path, issue-<n>/issue #<n>) in the SAME sentence
#      or an immediately adjacent list item — not merely the same
#      (potentially multi-topic) paragraph (issue #42's semantic upgrade:
#      a paragraph that mentions "adopted" once and links to something
#      unrelated elsewhere in the same paragraph no longer passes)
#   d. an explicit adopted-vs-skipped split (both sides present, each with
#      at least one line of content)
#   e. a closing "How this will be judged" section naming at least one
#      externally-verifiable condition
#
# This is a phase-1 structural probe only — it does not check the adoption
# claims for truth, only that the document's shape forces them to be made
# with a citable source and a judgeable, closing condition. A Bash tool call
# whose command string names this role's own proposal path is refused
# outright — this gate cannot reconstruct a Bash command's effect on file
# content, so it does not silently let such a write through uninspected.
#
# Kill switch: export REVIEW_PROPOSAL_COMPLETENESS_GATE_OFF=1 (any value
# other than a recognized on-spelling 1/true/yes/on leaves the gate ACTIVE).
set -uo pipefail

deny() { echo "review-proposal-completeness: refused — $*" >&2; exit 2; }

gate_kill_switch_active "${REVIEW_PROPOSAL_COMPLETENESS_GATE_OFF:-}" || { trap - EXIT; exit 0; }

command -v python3 >/dev/null 2>&1 || deny "proposal-completeness-gate.sh requires python3, which is not on PATH; denying rather than allowing an uninspectable write."

payload="$(cat 2>/dev/null || true)"

_plausible() { [ -n "$1" ] && [ -d "$1" ] && { [ -e "$1/.git" ] || [ -f "$1/docs/specs/role-handoff-contract.md" ]; }; }
root=""
if [ -n "${CLAUDE_PROJECT_DIR:-}" ] && _plausible "$CLAUDE_PROJECT_DIR"; then
  root="$(cd "$CLAUDE_PROJECT_DIR" 2>/dev/null && pwd -P)"
fi
[ -z "$root" ] && root="$(git -C "$(pwd -P)" rev-parse --show-toplevel 2>/dev/null || true)"
[ -z "$root" ] && deny "no project root could be determined; denying rather than allowing an indeterminate-root write."

RPC_PAYLOAD="$payload" RPC_ROOT="$root" GATE_LIB_PY="$GATE_LIB_PY" python3 <<'PY'
import sys as _fc_sys  # fail-closed-on-internal-error
try:
    import importlib.util, os, re, sys

    def deny(m):
        sys.stderr.write("review-proposal-completeness: refused — " + m + "\n"); sys.exit(2)

    _spec = importlib.util.spec_from_file_location("gate_lib", os.environ["GATE_LIB_PY"])
    gate_lib = importlib.util.module_from_spec(_spec)
    _spec.loader.exec_module(gate_lib)

    raw = os.environ.get("RPC_PAYLOAD", "")
    ev = gate_lib.gate_parse_json_or_deny(raw, deny)

    root = os.path.realpath(os.environ["RPC_ROOT"]).replace("\\", "/")
    PROPOSAL_RE = re.compile(r'^docs/issue-[0-9]+/proposals/review\.md$')

    tool = ev.get("tool_name")

    if tool == "Bash":
        ti_bash = ev.get("tool_input")
        cmd = ti_bash.get("command") if isinstance(ti_bash, dict) else None
        if not isinstance(cmd, str):
            sys.exit(0)
        for tok in re.findall(r'[\w./~-]+', cmd):
            rel_tok = gate_lib.gate_normalize_path(root, tok)
            if rel_tok and PROPOSAL_RE.match(rel_tok):
                deny("a Bash command appears to target %s directly; this gate can only "
                     "judge Write/Edit/MultiEdit content, so a Bash-authored write to "
                     "this role's own phase-1 proposal is refused rather than silently "
                     "passed through uninspected." % rel_tok)
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
    if not (rel and PROPOSAL_RE.match(rel)):
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

    missing = []

    lines = content.splitlines()
    heading_re = re.compile(r'^\s{0,3}#{1,6}\s+(.*\S)\s*$')
    headings = []  # (line_index, line, title)
    for i, ln in enumerate(lines):
        m = heading_re.match(ln)
        if m:
            headings.append((i, ln, m.group(1).strip()))

    def section_body(title_pattern):
        """Body text following the first heading whose title matches
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

    # (c) issue #42 structural upgrade: an "adopt(ed)" claim and a
    # source-attribution pattern must co-occur in the SAME SENTENCE, or in
    # an immediately adjacent list item — not merely anywhere in the same
    # (potentially multi-topic) paragraph.
    ADOPT_RE = re.compile(r'\badopt(?:ed|s|ion)?\b', re.I)
    SOURCE_RE = re.compile(r'\[[^\]]+\]\([^)]+\)|https?://\S+|docs/\S+|issue[\s-]?#?\d+', re.I)
    SENTENCE_SPLIT = re.compile(r'(?<=[.!?])\s+(?=[A-Z0-9`*_"\[])')
    BULLET_RE = re.compile(r'^\s*(?:[-*]|\d+[.)])\s+\S')

    def sourced_adopt_present(text):
        for para in re.split(r'\n\s*\n', text):
            para_lines = para.splitlines()
            bullet_idxs = [i for i, ln in enumerate(para_lines) if BULLET_RE.match(ln)]
            if bullet_idxs:
                for pos, i in enumerate(bullet_idxs):
                    item = para_lines[i]
                    if not ADOPT_RE.search(item):
                        continue
                    neighborhood = [item]
                    if pos + 1 < len(bullet_idxs):
                        neighborhood.append(para_lines[bullet_idxs[pos + 1]])
                    if pos - 1 >= 0:
                        neighborhood.append(para_lines[bullet_idxs[pos - 1]])
                    if SOURCE_RE.search("\n".join(neighborhood)):
                        return True
            for sentence in SENTENCE_SPLIT.split(para):
                if ADOPT_RE.search(sentence) and SOURCE_RE.search(sentence):
                    return True
        return False

    if not sourced_adopt_present(content):
        missing.append("sourced adoption claim (an \"adopt\"/\"adopted\" claim naming a "
                        "source — link, docs/ path, or issue-<n>/issue #<n> — in the same "
                        "sentence or an immediately adjacent list item)")

    # (d) Explicit adopt-vs-skip split: an "adopted" list-like section AND a
    # "skipped"/"out of scope" list-like section, each with >=1 content line.
    def has_list_section(title_pattern):
        body = section_body(title_pattern)
        if body is None:
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
            missing.append('"How this will be judged" section (present but names no '
                            'externally-verifiable condition: file exists/exit code/gate/'
                            'field presence/test/pass)')

    if missing:
        deny("phase-1 proposal at %s is missing required structure: %s. Per issue #39 "
             "(b.5)/#30 (a), a phase-1 proposal must carry Request, Constraints "
             "(non-trivial), a sourced adoption claim (source in the same sentence or an "
             "adjacent list item), an explicit adopt-vs-skip split, and a closing "
             "How-this-will-be-judged section with a verifiable condition."
             % (rel, "; ".join(missing)))

    sys.exit(0)
except SystemExit:
    raise
except Exception as _fc_e:  # fail-closed-on-internal-error
    _fc_sys.stderr.write("review-proposal-completeness: refused — fail-closed: internal error: %r\n" % (_fc_e,))
    _fc_sys.exit(2)
PY
_rc=$?
if [ "$_rc" -ne 0 ] && [ "$_rc" -ne 2 ]; then
  echo "review-proposal-completeness: refused — fail-closed: internal error (judge exited $_rc; mapping non-0/2 to DENY)." >&2
  exit 2
fi
exit "$_rc"
