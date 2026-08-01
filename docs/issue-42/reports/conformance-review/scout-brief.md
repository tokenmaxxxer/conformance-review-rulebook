# Scout brief — issue #42

Mode: 1 sweep stage (2 parallel WebSearch calls) + judge point, no
deepening round run — saturation reached immediately (both hits converge
on the same single answer the survey's gap already implied). Wall-clock
well under budget.

## Angles run (parallel, one turn)

1. Substring-false-positive avoidance in structured-field validators
   (frontmatter/config linting).
2. Markdown structural-linting tooling (markdownlint/remark-lint) for
   heading/section-adjacency checks.

## Must-be (the field's convergent answer)

Every credible tool in this space (remark-lint-frontmatter-schema,
markdownlint, PyMarkdown's front-matter extension) validates against a
**parsed structure** (frontmatter-as-schema, heading/AST tree) with
path/context-aware matching, never a raw whole-document substring/regex
scan. The one specific failure mode surfaced (remark schema mismatch)
was exactly a context-blindness bug: matching by filename alone instead
of by structural position — the same class of bug this repo's verdict
regex and "adopt"-paragraph check have (matching by bare word instead of
field/paragraph position).

## Gap line

Already met: this repo's `severity-gate.sh` and `closed-checks-gate.sh`
already check closed-vocabulary/exact-value fields, not substrings — no
change needed there (confirms survey §3's scoping).
Missing: `traceability-gate.sh`'s verdict scan and
`proposal-completeness-gate.sh`'s adoption-paragraph scan are the two
sites still doing bare-word matching instead of matching a field's
structural position (label-adjacent, or block-scoped to where the field
is declared) — these are the two the proposal targets.

## Adopt / skip

- Adopt: block/label-adjacency matching (`key:\s*value` line immediately
  governs the token that follows, not "word occurs somewhere in a
  70-line block") — the pattern every surveyed tool converges on.
- Skip: full CommonMark AST parsing (e.g. vendoring a markdown parser) —
  disproportionate to a bash/python hook with no such dependency today;
  a tightened regex/line-scan achieves the same structural precision
  without adding a parser dependency, and is the smallest change that
  satisfies "section/adjacency/structure" per the issue's own wording.

## Segment fit

This is an internal gate-hook, not a general-purpose linter — the
adjacency-based approach fits without adopting the heavier AST-based
tooling those products need for arbitrary user-authored markdown.

Sources:
- https://github.com/JulianCataldo/remark-lint-frontmatter-schema
- https://pymarkdown.readthedocs.io/en/stable/extensions/front-matter/
- https://github.com/DavidAnson/markdownlint/blob/main/doc/Rules.md
