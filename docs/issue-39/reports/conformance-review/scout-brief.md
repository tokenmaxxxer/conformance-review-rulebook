---
subject: issue-39
role: review
---

# Scout brief (issue #39) — skip record

**Scouting skipped.** Skip condition: "the spec literally leaves no
design decision open" (external-practice axis). Issue #30
(`docs/issue-30/proposals/conformance-methodology.md`) already ran the
domain-research sweep this role's deliverable needs and adopted, by named
external source, the requirement-decomposition / evidence-based-audit /
deterministic-severity methodology this issue is asked to *mechanize*.
Issue #39 poses no new question about which external field practice to
follow — it asks how to encode an already-adopted answer as enforcement.
The remaining decisions (gate script shape, state-file shape, test
matrix) were resolved against this repo's own already-landed sibling
implementations instead (see `current-state-survey.md`'s "Comparable
machines" section): `pricing-rulebook/pricing/hooks/methodology-gate.sh`,
`performance-engineering-rulebook/performance-engineering/hooks/
methodology-gate.sh`, and `implementation-rulebook/coding/hooks/{state,
hunt-state,hunt-guard,coding-progress-gate}.sh` — read directly this
session, all local checkouts. No web search was run.
