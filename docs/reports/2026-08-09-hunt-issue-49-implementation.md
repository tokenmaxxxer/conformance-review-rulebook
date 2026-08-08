---
proposal: docs/issue-49/proposals/implementation.md
---

# Hunt record — issue-49-implementation

## after-proposal — stance 3: assume the rule as written cannot hold — find the state nothing maintains

Verdict: FINDING — README.md's documented `loop_state` vocabulary (`idle, scoped, auditing, draft-reported, reported`) is not the vocabulary this repo's own conformance-review records actually use, and no gate anywhere checks loop_state values, so the proposal's premise that these five states are a stable, "load-bearing" baseline to layer the spec's states onto is already false — the invariant has been silently rotting since before this proposal.
Kind: silent-failure
Seed: docs/issue-49/proposals/implementation.md, docs/issue-49/reports/implementation/survey.md (both new, 231 lines total, docs-only)
cap_seconds: 120
tier: default
diff_stat_lines: 231 (2 files added)
started_at: 2026-08-09T00:00:00Z
ended_at: 2026-08-09T00:08:00Z

### Reproduce
```
grep -n 'loop_state' README.md
grep -rn 'loop_state:' docs/issue-39/reports/conformance-review.md docs/issue-45/reports/conformance-review/current-state-survey.md docs/issue-30/reports/conformance-review.md
grep -rln 'loop_state' review/hooks/ review-traceability/
```

### Observed
`README.md:86` states the canonical vocabulary as
`idle, scoped, auditing, draft-reported, reported`. But the actual
`loop_state:` values written in this repo's own conformance-review records
are `scope-proposed`, `scoped`, `phase2_complete`, `landed` (e.g.
`docs/issue-39/reports/conformance-review.md:4: loop_state: landed`,
`docs/issue-45/reports/conformance-review/current-state-survey.md:4: loop_state: scope-proposed`,
`docs/issue-30/reports/conformance-review.md:4: loop_state: phase2_complete`) —
none of `landed`, `phase2_complete`, or `scope-proposed` appear in README's
documented set. `grep -rln 'loop_state' review/hooks/ review-traceability/`
returns nothing: no hook or gate reads or validates `loop_state` at all, so
this drift between documented and actual vocabulary is invisible and has
already happened.

### Expected
Either README's `## Record vocabulary` loop_state list should match what
records actually write, or something should gate/flag a record whose
`loop_state:` value isn't in the documented set. The proposal treats the
five README states as a settled, load-bearing baseline worth carefully
layering the spec's four states onto (Rationale: "those three values are
load-bearing for `review/hooks/state.sh`'s resume-state detection... and
for `finding-record/SKILL.md`'s own phase gating") without checking that
the documented baseline itself is already unmaintained and diverged from
practice — the "state" this proposal assumes is stable is not being kept
true by anything in the repo.
