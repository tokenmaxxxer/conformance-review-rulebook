---
proposal: docs/issue-49/proposals/implementation.md
---

# Hunt record — align-rulebook-vocabulary-with-conformance-review-spec

## before-landing — stance 0: assume the gate just touched is bypassable — find the bypass

Verdict: FINDING — the new USE_WHEN "board condition" clause claims a trigger state (commit landed AND no conformance-review record exists for its sha) that no script in the repo ever evaluates; it is inert prose printed by a SessionStart hook, not a gate.
Kind: design-error
Seed: review/hooks/directive.sh — one-line USE_WHEN append: "; per the marketplace conformance-review role spec's board condition (issue-521): an implementation commit landed on the branch AND no conformance-review record exists yet for this commit sha"
cap_seconds: 120
tier: default
diff_stat_lines: 77 insertions, 8 deletions across 4 files
started_at: 2026-08-09T03:21:51+09:00
ended_at: 2026-08-09T03:30:00+09:00

### Reproduce
```
cd conformance-review-rulebook-issue-49-implementation
grep -rn "board_condition\|commit sha" --include=*.sh .   # -> no hits at all
CLAUDE_ROLE=review bash review/hooks/directive.sh          # dump the directive text
```

### Observed
grep finds zero references to "board_condition" or "commit sha" anywhere in *.sh files -- the string exists only inside the USE_WHEN literal in review/hooks/directive.sh. Running the hook just echoes the sentence to stdout at SessionStart; nothing parses the sentence, nothing checks git log for a landed implementation commit, nothing checks for an existing conformance-review report. The "board condition" reads as an operative trigger ("an implementation commit landed... AND no conformance-review record exists yet...") but is pure narration with no enforcement path -- the review role's SessionStart hook will print this sentence regardless of whether the stated condition holds or not, and nothing else in the repo consults it.

Note: this was also checked against the bash-3.2 parse-check concern raised in the task (apostrophe inside a nested heredoc breaking the bash-3.2 parser). That mechanism does not apply here -- the edit stayed inside a plain double-quoted VAR= assignment (no heredoc nesting), and tests/parse-check.sh reports "ok directive.sh" even under /bin/bash -n. The finding above is a different, real defect surfaced while checking that path.

### Expected
Either the USE_WHEN sentence should not phrase a condition ("board condition... commit landed AND no record exists") as if it gates anything, or some hook should actually evaluate that condition (check commit history against existing conformance-review report files) so the directive text matches real gate behavior. As written, nothing distinguishes "condition true, hook fired correctly" from "condition false, hook fired anyway" -- the sentence and the SessionStart print are two unconnected things wearing the same words.
