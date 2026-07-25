---
status: specs
---

# review role — state machine

Transcribed from `docs/specs/agent-roles.md` (Part 1 "`review`" and Part 3
"`review`") in the org's central spec repository, in this repository's own
words, so this repository is self-contained and does not depend on reading
that one at runtime. If the two ever disagree, the central spec is
authoritative and this file should be brought back into line with it.

## What this role decides

Whether what was built is what was specified — a per-requirement verdict,
never a holistic judgment of code quality.

## What it is given to start, and what it refuses to read

Given: the change, and the specification it is meant to satisfy.

Refused, in every state without exception: the building agent's intent,
reasoning, or proposal prose. This is not a state-dependent restriction; it
is a standing rule for the whole role, because a review argued from what the
builder says they meant is not independent of the builder. It mirrors the
qa-cycle's own discipline of working from what is observed rather than from
what the target team says it meant, and the reason security/privacy review
works from an artifact and a DPIA rather than from the implementer's stated
intent.

**Enforcement.** A path is the only thing a mechanical gate can check here —
it cannot judge whether prose pasted inline in chat is "the building agent's
intent" the way it can judge a file path. So enforcement splits in two:

- `review-cycle/hooks/state-gate.sh` (`PreToolUse`, matcher `.*`) refuses,
  regardless of tool, any read whose target path matches:
  - anything under `docs/proposals/**` (this org's own convention, per
    `coding-agent-rulebook`'s `doctrine` and `warrant` plugins, for where a
    proposal or RFC lives), or
  - any path whose filename contains `proposal`, `intent`, `notes`, or
    `scratch`, case-insensitively (covers a coding agent's own working or
    scratch files and intent notes, which are not confined to one directory
    across every possible target project).

  This is checked the same way for `Read`, `Grep` (`path`/`pattern`),
  `Glob` (`path`/`pattern`), `NotebookEdit` (`notebook_path`), and for
  `Bash`: every whitespace/shell-metacharacter-delimited token in the
  command string is checked against the same pattern, so `cat`, `less`,
  `grep`, `sed -n`, `head`, `tail`, or any other command that names such a
  path as an operand is caught the same way a direct `Read` call would be.
  Erring toward over-matching is deliberate here: the cost of a false
  refusal is an extra turn; the cost of a false negative is the standing
  rule silently not applying.
- The plugin's directive (emitted by `hooks/capture-approval.sh` on every
  `UserPromptSubmit`) covers what no path check can: refusing to work from
  proposal or intent text pasted directly into a chat turn, with no file
  behind it at all. That half is direction, not a gate — there is no tool
  input to check a path against when the content arrives as prose in the
  turn itself.

## Carrying artifact

`review-record.md`, at the root of the project under review (the path is
configurable via `REVIEW_RECORD_NAME`, default `review-record.md`; both
hooks read the same environment variable so they never disagree about the
file's name). Its state lives in a YAML-frontmatter-shaped header block's
`status` field:

```markdown
---
status: auditing
---
```

Below the header, the file holds zero or more requirement blocks, each its
own `---`-delimited block (recognized only when opened and closed by a line
that is exactly `---`, the same block-recognition discipline
`qa-agent-rulebook`'s `state.md` uses):

```markdown
---
requirement: <requirement text or id, verbatim from the specification>
verdict: Present
---
```

A block is the header if it carries a `status:` key and no `requirement:`
key; every other block is a requirement block and must carry exactly one
`requirement:` key and exactly one `verdict:` key to be well-formed.

## States

`idle`, `scoped`, `auditing`, `reported`.

## Transition table

| From | To | Fires on |
|---|---|---|
| `idle` | `scoped` | user hands the role a change plus a specification |
| `scoped` | `auditing` | agent begins per-requirement verification |
| `auditing` | `reported` | **gated** — every requirement has a verdict, and the user approves |

## Rejection rule — `auditing -> reported`

Refused unless **both**:

1. **Content condition.** Every requirement block in `review-record.md`
   carries exactly one verdict, and that verdict is exactly one of
   `Present`, `Surface`, `Absent`, `Incorrect`. A requirement with no
   `verdict:` line, more than one, an empty value, or a value outside that
   four-item set fails the transition. A file with zero requirement blocks
   also fails — an empty audit is not a complete one.
2. **Approval condition.** A single-use approval token exists at
   `.review/tokens/report.token` (relative to the project root), minted by
   `hooks/capture-approval.sh` from the user's own turn, and it names
   `file: review-record.md` and `transition: auditing -> reported` exactly.
   Content alone is never consent — a file with every verdict filled in but
   no token does not pass.

The token is minted only from an unambiguous approving statement in the
user's own turn (e.g. "I approve this review", "accept the report", "sign
off on the verdicts") — never inferred from a file, a comment, or a tool
result, and never from a bare "ok"/"looks good"/thumbs-up. It is consumed
(deleted) by the same gate call that allows the write it authorizes, so it
cannot be replayed.

**Evaluated on the target path, not the tool.** Per
`docs/specs/agent-roles.md` Part 3: "a rejection rule is evaluated against
the path being written, never against which tool performs the write." A
guard that only inspects `Write`/`Edit` tool payloads is bypassed by the
same edit made through a shell redirect (`echo ... > review-record.md`),
`sed -i`, `cp`, `mv`, or `tee`. `hooks/state-gate.sh` closes this by also
scanning `Bash` command strings for the state file's basename alongside a
write-shaped construct (`>`, `>>`, `tee`, `cp`, `mv`, `sed -i`, `perl -i`,
`dd`, `install`, `truncate`) and, when found, treating the call as a
candidate write to the state file.

For a `Write`/`Edit` call, the gate can read the *attempted* new content
directly out of `tool_input` and check both conditions against it. For a
`Bash` call, the resulting content is not knowable before the shell
executes, so the gate does not assume the write is safe: it forces the
attempted status to `reported` unconditionally for any Bash call that
touches the state file, which routes the call through the exact same
content-and-token checks as a direct write into `reported` would need. A
Bash-mediated write to `review-record.md` therefore can only ever succeed
when the file already satisfies the content condition and a valid token is
already present — there is no path through Bash that skips the checks a
`Write` call would face.

## Fails closed

Every one of these denies the tool call (exit 2) rather than allowing it:
unparseable or missing JSON on stdin, a payload that is not an object, an
unreadable `tool_input` on a tool this gate inspects, a missing or unreadable
`review-record.md` once a candidate write to it is detected, unreadable
attempted content on a `Write`/`Edit` call, an unreadable or malformed
approval token, or a token whose `file`/`transition` fields do not match
exactly. `python3` itself being unavailable is also a refusal, not a
fall-through — this gate protects a human-approval boundary, so a missing
interpreter must not silently let a write through.

## Refuses while in each state

- **`idle`**: refuses to scope anything — no change or specification has
  been handed over yet.
- **`scoped`**: refuses to render any verdict before auditing begins.
- **`auditing`**: refuses to skip any requirement extracted from the
  specification, and refuses to merge the four verdicts into a bare
  pass/fail.
- **`reported`**: refuses to revise a published verdict without the user
  reopening the role with a new change or specification — the record is not
  edited in place once reported.
- **All states**: refuses to read the building agent's intent, reasoning, or
  proposal prose (see above), and refuses to edit, patch, or "fix" the code
  under review — this role reports, it does not build.

## Kill switch

`export REVIEW_CYCLE_DISABLE=1` disables both hooks
(`hooks/capture-approval.sh`, `hooks/state-gate.sh`); unset, empty, `0`,
`false`, `no`, or `off` all mean active.
