---
subject: issue-45
role: review
loop_state: scope-proposed
---

# Current-state survey — gate A+ final closeout (issue #45)

Phase-1 rigor-floor survey per contract v3 s19. Every claim below is
verified this session by reading the cited file directly (not carried
over unread from the prior research pass referenced in the issue).

## Common prerequisites (confirm landed, do not redo)

- `git log --oneline` on this branch shows `dce15df deliver(...): gate A+
  remediation via gate-lib reference adoption (issue-42) (#44)` and
  `5a730a5 propose(...): gate A+ remediation via gate-lib reference
  adoption (issue-42) (#43)` already merged to `main` — issue #42's
  reference-adoption of core's gate-lib standard is landed in this repo.
  Core issue #75 (gate-lib source guard mandatory + compliance-check
  detection + missing-core mandatory test + `gate_bash_write_targets`
  ported to Python) and on-the-record issue #182
  (`CLAUDE_PLUGIN_ROOT_CORE` injection in `spawn.py`) are landed in the
  external `tokenmaxxxer-core` sibling repo, not this one — this repo
  only ever references core by URL/env var, never vendors it (confirmed
  below in A). Not re-derived further here; phase 2 is the point at
  which core's actual current `gate_bash_write_targets.py` shape gets
  pulled and diffed against.

## A) core/gate-lib is external, referenced not vendored

