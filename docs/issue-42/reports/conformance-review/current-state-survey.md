# Current-state survey — issue #42 (gate A+ remediation)

## Write surfaces inspected

- `review-traceability/hooks/traceability-gate.sh` (211 lines)
- `review-severity/hooks/severity-gate.sh` (177 lines)
- `review-record-norm/hooks/closed-checks-gate.sh` (204 lines)
- `review-proposal-completeness/hooks/proposal-completeness-gate.sh` (253 lines)
- `tests/deny-only-check.sh`, `tests/parse-check.sh`, `tests/run-gate-tests.sh`
- `README.md`

All four `*-gate.sh` scripts share one hand-rolled skeleton (trap-at-top,
kill-switch case, JSON parse, path resolve, Write/Edit/MultiEdit content
reconstruction) copy-pasted with no shared library — i.e. exactly the
pattern `core` issue #72 found and fixed across its own 43-rulebook
population, still present here uncorrected.

## Confirmed defects (matches the issue body's audit)

1. **Kill-switch inverted-default.** All four gates use
   `case "${X_OFF:-}" in ""|0|false|no|off) ;; *) exit 0 ;; esac` — any
   *unrecognized* value (a typo, `"2"`, `"disabled"`) falls to `*` and
   **disables** the gate. This is precisely the bug `gate-lib.sh`'s
   `gate_kill_switch_active` was written to fix (fixed default: only a
   recognized on-spelling disables; everything else, recognized-off or
   garbage, stays active).
2. **`Edit`/`MultiEdit` reconstruction ignores `replace_all`.** All four
   gates reconstruct `Edit` via `cur.replace(old, content, 1)`
   unconditionally (first occurrence only, `replace_all` field never read)
   and `MultiEdit` via a per-edit `text.replace(o, n, 1)` loop, same bug.
   A `replace_all: true` Edit or a MultiEdit relying on `replace_all` is
   silently mis-reconstructed, so the gate judges content that was never
   actually about to be written — a false negative to the write itself,
   or a mismatched positive if the wrong reconstruction happens to still
   trip a check.
3. **Semantic check is bare substring/word-boundary, not field-structural,
   in two places:**
   - `traceability-gate.sh`'s `verdict_re =
     re.compile(r'\b(Present|Surface|Absent|Incorrect|Unverifiable)\b',
     re.I)` matches the English words "Surface"/"Present"/"Absent" any
     time they occur in prose (e.g. "a broad surface area", "no test data
     present") — false verdict detection anywhere in the document.
   - `proposal-completeness-gate.sh`'s adoption check
     (`re.search(r'\badopt(?:ed|s|ion)?\b', p, re.I) and
     source_pat.search(p)`) only requires the word "adopt" and *a* source
     pattern to co-occur anywhere in the same paragraph — a paragraph that
     mentions "adopted" once and links to something unrelated elsewhere in
     the same paragraph passes. Both are "word mentioned" gates, exactly
     what the issue calls out.
   - By contrast `severity-gate.sh`'s vocabulary check and
     `closed-checks-gate.sh`'s sha-prefix check are already closed-set /
     exact-value comparisons, not substring scans — not flagged by the
     issue and out of scope here.
4. **Path matching:** all four already normalize through
   `os.path.realpath` + prefix-strip, which does handle an absolute
   `file_path` and a `./`-prefixed one correctly *when the file exists on
   disk* — `realpath` on a symlink-free repo path is a no-op. This is
   different from, and more filesystem-dependent than, `gate-lib.py`'s
   `gate_normalize_path`, which is pure string/path algebra and works
   before the file exists (relevant for a `Write` creating a brand-new
   path with no prior real file to `realpath` against — untested today).
   Not the sharpest form of the bug the issue names, but adopting
   `gate_normalize_path` closes the gap and de-duplicates the four
   copies.
5. **`gate_deny`/stderr:** already correct in all four (every `deny()`
   writes to `sys.stderr` and the outer trap forces exit 2) — the issue's
   "deny 사유 stderr 전달" requirement is already met; no regression
   found. Kept as-is, migrated onto `gate_deny`'s equivalent shape for
   consistency, not because it is currently broken.
6. **Repo-level checks pass vacuously post-split.** `tests/parse-check.sh`
   defaults to `review/hooks` and `tests/deny-only-check.sh`'s
   `substance_probe` defaults `probe_dir` to `.../review/hooks` — both
   predate issue #39's split into five sibling plugins. `review/hooks/`
   now holds only `directive.sh`/`state.sh` (no `*-gate.sh` file), so
   `parse-check.sh` silently checks zero of the four real gate files
   unless a caller remembers to pass a directory explicitly, and
   `deny-only-check.sh`'s `find "$probe_dir" -name '*-gate.sh'` finds
   nothing, hits the `no gate scripts under $probe_dir` early-return, and
   reports **pass** (`return 0`) despite covering none of the four actual
   gates. `README.md`'s own "Run the checks" section still shows the
   un-parameterized invocations, so a maintainer following the README
   gets the vacuous pass.
7. **README drift.** `README.md` still names the repo
   `tokenmaxxxer/review-agent-rulebook` (current repo:
   `conformance-review-rulebook`, per this session's role and branch
   naming), documents `review/hooks/closed-checks-gate.sh` (moved to
   `review-record-norm/hooks/closed-checks-gate.sh` in #39/#41),
   documents `review/skills/finding-record` and
   `review/skills/severity-classification` (now
   `review-traceability/skills/finding-record`,
   `review-severity/skills/severity-classification`), and the install
   command `claude plugin install review@tokenmaxxxer-review` /
   `marketplace add tokenmaxxxer/review-agent-rulebook` doesn't match
   `.claude-plugin/marketplace.json`'s real name (`tokenmaxxxer-review`)
   or the five real plugin names.

## Prerequisite check

Core issue #72 (gate-house standard) is merged to `tokenmaxxxer-core`
main: `22a7cad` "deliver(implementation): gate-house standard
canonization (issue-72) (#74)". `core/hooks/lib/gate-lib.sh` +
`gate-lib.py` + `core/hooks/tests/compliance-check.sh` +
`core/hooks/tests/run-gate-lib-tests.sh` all exist there now. The issue's
precondition ("core issue #72 가 랜딩된 뒤 그 라이브러리를 참조") is
satisfied — this proposal designs the reference-adoption, not a
reimplementation.

## Gaps this proposal must close (feeds the proposal directly)

- Migrate all four gates' kill-switch, `Edit`/`MultiEdit` reconstruction,
  fail-closed trap, and path-normalize onto `gate-lib.sh`/`gate-lib.py`
  by reference (source/importlib), not a vendored copy.
- Replace the two substring-scan semantic checks with block/adjacency/
  structural checks (see proposal for the concrete shape).
- Re-parameterize `parse-check.sh`'s and `deny-only-check.sh`'s default
  directories (or make `run-gate-tests.sh` the canonical entrypoint that
  always passes explicit dirs) so the post-split five-plugin layout is
  actually covered, not vacuously passed.
- Resync `README.md` to the real repo name, real file layout, and real
  install commands.
- Add the six gate-lib mandatory test cases (per
  `docs/handbooks/gate-house-standard.md`) to each of the four plugins'
  own test files, plus this repo's own semantic-upgrade cases.
