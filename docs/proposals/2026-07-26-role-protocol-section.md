---
status: landed
files:
  - README.md
  - review-cycle/hooks/state-gate.sh
---

# Role protocol section for review

## Intent

A review session today has to read the full shared
`docs/specs/role-handoff-contract.md` to find its accepted kinds, the one
refusal that is stated by `kind` rather than by path, and its single output
kind. This proposal adds a "Handoff protocol" section to `README.md`
carrying only review's rows, so the session reads one page scoped to its
own role — including the kind-based refusal rule that today lives only in
the shared contract's prose plus a path regex in
`review-cycle/hooks/state-gate.sh`.

## Constraints that change what gets built

- Excerpt only, from `docs/specs/role-handoff-contract.md` at
  `2affe5db7dfb285abaa2860d3004edb3f97c9aec` (root `tokenmaxxxer` repo) —
  review's rows from sections 2, 3, and 7, plus its reading of sections 1
  and 4.
- Section 3 for review is a `kind`-based refusal, not a path-based one: any
  artifact declaring `kind` in `{hypothesis, build-proposal}` is refused
  for its narrative body (`## Request`, `## Constraints`,
  `## What will be done`, `## Out of scope`) — review may still read
  `build-proposal`'s `files:` frontmatter field to resolve the diff's
  scope. The contract states this replaces the current
  `docs/proposals(/|$)` path regex in
  `review-cycle/hooks/state-gate.sh`, since a path rule breaks the moment
  either kind moves out of `docs/proposals/`.
- The section header pins the contract SHA; `review-cycle/hooks/state-gate.sh`
  gains a check that refuses to proceed when the pinned SHA no longer
  matches the contract's current SHA.
- Per-role path ownership (section 7) is enforced by this same gate, since
  warrant's write-set gate deliberately does not constrain writes under
  `docs/` and section 7 assigns that enforcement to each rulebook.

## What will be done

Add "Handoff protocol" to `README.md` with four parts:

1. **ACCEPTS** — `build-proposal` (the change) and the `hypothesis` /
   `feasibility-record` that specify what the change was supposed to do;
   must refuse any artifact declaring `kind` in `{hypothesis,
   build-proposal}` when read for its narrative body — refusal by declared
   `kind`, not by path — while still reading `build-proposal`'s `files:`
   field for scope.
2. **WHERE UPSTREAM LIVES** — `docs/proposals/<date>-build-<slug>.md` for
   `build-proposal` (frontmatter `files:` field only); `docs/proposals/<date>-<slug>.md`
   for `hypothesis`; `docs/reports/records/<subject>/feasibility.md` for
   `feasibility-record` (both read for their specification content, not as
   narrative intent).
3. **PRODUCES** — `review-record` at
   `docs/reports/records/<subject>/review.md`, required fields: role status
   (`idle,scoped,auditing,draft-reported,reported`), plus the common header
   including `handoff_status`; with inline `finding` blocks, required
   fields: `requirement`, `verdict` (`Present|Surface|Absent|Incorrect|Unverifiable`),
   `evidence`, `rationale`, `spec_vs_built` (required only when
   `verdict: Incorrect`).
4. **STOPS** — upstream stale at role entry (recorded `sha` for whichever
   of `build-proposal`/`hypothesis`/`feasibility-record` was read, against
   its current `sha`); an existing record already at a path review does
   not own under `docs/reports/records/` (refuse, report, never
   overwrite); input carrying `handoff_status: provisional` when review is
   not permitted to treat it as final baseline for a verdict.

Also add the SHA-pin check to `review-cycle/hooks/state-gate.sh`, and
replace its `docs/proposals(/|$)` path regex with the kind-based refusal
described above.

## Out of scope

Changing `docs/specs/role-handoff-contract.md`. Changing warrant's
`scope-gate.sh` (not present in this repo). The other five rulebook repos.
Starting any review-cycle build work, including the actual regex-to-kind
migration in `state-gate.sh` beyond what this proposal specifies.

## How you will know it worked

A review session can answer, from `README.md` alone, which kinds it
accepts and how the kind-based refusal differs from a path-based one,
where to find each accepted kind, where its own output lands, and its
three stop conditions. `state-gate.sh` refuses to proceed when the pinned
SHA no longer matches the contract's current SHA, refuses a write to a
`docs/reports/records/` path review does not own, and refuses narrative-body
reads of `hypothesis`/`build-proposal` by `kind` rather than by path.