- `review/hooks/hooks.json` (SessionStart only; see B) sources
  `review/hooks/directive.sh`, which per `README.md:63-70` sources
  `core/hooks/lib/gate-lib.sh` + `gate-lib.py` (core issue #72) "by
  reference — never a vendored copy."
- `README.md:112` documents running `core`'s
  `compliance-check.sh` by reference:
  `"${CLAUDE_PLUGIN_ROOT_CORE:-../core}/hooks/tests/compliance-check.sh" review-traceability/hooks`.
- No local taxonomy or vendored core file exists in this repo (`find`
  over the repo shows no `gate-lib.py`/`gate-lib.sh`/taxonomy file
  outside the five plugin dirs, `tests/`, `docs/`, `install.sh`,
  `README.md`, `.claude-plugin/marketplace.json`).

## B) hooks.json matcher vs. code coverage — verified this session

Actual `hooks.json` paths are at `<plugin>/hooks/hooks.json` (not
`<plugin>/hooks.json`):

| Plugin | hooks.json matcher | Gate script | Bash branch in code? | NotebookEdit branch in code? |
|---|---|---|---|---|
| `review` | `hooks/hooks.json` wires only `SessionStart` (`directive.sh`, `state.sh`) — no `PreToolUse` at all | n/a | n/a | n/a |
| `review-agent-env` | **no `hooks.json` file exists** (only `.claude-plugin/plugin.json`) | n/a | n/a | n/a |
| `review-proposal-completeness` | `hooks/hooks.json:5` = `"Write\|Edit\|MultiEdit\|NotebookEdit"` | `hooks/proposal-completeness-gate.sh` | **Yes**, lines 79-91 (Bash-command path-token scan, denies a Bash write targeting this role's own phase-1 proposal) — but unreachable, hooks.json never dispatches `Bash` here | **No** — line 93 `if tool not in ("Write","Edit","MultiEdit"): sys.exit(0)` treats `NotebookEdit` as a silent no-op despite the matcher advertising it |
| `review-record-norm` | `hooks/hooks.json:5` = same matcher, no `Bash` | `hooks/closed-checks-gate.sh` | Yes (per issue body: lines 83-96) — unreachable | No (line ~97 generic-fallback pattern, same shape) |
| `review-severity` | `hooks/hooks.json:5` = same matcher, no `Bash` | `hooks/severity-gate.sh` | Yes (lines 69-82) — unreachable | No (line ~83) |
| `review-traceability` | `hooks/hooks.json:5` = same matcher, no `Bash` | `hooks/traceability-gate.sh` | Yes (lines 76-89) — unreachable | No (line ~90) |

Confirmed directly by reading `review-proposal-completeness/hooks/proposal-completeness-gate.sh:79-94`
this session: the `Bash` branch is real, complete code (scans command
tokens for a path matching this role's phase-1 proposal path regex and
denies), immediately followed by `sys.exit(0)` — but since
`hooks.json`'s matcher string is `Write|Edit|MultiEdit|NotebookEdit`,
Claude Code's hook dispatcher never invokes this script for a `Bash`
tool call, so the branch is dead code in production, reachable only
under direct/test invocation. The four gate test files (`tests/*-gate-
test.sh` in each of these four plugins) exercise the `Bash` branch
directly by invoking the script, which is why the tests pass despite
the branch being unreachable through the real hook dispatch path — this
is exactly the "implemented and tested but not registered" defect named
in the issue.

Symmetrically, `NotebookEdit` **is** in the matcher for all four gates,
but every one of the four falls through the generic
`if tool not in ("Write","Edit","MultiEdit"): sys.exit(0)` guard,
making the advertised `NotebookEdit` coverage a silent allow-through
no-op — the second defect named in the issue.

`tests/deny-only-check.sh` (repo root) is referenced by `README.md:106`
and, per the issue's prior-pass finding, contains Bash-targeting test
fixtures at the repo root consistent with the four plugins' Bash
branches being test-only-reachable today.

## C) install.sh stale repo name / missing plugin

Read directly, `install.sh`:
- Line 15: `GITHUB_REPO="tokenmaxxxer/review-agent-rulebook"`.
- `git remote -v` on this checkout: `origin
  https://github.com/tokenmaxxxer/conformance-review-rulebook.git` —
  confirms the actual repo name is `conformance-review-rulebook`, not
  `review-agent-rulebook`. Stale.
- Line 16: `PLUGINS=(review review-traceability review-severity
  review-record-norm review-proposal-completeness)` — omits
  `review-agent-env`, which exists in-tree
  (`review-agent-env/.claude-plugin/plugin.json`) but is installed by
  neither `install.sh` nor documented in `README.md`.
- Lines 2-6 (header comment) also state "Installs ... ONLY this
  repository's plugins (review, review-traceability, review-severity,
  review-record-norm, review-proposal-completeness)" — the comment
  itself excludes `review-agent-env` by name, so this is a documented
  intentional-looking omission, not just an install-array oversight;
  phase 2 needs to decide (via the proposal) whether `review-agent-env`
  should be installed at all, see proposal.

## D) README / manifest completeness — old-role-name and ghost-file check (verification gap closed this session)

Read `README.md` in full (113 lines) and every `.claude-plugin/
plugin.json` (5 plugin dirs + `review-agent-env`) plus
`.claude-plugin/marketplace.json`, and skimmed
`docs/issue-30/proposals/conformance-methodology.md`,
`docs/issue-39/proposals/conformance-review.md`, and
`docs/issue-42/proposals/conformance-review.md` for any historical role
rename.

Findings:

1. **No old-role-name string hits.** Issue #39's proposal
   (`docs/issue-39/proposals/conformance-review.md:60-89`) documents the
   only naming-shape change in this repo's history: a prior draft
   proposed one monolithic `review` plugin with one
   `methodology-gate.sh`; that draft was never landed (rejected by
   issue #39's own corrective-feedback thread before merge) and never
   shipped a differently-named plugin. `review`,
   `review-traceability`, `review-severity`, `review-record-norm`, and
   `review-proposal-completeness` are the only plugin names that have
   ever existed in a landed state in this repo, and all five are
   consistently spelled across `README.md`,
   `.claude-plugin/marketplace.json`, and each plugin's own
   `.claude-plugin/plugin.json`. **No old-role-name hits found —
   recorded explicitly so phase 2 does not re-derive this.**
2. **One ghost/dangling reference found, not previously flagged in the
   prior pass:** `review-agent-env/.claude-plugin/plugin.json:8-10`
   declares `"dependencies": ["review-cycle"]`. No plugin named
   `review-cycle` exists anywhere in this repo — not in
   `.claude-plugin/marketplace.json`'s `plugins` array (which lists only
   the five names above), not as a directory. This is a ghost dependency
   reference under requirement 4's "no ghost-file/old-name reference"
   bar. It most likely refers to what eventually shipped as (some
   combination of) the five split plugins from issue #39, but the exact
   historical name `review-cycle` does not appear in any of
   `docs/issue-30`, `docs/issue-34`, `docs/issue-39`, or `docs/issue-42`
   — its origin could not be traced from in-repo history alone. Flagged
   for the proposal as a defect requiring either a rename to a real
   dependency or removal, pending phase-2 confirmation of intent (this
   file is undocumented and unregistered elsewhere, see below).
3. **`review-agent-env` is otherwise a ghost plugin from the
   README's/marketplace's point of view**: it has a real
   `.claude-plugin/plugin.json` in-tree but (a) no `hooks.json` (per B),
   (b) no entry in `.claude-plugin/marketplace.json`'s `plugins` array
   (read in full — only 5 entries, `review-agent-env` absent), (c) no
   mention anywhere in `README.md`'s "What is here" plugin list
   (`README.md:22-70`) or install instructions (`README.md:85-94`), and
   (d) is excluded by name from `install.sh`'s own header comment (C).
   Net effect: it exists in-tree, uninstallable through the documented
   path, and undocumented — a manifest/README completeness gap under
   requirement 4, distinct from but adjacent to the ghost-dependency
   finding in (2).
4. **No ghost file-path references found** in `README.md`: every path
   named in `README.md:27-62`'s file listing
   (`review/hooks/directive.sh`, `review/hooks/state.sh`,
   `review-traceability/hooks/traceability-gate.sh`,
   `review-traceability/skills/finding-record`,
   `review-severity/hooks/severity-gate.sh`,
   `review-severity/skills/severity-classification`,
   `review-record-norm/hooks/closed-checks-gate.sh`,
   `review-proposal-completeness/hooks/proposal-completeness-gate.sh`,
   `tests/`) corresponds to a real path in this checkout, confirmed by
   directory listing.

## E) issue #42 scope confirmation

`docs/issue-42/proposals/conformance-review.md:1-22` confirms issue #42
fixed four different defects (kill-switch inverted default,
Edit/MultiEdit/replace_all mis-reconstruction, vacuous repo-level
checks, README drift) and explicitly did not touch hooks.json matcher
lists, NotebookEdit support, or `install.sh`'s repo name. Items B/C/D
above are newly-scoped gaps for issue #45, not regressions of #42's
work — confirmed by reading the #42 proposal text directly this
session (not merely cited from the prior pass).
