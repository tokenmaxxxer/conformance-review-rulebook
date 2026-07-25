# tokenmaxxxer / review-agent-rulebook

A Claude Code plugin marketplace implementing the `review` agent role
specified in the tokenmaxxxer org's `docs/specs/agent-roles.md`: an agent
that decides whether what was built matches what was specified — a
per-requirement verdict, never a holistic code-quality judgment, and never a
fix.

## The role

**Decides**: whether what was built is what was specified.

**Given to start**: the change, and the specification it is meant to
satisfy — deliberately without the building agent's intent, reasoning, or
proposal prose. This role refuses to read that in every state, mirroring
why security/privacy review works from the artifact and a DPIA rather than
from the implementer's stated intent.

**Produces**: a verdict of `Present`, `Surface`, `Absent`, or `Incorrect`
for every requirement in the specification.

**Prevents**: a surface imitation of a requirement passing as a genuine
implementation — the most game-able failure mode when the entity grading
the work also built it.

Full state machine, transition table, rejection rule, and the standing
refusal rule's enforcement are in
[`docs/specs/state-machine.md`](docs/specs/state-machine.md).

## How it works

Two cooperating hooks in the `review-cycle` plugin implement the state
machine:

- **`hooks/capture-approval.sh`** (`UserPromptSubmit`) — mints a single-use
  approval token only from an unambiguous statement in the user's own turn
  (never from a file, a comment, or a tool result), and emits the standing
  directive steering the four verdicts and the intent-refusal rule.
- **`hooks/state-gate.sh`** (`PreToolUse`, matcher `.*`) — refuses the
  `auditing -> reported` transition unless every requirement in
  `review-record.md` carries a valid verdict AND a matching token is
  present, evaluated against the target path regardless of which tool
  performs the write (a `Bash` redirect, `sed -i`, `cp`, `mv`, or `tee`
  targeting the state file is caught the same way a `Write`/`Edit` call
  is). The same gate stands in every state to refuse reading the building
  agent's intent, proposal, or scratch content, by path shape, across
  `Read`, `Grep`, `Glob`, `NotebookEdit`, and `Bash`.

Both hooks fail closed: malformed input, an unreadable state file, or a
missing/mismatched token all deny the action rather than allowing it.

## Install

```
curl -fsSL https://raw.githubusercontent.com/tokenmaxxxer/review-agent-rulebook/main/install.sh | bash
```

This registers the `tokenmaxxxer-review` marketplace and installs
`review-agent-env` (which pulls in `review-cycle` as a dependency) at
**user scope**. It applies to your account on every machine-local session;
it does not travel with a repo and does not reach Claude Code on the web or
Slack cloud sessions. It names no other repository and no other
marketplace.

The script prefers a real `claude` CLI (standalone, or the binary bundled
inside the VSCode extension) if it finds one. If no `claude` binary is found
— or `TOKENMAXXXER_SETTINGS_ONLY=1` is set to force it — it falls back to
writing `~/.claude/settings.json` directly: it resolves and prefix-checks
the settings path against your home directory before writing anything,
aborts untouched on a parse failure of an existing file, backs the file up
first, and writes through a symlink rather than replacing it.

Or, from any Claude Code session, the equivalent by hand:

```
/plugin marketplace add tokenmaxxxer/review-agent-rulebook
/plugin install review-agent-env@tokenmaxxxer-review
```

`install.sh --help` prints usage. The only other input it reads is
`TOKENMAXXXER_SETTINGS_ONLY=1`.

## Writing the settings by hand

```json
{
  "extraKnownMarketplaces": {
    "tokenmaxxxer-review": {
      "source": { "source": "github", "repo": "tokenmaxxxer/review-agent-rulebook" }
    }
  },
  "enabledPlugins": {
    "review-agent-env@tokenmaxxxer-review": true
  }
}
```

## The carrying artifact

`review-record.md`, at the root of the project under review. Its
frontmatter `status` field holds the state (`idle`, `scoped`, `auditing`,
`reported`); below it, one block per requirement carries `requirement:` and
`verdict:`. See `docs/specs/state-machine.md` for the exact shape and every
gate rule.

## Handoff protocol (contract SHA `2affe5db7dfb285abaa2860d3004edb3f97c9aec`)

Excerpt only — review's own rows from the shared, cross-repo
`docs/specs/role-handoff-contract.md` (root `tokenmaxxxer` repo), pinned at
commit `2affe5db7dfb285abaa2860d3004edb3f97c9aec`. Not a restatement of the
full contract; read the contract itself for anything not covered here.

### ACCEPTS

`build-proposal` (the change) and the `hypothesis` / `feasibility-record`
that specify what the change was supposed to do. Must refuse any artifact
declaring `kind` in `{hypothesis, build-proposal}` when read for its
narrative body (`## Request`, `## Constraints`, `## What will be done`,
`## Out of scope`) — refusal by declared `kind`, not by path. Review may
still read a `build-proposal`'s `files:` frontmatter field to resolve the
diff's scope.

### WHERE UPSTREAM LIVES

- `build-proposal` — `docs/proposals/<date>-build-<slug>.md` (`files:`
  frontmatter field only).
- `hypothesis` — `docs/proposals/<date>-<slug>.md`.
- `feasibility-record` — `docs/reports/records/<subject>/feasibility.md`.

Both `hypothesis` and `feasibility-record` are read for their specification
content, not as narrative intent.

### PRODUCES

- `review-record` at `docs/reports/records/<subject>/review.md`. Required
  fields: role status (`idle,scoped,auditing,draft-reported,reported`),
  plus the common header, including `handoff_status: provisional | final`.
- Inline `finding` blocks within `review-record`. Required fields:
  `requirement`, `verdict` (`Present|Surface|Absent|Incorrect|Unverifiable`),
  `evidence`, `rationale`, `spec_vs_built` (required only when
  `verdict: Incorrect`).
- `finding` is the kind `coding` now accepts as its route back into a fix
  (a `verdict: Absent|Incorrect|Surface` finding closes the review -> coding
  -> qa cycle); the `review-record` as a whole stays out of coding's scope
  — only its inline `finding` blocks are accepted there.

### STOPS

- Upstream stale at role entry: the recorded `sha` for whichever of
  `build-proposal`/`hypothesis`/`feasibility-record` was read no longer
  matches that path's current `sha` — stop before doing further work, ask
  the user.
- An existing record already at a path review does not own under
  `docs/reports/records/` — refuse to write, report the conflict, never
  overwrite.
- Input carrying `handoff_status: provisional` — refuse to treat it as
  final baseline input for a verdict or as the recorded `upstream` entry
  for the staleness check.

## Kill switch

```sh
export REVIEW_CYCLE_DISABLE=1
```

Disables both hooks.

## Repo layout

- `install.sh` — the one-shot installer described above.
- `.claude-plugin/marketplace.json` — the marketplace manifest.
- `review-cycle/` — the role plugin: `hooks/`, `skills/review-cycle/`.
- `review-agent-env/` — the bundle plugin; no code of its own, lists
  `review-cycle` as a dependency.
- `docs/` — `specs/` (state machine, authoritative), `handbooks/`,
  `decisions/`, `reports/`, `proposals/`, `_assets/`.

## Scope

This repository is fully self-contained: no shared code, no cross-repo
dependency, and no file shared with `coding-agent-rulebook`,
`qa-agent-rulebook`, or any sibling `<role>-agent-rulebook` repository. It
never reads another role's repository, and it never talks to another agent
directly — the user carries the review's conclusion forward by hand.
