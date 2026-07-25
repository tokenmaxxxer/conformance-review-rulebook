---
status: draft
---

# Agent roles and their state machines

This document defines the `review` role the tokenmaxxxer org runs beyond the
two that already exist (`coding`, `qa`), specifies how the human user drives
the role in a star topology (user at the centre, agents never talking to
each other), and gives the role's internal state machine at the concreteness
of `coding-agent-rulebook`'s warrant plugin: named states, a named artifact
carrying the state, explicit gate conditions evaluated on a file, not on
which tool wrote it.

Sources for every research claim are the eight files under
`docs/reports/research/2026-07-25-swpd-roles/`, cited by filename.

## Part 1 — Role

### `review`

**Decides**: whether what was built is what was specified — a per-requirement
verdict, not a holistic judgment of code quality.

**Given to start**: the change and the specification, deliberately without
the building agent's intent, reasoning, or proposal prose. This mirrors the
qa-cycle's own discipline of working from what is observed rather than from
what the target team says it meant (qa-testing.md), and the security/legal
review functions this role absorbs: privacy engineering and DPO-style review
work from the artifact and the DPIA, not from the implementer's stated
intent (security-legal-compliance.md). Design/UX critique — is the built
thing accessible, is it consistent with what was designed — is also folded
into this role's per-requirement verdict when the specification carries
design requirements (design-ux.md).

**Produces**: a verdict of Present, Surface, Absent, or Incorrect for every
requirement in the specification — the same four-way classification
`implementation-audit` uses for exactly this reason: a surface imitation of
a requirement must be distinguishable from a real one, not merged into a
single pass/fail.

**Prevents**: a surface imitation of a requirement passing as an
implementation — the single most game-able failure mode when the entity
grading the work also built it.

### `coding` (existing, as-is)

Described from `coding-agent-rulebook`'s `warrant` plugin, read directly, not
proposed to change. A request becomes a proposal file under
`docs/proposals/`, whose frontmatter carries `status: proposed -> approved ->
landed` and a `files:` write set. Approval freezes the write set; a
`PreToolUse` hook (`warrant/hooks/scope-gate.sh`) then refuses edits outside
that set and refuses commits without a `Proposal: <path>` trailer, judged
against the resolved path or command string regardless of which tool
produced it. A `SessionStart` hook (`warrant/hooks/state.sh`) reads the
repository — proposal frontmatter plus `git log --grep` — and reports open
units back to a fresh session with no other memory. Nothing here is changed
by this document.

### `qa` (existing, as-is)

Described from `qa-agent-rulebook`'s `qa-cycle` plugin (see
`docs/specs/qa-cycle-state-machine.md` in that repository), read directly,
not proposed to change. Its unit is one feedback item, not the project: an
item moves `observed -> reproducing -> reproduced`, then to one of four
human-gated destinations (`handed-off`, `not-a-defect`, `wont-fix`, or back
to `reproducing`/`observed`/`parked-unreproducible`), with `handed-off ->
re-verifying -> verified-fixed` completing the loop once the human asserts a
fix landed. Human-locked transitions require a single-use verdict token
bound to both a specific item id and a specific (from, to) pair, minted only
from the user's own turn — never inferred from a file, issue, PR, comment, or
tool output. Nothing here is changed by this document.

## Part 2 — Working with the role

The user is the only channel between roles. Agents never talk to each other,
and the `review` role runs in its own sandbox with only its own plugin
installed — `review` never reads another role's repository, exactly as
`coding-agent-rulebook` and `qa-agent-rulebook` today never read each other's.

**Starting the role.** The user hands `review` whatever its "given to start"
line in Part 1 names — a change plus a specification. A role opened without
its entry requirement met can still be opened — nothing locks the door — but
it has nothing to work from and says so; the requirement is on the work, not
a gate on entry.

