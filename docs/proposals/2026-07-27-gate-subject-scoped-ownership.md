---
status: approved
files:
  - review-cycle/hooks/state-gate.sh
  - review-cycle/hooks/run-gate-tests.sh
  - docs/proposals/2026-07-27-gate-subject-scoped-ownership.md
---

## 1. Intent

Under contract-v2 the blackboard lives at `docs/reports/records/<subject>/<role>.md`; each role's gate must enforce §11 path-ownership against the SUBJECT-SCOPED path (a role may write only its own `<role>.md` under any subject), not a hardcoded flat record name; rules/contract resolution is repo-local. `review-cycle/hooks/state-gate.sh` currently only compares against a hardcoded flat `review-record.md` path and never checks ownership for subject-scoped `docs/reports/records/<subject>/<role>.md` paths — so review writing ANOTHER role's record (e.g. `.../records/<subject>/product.md`) is silently ALLOWED (exit 0) instead of refused per §11 NEVER-OVERWRITE. This was surfaced live, reproduced by the before-landing hunter in `docs/reports/2026-07-27-hunt-full-gate-relay-simulation.md`, and confirmed in the relay, both in relay-sim-v2. This proposal fixes that gap in the review gate.

## 2. Constraints that change what gets built

- Contract-v2 blackboard layout is frozen and stated verbatim: `docs/reports/records/<subject>/<role>.md`. The fix must classify paths under this shape, not a single hardcoded filename.
- A role owns exactly `docs/reports/records/<subject>/<its-own-role>.md` for ANY subject value; any other role's file under the same (or any) subject must be refused.
- Mirror the shape the qa/product gates already use for subject-scoped owned-path classification — same structure, applied to review's own role name (`review`).
- Keep the existing Rule 0 (contract-presence) and Rule 1 (write-path handling) behavior intact; this is an addition/generalization of ownership classification, not a rewrite of the gate's overall control flow.
- Repo-local resolution: no dependency on other rulebook repos' gate code or shared libraries.

## 3. What will be done

In `review-cycle/hooks/state-gate.sh`, add subject-scoped owned-path classification: given a candidate write target, detect whether it matches `docs/reports/records/<subject>/<role>.md` for any `<subject>` segment, and if so, treat it as owned only when `<role>` equals `review`; any other role name under that pattern is a §11 violation and must be refused (deny), not silently allowed. This replaces/extends the current comparison-against-hardcoded-flat-path logic so that subject-scoped paths are recognized and classified, alongside whatever legacy flat-path handling remains needed. `review-cycle/hooks/run-gate-tests.sh` will get corresponding test cases for the new classification (own-role subject-scoped write allowed; other-role subject-scoped write refused, across at least two distinct subject values, citing §11).

## 4. Out of scope

- The other five rulebook repos (coding, qa, product, feasibility, ops) — not touched, not read as edit targets.
- relay-sim-v2 itself.
- The ops fail-open defect — tracked as a separate ops proposal.
- Any change to Rule 0 contract-presence checking or to the state-machine transition tables.

## 5. How we know it worked

- Review writing its own subject-scoped record (`docs/reports/records/<subject>/review.md`, for any subject) ALLOWs (exit 0).
- Review writing another role's record under the same subject (e.g. `docs/reports/records/<subject>/product.md`) REFUSEs (exit 2), citing §11.
- Both cases covered as passing tests in `review-cycle/hooks/run-gate-tests.sh`.

## What did not work

- Could not get the new `(m1)/(m2)/(n1)/(n2)` §11 tests (or, in fact, most of
  the pre-existing test suite: `(b)(c)(e1)(g)(h)(i)(j)(k)`) to pass end-to-end
  via `run-gate-tests.sh` as run against this checkout's actual on-disk repo
  root, because `docs/specs/role-handoff-contract.md` does not exist in this
  repo at all — Rule 0 (contract-presence, out of scope to touch per this
  proposal) refuses every call before the new §11 ownership logic, or any of
  Rule 1's transition logic, ever runs. Confirmed with `git stash` that this
  is a pre-existing baseline failure (5 passed / 9 failed) unrelated to this
  change, not a regression introduced here — the same 9 tests fail identically
  at the pre-change commit.
- Worked around this for manual verification only (not committed) by copying
  `state-gate.sh` into a throwaway directory with its own `.git` and a stub
  `docs/specs/role-handoff-contract.md`, and confirmed there: writing
  `docs/reports/records/checkout-flow/review.md` allows (exit 0), and writing
  `docs/reports/records/checkout-flow/product.md` refuses (exit 2, citing
  §11 NEVER-OVERWRITE). The new tests in `run-gate-tests.sh` are correct
  against a repo that actually has the contract file; they cannot be made to
  pass against this repo's current state without adding
  `docs/specs/role-handoff-contract.md`, which is outside this proposal's
  frozen file set and outside Rule 0's explicitly-out-of-scope boundary.
