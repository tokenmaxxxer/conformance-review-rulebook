# review-proposal-completeness

A `PreToolUse` gate on `Write|Edit|MultiEdit|NotebookEdit` that enforces a
freelunch-grade structural completeness bar on this role's own phase-1
proposal, `docs/issue-<n>/proposals/review.md` — the same bar `core`'s
`freelunch` plugin holds a fan-out chunk to before accepting it as complete,
per issue #39 (b.5) and issue #30 (a)'s source-grounding requirement. Any
other path is allowed through untouched.

## The five checks

On the PROPOSED content (Write's `content`, or the post-edit reconstruction
for Edit/MultiEdit), all five must be present or the write is refused, naming
which are missing:

1. **Request** — a `## Request` (or `# Request`) heading.
2. **Constraints** — a `## Constraints` heading with a non-trivial body
   (at least ~20 non-whitespace characters before the next heading).
3. **Sourced adoption** — at least one paragraph using "adopt"/"adopted" that
   also carries a source-attribution pattern in the same paragraph: a
   markdown link, a `docs/` path, or an `issue #<n>`/`issue-<n>` reference.
4. **Adopt-vs-skip split** — both an adopted-items section and a
   skipped/out-of-scope section, each with at least one line of content.
5. **How this will be judged** — a closing section (case-insensitive) naming
   at least one externally-verifiable condition: file existence, exit code,
   gate, field presence, test, or pass — not prose alone.

This is a structural probe, not a truth check: it does not verify that an
adoption claim is actually sourced correctly, only that the document's shape
forces the claim to name a source and the judgment criteria to be
verifiable, per §30(a)'s norm.

## Kill switch

`export REVIEW_PROPOSAL_COMPLETENESS_GATE_OFF=1` disables the gate entirely
(fail-open only when explicitly requested).

This plugin has no `skills/` component — the bar is stated in issue #30 (a)
and restated in `review`'s own directive, not owned by a separate skill file;
the hook/test pair alone is self-contained.

## Running tests

```
bash review-proposal-completeness/tests/proposal-completeness-gate-test.sh
bash tests/deny-only-check.sh review-proposal-completeness/hooks
```