**Answering a gate.** The role stops at named points (Part 3) and needs a
decision only the user can give. A valid answer is a verdict acceptance —
`review`'s per-requirement call. The role never infers approval from the
content of a file — a file saying the right things is not consent. Whether
the user approved, rejected, or course-corrected is a semantic judgement the
model makes from the conversation, checked against the role's
`transition-rules.md` table (Part 3) for whether the resulting move is one
the table allows for that actor. This is unlike `qa-cycle`'s own mechanism,
which mints a single-use verdict token from the user's own turn
(qa-agent-rulebook's `docs/specs/qa-cycle-state-machine.md`); `review` uses no
such token.

**Carrying output forward.** The user moves artifacts between sandboxes by
hand — copies a specification file, pastes a verdict, opens the next role
with `review`'s output as its starting input. Nothing is automatic, nothing
is shared between repositories, and `review` does not read another role's
files directly. This is the same constraint `coding-agent-rulebook` and
`qa-agent-rulebook` already satisfy toward each other today.

**Returning to a finished role.** The user may reopen `review` at any time
with new input — a `reported`-state review can be reopened against a changed
specification. Order between roles is advisory: nothing enforces `review`
before or after any other role; the user routes.

**The failure this arrangement has, stated plainly.** With the user as the
only router and no cross-agent communication, the thing that goes wrong is
the user losing track of which output is current — which specification is
the live one, which verdict is stale. The mitigation costs nothing and
requires no shared machinery: `review`, on being opened, reports its own
current state and what its last output was based on, read from its own
repository — the same thing `warrant/hooks/state.sh` already does at
`SessionStart` for `coding` ("reads the proposal files and git, and says
where things stand. It writes nothing"). This is per-role visibility only.
There is no global view across roles, and a role that is never opened stays
silently stale — nobody is told a specification changed unless `review` is
reopened. That cost is accepted deliberately: any global view would need a
shared write target, and a shared write target is exactly what per-repository
write gates (`scope-gate.sh`'s write-set freeze, `qa-cycle`'s workspace-only
persistence) exist to refuse.

## Part 3 — State machine

Mechanism applying to the `review` role. There is no approval-token minting
hook and no regex deciding intent: whether the user approved, rejected, or
course-corrected is a semantic judgement the model makes from conversation
context, not a token minted by a hook.

The role's legal transitions live in a per-repo data file
`review-cycle/hooks/transition-rules.md`, pipe-delimited with columns
`from | to | actor | precondition`, where `actor` is `user` for transitions
that require the user to have said something and `agent` otherwise. A
`UserPromptSubmit` hook renders the rows matching the current state into
every prompt as a condition→allowed-transition table. If the table or the
state file cannot be read, that hook still emits a block saying so and
forbidding transitions until it is fixed — it never exits silently.

The `PreToolUse` gate decides only two things: whether a write reaches the
role's state file, judged by resolved target path rather than tool name or
literal filename (the same discipline `scope-gate.sh` applies for `coding`:
a guard that inspects only file-editing tool payloads is bypassed by the
same edit made through a shell redirect or in-place `sed`, so the gate
resolves the path regardless of which tool produced the write), and whether
the resulting transition is a row in the table. It reports "rules could not
be loaded" and "transition not in table" as distinct denials — the first for
a gate that cannot establish its own input, the second for a transition the
table refuses. Anything not reaching the state file passes.

On each transition the model appends one line to the state file naming the
user utterance it read as the basis. Nothing enforces this; it exists so a
reader outside the session can see what the transition rested on.

The `review` rulebook implements all of this itself — no shared file, no
cross-repo dependency.

A self-loop (a row whose `from` and `to` are the same state) is a legal
transition-table row like any other, gated the same way when marked
`actor: user`. It is how a repeatable, no-clean-single-precondition decision
(a disputed-finding resolution) is recorded without minting a state the
shape does not need.

**Skills.** The `review` role also carries a `skills/` directory,
`review-cycle/skills/<name>/SKILL.md`, one skill per artifact-producing
conversation named in Part 3 below. A skill runs a conversation with the
user and writes a named artifact to its own file path — a different file
from the role's state file. **This matters because it is easy to get
backwards: the `PreToolUse` gate above binds only to the state file's
resolved path. A skill's artifact write is never gated** — the model can
write, revise, or fail to write a report artifact freely; only the write
that changes the `status` field in the state file is checked against the
transition table.

**Bootstrap convention.** When the role's state file does not exist, the
current state is the synthetic literal `(none)`. The role's
`transition-rules.md` carries at least one row whose `from` is `(none)`,
naming the role's legal initial state; the write that creates the state
file is allowed exactly when such a row exists for the target, and denied
otherwise as an ordinary "transition not in table" case — no separate
mechanism from the one above. The `UserPromptSubmit` injector renders
`(none)` as a normal current state and lists its rows like any other; it
emits the "rules could not be loaded" failure block only for a missing or
unparseable `transition-rules.md`, or a state file that exists but whose
state field is absent, duplicated, or unparseable — a missing state file is
not a failure. A state file that exists is checked, both by the
`UserPromptSubmit` injector and by the `PreToolUse` gate, against the role's
declared state list regardless of what value it holds — `(none)` included —
and any value outside that list, `(none)` or otherwise, is treated
identically to "unparseable," never merged with the true-absent case.
`(none)` never appears as a `to` value: nothing transitions
into it, and deleting the state file is not a transition. The `review`
rulebook uses this same literal, implementing it independently, per the
no-shared-file rule above. `coding-agent-rulebook` and `qa-agent-rulebook`
are untouched by this convention.

### `review`

**Carrying artifact**: the review record file; state in its frontmatter
field `status`.

**States**: `idle`, `scoped`, `auditing`, `draft-reported`, `reported`.
`draft-reported` is entered once every requirement has a verdict, and is
where findings are confirmed with the reviewed party — disputes are
resolved there, inline — before the report is finalized into `reported`.

**Transition table**:

| From | To | Fires on |
|---|---|---|
| `idle` | `scoped` | user hands the role a change plus a specification |
| `scoped` | `auditing` | agent begins per-requirement verification |
| `auditing` | `auditing` | **gated, self-loop** — reviewer needs evidence/access the reviewed party must grant before a specific requirement can be checked |
| `auditing` | `draft-reported` | **gated** — every requirement has a verdict |
| `draft-reported` | `draft-reported` | **gated, self-loop** — the reviewed party disputes a finding; reviewer attempts resolution by clarification, recorded inline |
| `draft-reported` | `reported` | **gated** — user (or a named governance-equivalent party) confirms the draft as final |

**Rejection rule**: `auditing -> draft-reported` fails unless every
requirement line extracted from the specification carries exactly one
verdict of `Present`, `Surface`, `Absent`, `Incorrect`, or `Unverifiable` in
the record file. Any requirement with no verdict field, or a verdict value
outside that five-way set, fails the transition. `Unverifiable` is for a
requirement the reviewer genuinely cannot check from the given evidence —
distinct from `Absent` (verifiably not there). `draft-reported -> reported`
fails unless the model judges, from the user's own turn, that the draft was
confirmed as final — either by agreement or by an explicit
"publish with the disagreement noted" call.

**Refuses in every state**: reading the building agent's intent, reasoning,
or proposal prose, in `idle`, `scoped`, `auditing`, and `reported` alike —
this is not a state-dependent restriction, it is a standing one for the
whole role, mirroring why `review` is handed only the change and the
specification (Part 1).

## Reference

Full sourcing for every claim above is in
`docs/reports/research/2026-07-25-swpd-roles/`: `product-discovery.md`,
`design-ux.md`, `engineering-architecture.md`, `qa-testing.md`,
`release-ops-sre.md`, `security-legal-compliance.md`,
`data-experimentation.md`, `lifecycle-frameworks-handoffs.md`.

Gate mechanics with published, checkable criteria — not just a named
gate but a stated rule for what makes it fail — were found in exactly four
places across this research: Cooper's Stage-Gate must-meet/should-meet split,
Google's error-budget release-freeze policy, GDPR's Article 35 DPIA
requirement, and Shape Up's betting table. The strongest-enforced gate in
industry practice found anywhere in this research is ordinary code review,
because unlike the other four it has a mechanical blocking device attached
directly to the merge action rather than a process convention around it.
