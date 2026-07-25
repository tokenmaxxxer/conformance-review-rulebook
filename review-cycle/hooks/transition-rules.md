# review role — transition table

Single source of truth for legal `review-record.md` `status` transitions.
Read by both `inject-transition-rules.sh` (UserPromptSubmit) and
`state-gate.sh` (PreToolUse). Derived from
`docs/proposals/2026-07-28-role-workflow-plugins.md`'s `review` design,
which revises the state set to `idle`, `scoped`, `auditing`,
`draft-reported`, `reported` (`draft-reported` added between `auditing` and
`reported` — findings confirmed with the party being reviewed but not yet
published, per the Fagan-inspection follow-up / exit-conference draft
convention and the audit management-response pattern) and the verdict set
to `Present`, `Surface`, `Absent`, `Incorrect`, `Unverifiable`
(`Unverifiable` added for a requirement the reviewer genuinely cannot check
from the given evidence — distinct from `Absent`, which is verifiably not
there).

`actor` is `user` when the transition requires the user to have said
something in their own turn; `agent` when the agent may make it unprompted.
There is no approval-token mechanism: for an `actor: user` row, the model
reads the user's own turn, judges the precondition met, and records — as
one line appended to `review-record.md` — the user utterance it read as
the basis for the transition. Nothing mints or checks a token for this;
nothing enforces that the recorded line is accurate.

from | to | actor | precondition
--- | --- | --- | ---
(none) | idle | agent | review-record.md does not yet exist; agent creates it to begin the role at idle
idle | scoped | user | user hands the role a change plus a specification, and reviewer/auditee have agreed the engagement's scope and boundaries (entrance-conference equivalent)
scoped | auditing | agent | agent begins per-requirement verification; no further human input required to begin
auditing | auditing | user | reviewer needs evidence/access the party being reviewed must grant before a specific requirement can be checked — stays in auditing, not its own state
auditing | draft-reported | agent | every requirement carries exactly one verdict from Present, Surface, Absent, Incorrect, Unverifiable
draft-reported | draft-reported | user | the reviewed party disputes a finding; reviewer attempts resolution by clarification, recorded as a management-response-equivalent artifact attached to the finding, not a new state
draft-reported | reported | user | user (or a named governance-equivalent party) confirms the draft as final — either by agreement or by an explicit "publish with the disagreement noted" call
