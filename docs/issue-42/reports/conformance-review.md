---
subject: issue-42
role: review
loop_state: landed
code_under_review: 5a730a5
---

# Phase-2 delivery record: gate A+ remediation via gate-lib reference adoption (issue #42)

## What was done

Implemented the approved proposal
(`docs/issue-42/proposals/conformance-review.md`, APPROVE
issue-42/conformance-review) exactly as frozen:

| Area | Change |
|---|---|
| All four `*-gate.sh` | Source `core`'s `gate-lib.sh` (issue #72, landed at `tokenmaxxxer-core@22a7cad`) by reference (`. "${CLAUDE_PLUGIN_ROOT_CORE:-...$(../../core)}"/hooks/lib/gate-lib.sh`), load `gate-lib.py` via `importlib` in the Python payload. Migrated: fail-closed trap (`gate_trap_fail_closed`), kill-switch check (`gate_kill_switch_active` — unrecognized values now stay ACTIVE, not disable), JSON parse (`gate_parse_json_or_deny`), path normalize (`gate_normalize_path`), and Write/Edit/MultiEdit reconstruction (`gate_reconstruct_write`, honoring each edit's own `replace_all`). Added a `Bash`-tool branch to all four gates: a `Bash` command whose target token resolves (via `gate_normalize_path`) to the gate's own protected path is refused outright — content cannot be reconstructed from a shell command, so it fails closed instead of passing through unjudged (closes the class of bypass `tests/deny-only-check.sh`'s own header comment names). |
| `review-traceability/hooks/traceability-gate.sh` | Semantic upgrade: a phase-2 verdict now only counts when it sits on a `verdict:`-labeled field line (`VERDICT_LINE` regex), never a bare word-boundary match anywhere in prose — eliminates the false-positive class named in the issue, where an ordinary English sentence using one of the five verdict words with no label attached was mistaken for a real verdict. |
| `review-proposal-completeness/hooks/proposal-completeness-gate.sh` | Semantic upgrade: the sourced-adoption check now requires the "adopt(ed)" claim and the source-attribution pattern to co-occur in the SAME sentence or an immediately adjacent bullet-list item, not merely the same (potentially multi-topic) paragraph. |
| `review-severity/hooks/severity-gate.sh`, `review-record-norm/hooks/closed-checks-gate.sh` | Kill-switch/reconstruct/path plumbing migrated only — their own value checks (closed vocabulary, sha-prefix match) were already exact-match, not substring scans, and are unchanged (out of scope per the proposal's Constraints). |
| `tests/parse-check.sh` | Default directory changed from the now-empty `review/hooks` to the repo root (recursive `find` already reaches every plugin's `hooks/`/`tests/`), so a no-argument run actually parses all four real gate files instead of silently checking zero. |
| `tests/deny-only-check.sh` | Default `probe_dir` changed the same way. The substance probe itself was redesigned: an "empty record" fixture is core's job (`record-fields-gate.sh`, not vendored here), so it was replaced with a fail-closed-on-malformed-JSON probe run against every discovered `*-gate.sh` — a check this repo's own migrated gates can legitimately be held to, and one that fails loudly (`return 1`, not a silent early "nothing to check") when no gate scripts are found under the probed directory. |
| Each plugin's own `*-gate-test.sh` | Added the gate-house standard's six mandatory case groups (Edit `replace_all:true` against a multiply-occurring string, mixed-`replace_all` MultiEdit, malformed/empty/non-object JSON, unrecognized kill-switch value asserting the gate stays active, absolute + `./`-prefixed path matching the same scope as a relative fixture, a `Bash`-tool write reaching the same target a `Write` call would hit) plus this repo's own semantic-upgrade cases (a fixture on `review-traceability` proving an unlabeled verdict word embedded in ordinary prose no longer trips the gate; a fixture on `review-proposal-completeness` proving an adoption claim and an unrelated citation elsewhere in the same paragraph no longer satisfies the sourced-adoption check). |
| `README.md` | Resynced to the real repo name (`tokenmaxxxer/conformance-review-rulebook`, not `review-agent-rulebook`), the real five-plugin file layout (`review-record-norm/hooks/closed-checks-gate.sh`, not `review/hooks/...`; skills under `review-traceability/`/`review-severity/`, not `review/`), and the real install commands (five separate `plugin install` lines, matching `.claude-plugin/marketplace.json`'s actual plugin names). |

## Why

The issue's own 2026-08-01 code audit (grade B) named four defect
classes: a verdict-detection regex that false-triggers on ordinary
English sentences, silent fail-open on `Edit`/`MultiEdit` reconstruction
ignoring `replace_all`, vacuously-passing repo-level checks after issue
#39's plugin split, and README drift. Core issue #72 landed the shared
fix (`gate-lib.sh` + `gate-lib.py`) for exactly this defect shape across
its own 43-rulebook population; the issue's own precondition named
referencing that library, not re-deriving the fixes, as the required
approach — followed here per `docs/handbooks/canon-scripts.md`'s
reference-not-copy rule (upstream basis:
`docs/issue-42/proposals/conformance-review.md`, APPROVE
issue-42/conformance-review).

## Verification

- `bash tests/run-gate-tests.sh`: **61/61 passed** across all four plugin
  test files (20 traceability + 18 severity + 14 record-norm + 19
  proposal-completeness — up from 33 pre-remediation; the delta is the
  six gate-house mandatory cases per plugin plus the semantic-upgrade
  cases).
- `bash tests/parse-check.sh`: 14 files, all `ok`, exit 0 (previously
  checked 0 files by default; the `review/hooks` default held no
  `*-gate.sh` file post-split).
- `bash tests/deny-only-check.sh`: `permissionDecision` scan clean; the
  redesigned substance probe covers all four gate scripts and confirms
  each fails closed on malformed JSON, exit 0 (previously the probe's
  early return silently reported pass while covering zero real gates).
- `core/hooks/tests/compliance-check.sh <plugin>/hooks`, run against all
  four plugin `hooks/` directories: **all four `ok`**, zero violations
  (previously all four flagged: hand-rolled kill-switch case statement
  without `gate_kill_switch_active`, and `.replace(old, new[, 1])`-shaped
  `Edit`/`MultiEdit` reconstruction without `gate_reconstruct_write`).

closed_checks:
  - check: verdict-regex-false-positive
    code_sha: 5a730a5
  - check: replace-all-ignored-in-edit-multiedit
    code_sha: 5a730a5
  - check: repo-level-checks-vacuous-post-split
    code_sha: 5a730a5
  - check: readme-drift
    code_sha: 5a730a5

## R1: kill-switch fixed to fail-closed on unrecognized values (all four gates)
spec_ref: docs/issue-42/proposals/conformance-review.md#adopted-with-source
evidence: review-traceability/hooks/traceability-gate.sh:41, review-severity/hooks/severity-gate.sh:37, review-record-norm/hooks/closed-checks-gate.sh:44, review-proposal-completeness/hooks/proposal-completeness-gate.sh:41; review-traceability/tests/traceability-gate-test.sh (kill-switch-unrecognized-value-stays-active)
Verdict: Present

## R2: Edit/MultiEdit reconstruction honors replace_all (all four gates)
spec_ref: docs/issue-42/proposals/conformance-review.md#adopted-with-source
evidence: gate_lib.gate_reconstruct_write calls in all four gate scripts; review-traceability/tests/traceability-gate-test.sh (edit-replace-all-multi-occurrence, multiedit-mixed-replace-all)
Verdict: Present

## R3: verdict/adoption semantic checks upgraded to structural adjacency
spec_ref: docs/issue-42/proposals/conformance-review.md#adopted-with-source
evidence: review-traceability/hooks/traceability-gate.sh VERDICT_LINE regex; review-proposal-completeness/hooks/proposal-completeness-gate.sh sourced_adopt_present; both plugins' test files (verdict-word-in-prose-not-a-field, adopt-and-source-same-paragraph-not-adjacent-now-denies)
Verdict: Present

## R4: repo-level checks cover the real post-split layout
spec_ref: docs/issue-42/proposals/conformance-review.md#adopted-with-source
evidence: tests/parse-check.sh:35, tests/deny-only-check.sh:49; this record's Verification section (14 files parsed, 4 gates probed)
Verdict: Present

## R5: mandatory gate-house test cases added, full suite green
spec_ref: docs/issue-42/proposals/conformance-review.md#how-this-will-be-judged
evidence: this record's Verification section (61/61)
Verdict: Present

## R6: README resynced to real repo/layout
spec_ref: docs/issue-42/proposals/conformance-review.md#adopted-with-source
evidence: README.md
Verdict: Present

## Open findings

None. All items in the approved proposal's "How this will be judged"
section are demonstrated in the Verification section above:
`compliance-check.sh` clean on all four plugins, `run-gate-tests.sh`
green including every mandatory gate-house case, `parse-check.sh`/
`deny-only-check.sh` actually exercising all five plugins (not vacuously
passing), and `README.md` matching the real layout. The proposal's own
named out-of-scope items (full CommonMark/AST parsing, rewriting
`severity-gate.sh`/`closed-checks-gate.sh`'s already-exact value checks,
the pre-existing `proposals/review.md`/`reports/(conformance-)?review.md`
filename-pattern mismatch) remain out of scope here, unchanged, per that
proposal's Skipped section.
