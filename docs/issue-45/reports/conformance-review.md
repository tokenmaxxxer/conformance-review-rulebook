---
subject: issue-45
role: review
loop_state: landed
code_under_review: 3a3bdb1
---

# Phase-2 delivery record: gate A+ final closeout — remaining re-audit defects (issue #45)

## What was done

Implemented the approved proposal
(`docs/issue-45/proposals/conformance-review.md`, APPROVE
issue-45/conformance-review) exactly as frozen:

| Area | Change |
|---|---|
| `review-proposal-completeness`, `review-record-norm`, `review-severity`, `review-traceability` `hooks/hooks.json` | Matcher changed from `Write\|Edit\|MultiEdit\|NotebookEdit` to `Write\|Edit\|MultiEdit\|NotebookEdit\|Bash` in all four — the already-implemented, already-tested `Bash` branch in each gate script is now dispatched to in production, not just reachable from a test file that invoked the script directly. |
| Same four `*-gate.sh` | `if tool not in ("Write", "Edit", "MultiEdit"): sys.exit(0)` extended to include `"NotebookEdit"`; `path = ti.get("file_path")` changed to fall back to `ti.get("notebook_path")` for a `NotebookEdit` call. `gate_lib.gate_reconstruct_write` (core issue-72/75, applied by reference, not reimplemented) already covers `NotebookEdit` — returns the edited cell's `new_source` for `edit_mode` `insert`/`replace` — so the existing content-check logic now actually runs against `NotebookEdit` content instead of silently exiting 0. |
| Same four `*-gate.sh` | Fixed the fail-open source-guard defect (core issue-75's confirmed shape): `. ".../gate-lib.sh"` had **no `\|\|` guard** on the source line in all four gates — a missing/unreachable core would run no code past that line (including no `gate_*` function definitions), and every `gate_kill_switch_active ... \|\| { exit 0; }` call downstream would then read the resulting "command not found" (rc 127) as the kill switch being off, silently allowing everything through. Added `\|\| { echo "<gate>: cannot source gate-lib.sh" >&2; exit 2; }` to the source line in all four, matching core's own `directive.sh`/`record-fields-gate.sh` guard shape exactly (applied by reference). |
| `review/hooks/directive.sh` | Same fail-open defect, same fix: the `. ".../role-directive.sh"` source line had no `\|\|` guard either — added `\|\| { echo "directive.sh: cannot source role-directive.sh" >&2; exit 2; }`. |
| `install.sh` | `GITHUB_REPO="tokenmaxxxer/review-agent-rulebook"` corrected to `"tokenmaxxxer/conformance-review-rulebook"` (the actual repo, confirmed via `git remote -v`). `PLUGINS` array and the header comment both extended to include `review-agent-env` (six plugins total), once (below) `review-agent-env` had a resolved, non-ghost `dependencies` field and a marketplace entry to install against. |
| `review-agent-env/.claude-plugin/plugin.json` | `"dependencies": ["review-cycle"]` was a ghost reference — no plugin named `review-cycle` exists in this repo; `review-cycle` was the pre-issue-#39-split monolith's plugin name (confirmed via `docs/proposals/2026-07-28-role-workflow-plugins.md`'s file list, which still names `review-agent-rulebook/review-cycle/...` paths from before the rename+split). Corrected to the five real plugins issue #39 split it into: `review`, `review-traceability`, `review-severity`, `review-record-norm`, `review-proposal-completeness`. |
| `.claude-plugin/marketplace.json` | Added the missing `review-agent-env` plugin entry (source `./review-agent-env`, description matching its corrected dependency bundle) — it was on disk but unregistered. |
| `README.md` | "Five self-contained plugins" section updated to note the sixth (`review-agent-env`, no code of its own) with a description line; install-command list gained the `review-agent-env@tokenmaxxxer-review` line; the gate-house-standard paragraph's tool list updated from "Write/Edit/MultiEdit/Bash reconstruction" to "Write/Edit/MultiEdit/NotebookEdit/Bash reconstruction" to match the parity fix. |
| Each of the four plugins' own `*-gate-test.sh` | Added a `missing-core` case (mirrors core issue-75's own `run-gate-lib-tests.sh` group 7: `CLAUDE_PLUGIN_ROOT_CORE` pointed at a nonexistent path must deny, not silently allow) and two `NotebookEdit` cases (one that must deny on content that would fail the gate's existing check, one that must allow on content that would pass it) — proving the new branch is real coverage, not a second silent no-op. |
| Four `*-gate.sh` header comments | `PreToolUse(Write\|Edit\|MultiEdit\|Bash)` corrected to `PreToolUse(Write\|Edit\|MultiEdit\|NotebookEdit\|Bash)` to match the matcher/code parity fix (documentation accuracy, no behavior change). |

## Why

The 2026-08-01 re-audit (grade A-) found the `Bash`-deny logic
implemented and tested but never dispatched to (matcher gap),
`NotebookEdit` advertised in the matcher but silently allowed through in
code, and `install.sh` naming a renamed repo while omitting
`review-agent-env`. Auditing this session for full hooks.json/code
parity (proposal item (d)) also surfaced the ghost `review-cycle`
dependency and the missing source-guard on all five `*.sh` files that
source core by reference — the exact fail-open shape core issue #75
already fixed in `core`'s own gates, applied here by reference rather
than re-derived (upstream basis: `docs/issue-45/proposals/conformance-review.md`,
APPROVE issue-45/conformance-review; core issue #75 landed at
`tokenmaxxxer-core@f61d52f`).

## Verification

- `bash tests/run-gate-tests.sh`: **4 suites passed, 0 failed** — 21
  (severity) + 17 (record-norm) + 23 (traceability) + 22
  (proposal-completeness) = 83 cases, up from 61 pre-remediation (the
  delta is one `missing-core` + two `NotebookEdit` cases per plugin).
- `bash tests/parse-check.sh`: 14 files, all `ok`, exit 0.
- `bash tests/deny-only-check.sh`: `permissionDecision` scan clean; all
  four gates confirmed fail-closed on malformed JSON.
- `core/hooks/tests/compliance-check.sh <plugin>/hooks`, run by reference
  against `tokenmaxxxer-core@f61d52f` (core issue #75's landed shape),
  against all five plugins with a `hooks/` directory: **`review-proposal-completeness`,
  `review-record-norm`, `review-severity`, `review-traceability` all
  `ok`**; `review` reports "no `*-gate.sh` files found — nothing to
  check" (correct — it has no PreToolUse gate, only `directive.sh`/
  `state.sh` at SessionStart, out of scope for this compliance detector
  by construction, per the proposal's (d)).
- Matcher/code parity re-checked both directions post-fix: every
  `hooks.json` matcher entry (`Write`, `Edit`, `MultiEdit`, `NotebookEdit`,
  `Bash`) now maps to a real, tested branch in all four gate scripts; no
  branch keyed on `tool_name` exists without a matcher entry dispatching
  to it.
- README/manifest re-grepped after this session's own edits (per the
  proposal's (f)(1) note that the check should be re-run once phase-2
  edits land, since edits to `install.sh`/`README.md` could in principle
  introduce a typo'd name): no old-role-name or ghost-file-path hits;
  `review-cycle`'s only remaining hits are inside historical
  `docs/proposals/*.md`/`docs/issue-*/proposals/*.md` files (frozen
  historical record, not live config) — zero hits in `README.md`,
  `.claude-plugin/marketplace.json`, or any `plugin.json`.

closed_checks:
  - check: bash-deny-dead-branch
    code_sha: 3a3bdb1
  - check: notebookedit-noop
    code_sha: 3a3bdb1
  - check: install-sh-stale-repo-name
    code_sha: 3a3bdb1
  - check: hooks-json-code-full-parity
    code_sha: 3a3bdb1
  - check: missing-core-test-and-compliance-record
    code_sha: 3a3bdb1
  - check: readme-manifest-ghost-references
    code_sha: 3a3bdb1

## R1: Bash registered in all four matchers, dead branch now reachable
spec_ref: docs/issue-45/proposals/conformance-review.md#a-bash-deny-dead-branch--4-plugins
evidence: review-proposal-completeness/hooks/hooks.json:5, review-record-norm/hooks/hooks.json:5, review-severity/hooks/hooks.json:5, review-traceability/hooks/hooks.json:5 (all `Write|Edit|MultiEdit|NotebookEdit|Bash`); each plugin's own `*-gate-test.sh` `bash-write-same-target-as-write`/`bash-write-unrelated-target` cases exercise the same code path the matcher now dispatches to
Verdict: Present

## R2: NotebookEdit implemented as a real content-check branch, not a no-op
spec_ref: docs/issue-45/proposals/conformance-review.md#b-notebookedit-no-op--4-plugins
evidence: review-proposal-completeness/hooks/proposal-completeness-gate.sh:93-101, review-record-norm/hooks/closed-checks-gate.sh:97-106, review-severity/hooks/severity-gate.sh:83-92, review-traceability/hooks/traceability-gate.sh:90-99 (tool tuple + notebook_path fallback); all four `*-gate-test.sh` files' `notebookedit-*` cases (one deny, one allow per plugin)
Verdict: Present

## R3: install.sh repo name and plugin list corrected
spec_ref: docs/issue-45/proposals/conformance-review.md#c-installsh-stale-repo-name--missing-plugin
evidence: install.sh:2-6 (header), install.sh:15 (GITHUB_REPO), install.sh:16 (PLUGINS array, six entries including review-agent-env)
Verdict: Present

## R4: hooks.json/code full parity, both directions, zero gaps
spec_ref: docs/issue-45/proposals/conformance-review.md#d-hooksjsoncode-full-parity--audit-method-for-phase-2
evidence: this record's Verification section (matcher->code and code->matcher re-check); review's own hooks.json (SessionStart only) and review-agent-env (no hooks.json) confirmed out of scope by construction, per the proposal
Verdict: Present

## R5: missing-core mandatory test case added, full suite green, compliance-check pass recorded
spec_ref: docs/issue-45/proposals/conformance-review.md#e-missing-core-test-case--compliance-check-record
evidence: this record's Verification section (83/83 run-gate-tests.sh, compliance-check.sh ok on all four gated plugins, pulled by reference from tokenmaxxxer-core@f61d52f/issue #75's landed gate_bash_write_targets.py + source-guard shape — never reimplemented)
Verdict: Present

## R6: README/manifest zero old-role-name or ghost-file references
spec_ref: docs/issue-45/proposals/conformance-review.md#f-readme--manifest-cleanup
evidence: README.md (six-plugin listing, install commands, tool-coverage line), .claude-plugin/marketplace.json (review-agent-env entry added), review-agent-env/.claude-plugin/plugin.json (dependencies corrected from the ghost review-cycle to the five real split plugins) — this record's Verification section documents the re-grep
Verdict: Present

## R7 (common precondition, applied by reference): source guard on every `. ".../gate-lib.sh"`/`. ".../role-directive.sh"` line
spec_ref: docs/issue-45/proposals/conformance-review.md#constraints (apply core #75 by reference, never reimplement)
evidence: review-proposal-completeness/hooks/proposal-completeness-gate.sh:2, review-record-norm/hooks/closed-checks-gate.sh:2, review-severity/hooks/severity-gate.sh:2, review-traceability/hooks/traceability-gate.sh:2, review/hooks/directive.sh:2 (all five now carry `|| { echo ...; exit 2; }` on the source line, matching tokenmaxxxer-core@f61d52f's own `core/hooks/directive.sh`/`record-fields-gate.sh` guard shape); found during this session's own parity audit (proposal item (d)), not named as a defect in the issue's original three items, but falls under requirement 1's "공통 외" scope once discovered
Verdict: Present

## Open findings

None. All items in the approved proposal's "How this will be judged"
section, plus the issue's four numbered requirements, are demonstrated in
the Verification section above. The proposal's deliberately-out-of-scope
items (re-litigating the issue #39 plugin-split architecture; changing
`review-severity`'s/`review-record-norm`'s existing Write/Edit/MultiEdit
check logic; re-deriving core #75's or on-the-record #182's guard/
injection shapes) remain out of scope here, unchanged, per that
proposal's own "What is deliberately out of scope" section.
