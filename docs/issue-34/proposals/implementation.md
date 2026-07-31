# issue-34 proposal (implementation)

## Change

1. `git rm review/hooks/tests/stub-check.sh` — delete the vendored copy.
2. `review/hooks/hooks.json` — no change; it never registered
   `stub-check.sh` (survey confirmed only `directive.sh` and
   `closed-checks-gate.sh` are hooked).
3. `README.md:30` — replace the "copied verbatim" line with a description
   of stub-check as core-canon, run by reference against the installed
   `core` plugin (`${CLAUDE_PLUGIN_ROOT}`-resolved), no local file.
4. `docs/handbooks/review-hooks.md:17-21` — same edit: drop "copied
   verbatim from `core/hooks/tests/stub-check.sh`," describe as reference
   execution against core's installed copy.
5. Phase 2 (post-Approve): run stub-check by reference against
   `review/hooks` and record the pass in
   `docs/issue-34/reports/implementation.md`, per the issue's instruction.

## Out of scope

- `docs/issue-31/**` — historical record of the original copy-in decision;
  not touched.
- Any core-side change (core #69 already landed the canon decision).

## Acceptance

- `review/hooks/tests/stub-check.sh` no longer exists.
- `hooks.json` unchanged.
- README and handbook describe reference execution, not vendoring.
- Report records a clean stub-check pass run against the installed core
  copy.
