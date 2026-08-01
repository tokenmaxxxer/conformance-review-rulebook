---
subject: issue-45
role: review
loop_state: scope-proposed
---

# Scout brief — issue #45 (skip record)

**Skipped.** Task is a pure bugfix / the spec leaves no design decision
open — all fixes reconcile existing `hooks.json` matchers against
existing tested code branches per already-landed core #75 guard shapes;
no product-direction choice exists to scout. Every defect in scope
(Bash-matcher registration, NotebookEdit branch implementation,
`install.sh` repo-name/plugin-list correction, README/manifest
ghost-reference cleanup) is a reconciliation against artifacts that
already exist in this repo or in landed core work — not an open
question about what methodology, tool, or approach to adopt.

The one item that could look like a choice — NotebookEdit either gets a
real content-check branch or gets dropped from the matcher — is
resolved in the proposal itself by a stated default (implement, don't
silently drop advertised surface) rather than by field-scouting external
practice; it does not need a scout sweep because it is a call the
proposal document can make and justify in one line, not a question with
external prior art to canvas.
