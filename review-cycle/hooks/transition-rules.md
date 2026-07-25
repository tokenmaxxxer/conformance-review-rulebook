# review role — transition table

Single source of truth for legal `review-record.md` `status` transitions.
Read by both `inject-transition-rules.sh` (UserPromptSubmit) and
`state-gate.sh` (PreToolUse). Derived from `docs/specs/state-machine.md`'s
"States" (`idle`, `scoped`, `auditing`, `reported`) and "Transition table".

`actor` is `user` when the transition requires the user to have said
something in their own turn; `agent` when the agent may make it unprompted.

from | to | actor | precondition
--- | --- | --- | ---
(none) | idle | agent | review-record.md does not yet exist; agent creates it to begin the role at idle
idle | scoped | user | user hands the role a change plus a specification
scoped | auditing | agent | agent begins per-requirement verification
auditing | reported | user | every requirement carries a verdict and the user approves the report
