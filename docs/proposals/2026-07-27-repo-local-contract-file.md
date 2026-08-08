---
status: landed
files:
  - docs/specs/role-handoff-contract.md
  - review-cycle/hooks/run-gate-tests.sh
  - docs/proposals/2026-07-27-repo-local-contract-file.md
---

## Intent

`review-agent-rulebook` has no repo-local contract file at
`docs/specs/role-handoff-contract.md`. The gate's Rule 0 (contract-presence)
refuses every call when that file is absent, which means the new §11
subject-scoped ownership logic never gets a chance to run — Rule 0 rejects
the call before ownership checking is reached. This blocks the gate-fix
branch's ownership tests from ever going green, not because the ownership
logic is wrong, but because a precondition file this repo was never given
is missing.

## What will be done

Create `docs/specs/role-handoff-contract.md` in this repo, sourced from the
v2 handoff contract already landed in the sibling repo
`coding-agent-rulebook`, via:

```
git show v2-conformance:docs/specs/handoff-protocol.md
```

run from `/home/jwjung/tokenmaxxxer/coding-agent-rulebook`, with the output
written verbatim (or with only path/repo-name references adjusted to this
repo, if any exist) into
`/home/jwjung/tokenmaxxxer/review-agent-rulebook/docs/specs/role-handoff-contract.md`.
This gives `review-agent-rulebook` its own repo-local copy of the v2 handoff
contract — no cross-repo dependency at runtime, no shared file, consistent
with this repo's standing constraint that each rulebook is self-contained.

`review-cycle/hooks/run-gate-tests.sh` will be checked and, if it hardcodes
an assumption that the contract file is absent (e.g. an expected-failure
case for Rule 0, or a skip/xfail marker on the subject-scoped ownership
tests that exist only because the contract was missing), updated so those
cases reflect the contract now being present. No gate logic itself is
touched — that is out of scope, owned by the gate-fix branch.

## Out of scope

- Any repo other than `review-agent-rulebook` (this only reads from
  `coding-agent-rulebook` via `git show`; nothing there is modified).
- Merging this work or any other branch.
- Pushing to any remote.
- Modifying gate logic itself (Rule 0's implementation, §11 ownership
  logic) — both already live on the gate-fix branch and are not touched
  here.

## How we'll know it worked

- The gate no longer refuses calls via Rule 0 (contract-presence) for this
  repo, since `docs/specs/role-handoff-contract.md` now exists.
- A test where the acting role writes to its own `review.md` (own-subject
  write) is allowed through §11 ownership logic.
- A test where the acting role writes to a foreign subject's file is
  refused by §11 ownership logic — not by Rule 0.
- The set of test cases that were previously red because the contract file
  was absent (reported as 9 cases) pass, and none of them are passing
  merely because they were skipped or marked expected-failure.

## Review

Self-reviewed; no other reviewer assigned yet.

## What did not work

- **Rewriting the sourced content to read as review's own contract.**
  Considered relabeling `coding-agent-rulebook`'s handoff-protocol.md
  content (role name "coding", section 4 "Read/Depends-on/Never-overwrite")
  into review-specific language and section numbers (so a human reading
  `docs/specs/role-handoff-contract.md` would see "review" and "§11"
  matching what `state-gate.sh`'s refusal message cites), to make the file
  read naturally as this repo's contract. Abandoned: this proposal's "What
  will be done" section restricts adaptation to "path/repo-name
  references... if any exist," and none exist in the sourced text — so the
  file was written verbatim from
  `git show v2-conformance:docs/specs/handoff-protocol.md` (run in
  `coding-agent-rulebook`) instead. Net effect: the landed contract file
  describes the *coding* role's behavior, not review's, and its own scope
  note explicitly disclaims defining the contract at all. `state-gate.sh`'s
  §11 citation and role name ("review") are hardcoded in the gate's Python,
  not read from this file's content, so no gate behavior depends on this
  mismatch — but it is a real oddity in the landed file worth a future
  proposal's attention.

- **Gate tests that were expected to go green did not, for a reason
  unrelated to contract absence.** After adding the contract file, all 13
  baseline failures whose message cited "this repo has no collaboration
  contract yet" stopped citing that message — the contract-presence
  precondition this proposal targets is fully resolved. But of those 13,
  only 8 now pass. Five ((g), (h), (i), (n1), (n2)) and, more surprisingly,
  three tests that had *passed* at baseline ((a), (d), (e2)) now fail, all
  with the same new symptom: an expected `deny` returns exit 0 with no
  output. Root cause, confirmed by direct inspection of `state-gate.sh`:
  the gate resolves its root by walking up from the hook script's own
  on-disk directory to the nearest `.git` — explicitly, per its own inline
  comment, "never from the process cwd or CLAUDE_PROJECT_DIR." Every
  `run-gate-tests.sh` test case sets `CLAUDE_PROJECT_DIR` to a fresh
  `mktemp -d` tmp root, expecting the gate to treat that as root; the gate
  never reads that variable, so it always resolves to the real
  `review-agent-rulebook` checkout instead. Tmp-root state/record files
  the tests write are therefore invisible to the gate, and paths under the
  tmp root fall outside the resolved root, silently routing many calls to
  a no-match `allow()`. At baseline this was masked because Rule 0 refused
  every call outright (contract absent), which happened to match what the
  `expect_deny` tests wanted regardless of whether Rule 1's actual logic
  ran. Removing that mask (by adding the contract) exposed the mismatch
  rather than fixing it. This is a gate-logic / test-harness
  root-resolution bug, not a contract-presence bug, and per this
  proposal's explicit scope boundary ("No gate logic itself is touched...
  already live on the gate-fix branch") it was not fixed here — it belongs
  to gate-fix branch follow-up work. `run-gate-tests.sh` was left
  unmodified: nothing in it hardcodes an absent-contract assumption (no
  skip/xfail markers were found), so no edit was warranted under this
  proposal's narrower mandate for that file.
