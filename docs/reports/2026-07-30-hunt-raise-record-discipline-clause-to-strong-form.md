---
proposal: docs/issue-27/proposals/coding.md
---

# Hunt record — raise record-discipline clause to strong form

## after-proposal — stance: silent-failure / composition-regression check on review/hooks/directive.sh RECORD FORMAT edit

Verdict: FINDING — the appended "(Measured: ...)" citation is fabricated/untraceable, violating the record-discipline standard it is meant to enforce
Kind: design-error
Seed: appended sentences in review/hooks/directive.sh RECORD FORMAT section (lines ~66-68): "Ending phase 2 without your record committed on the branch means the record was never written. (Measured: a phase-1-only issue left the record empty.)"

### Reproduce
    git show ba79832 -- docs/issue-27/reports/coding/survey.md
    grep -rn "obligation is unmet\|left no record committed" . --include=*.md --include=*.sh
    grep -rn "Measured" --include=*.sh .
    find . -path ./.git -prune -o -iname "*directive*" -print

### Observed
The phase-1 survey (docs/issue-27/reports/coding/survey.md) justifies the wording by quoting a
"reference wording (strong form, from this session's own coding-role directive, which already
carries it)": "Ending phase 2 without your record committed on the branch means the obligation is
unmet. (Measured: a phase-1-only issue left no record committed.)" But `find . -iname
"*directive*"` shows the only directive file in this repo is review/hooks/directive.sh itself —
there is no coding-role directive.sh anywhere in the repo that "already carries" that wording. The
claimed source is unverifiable/nonexistent in this checkout.

Worse, the wording actually committed into review/hooks/directive.sh does not even match what the
survey quoted as its "reference": committed text says "means the record was never written" / "left
the record empty", while the survey's supposedly-sourced wording says "means the obligation is
unmet" / "left no record committed". The citation was rewritten in transit with no new
justification recorded — a "Measured:" claim (an evidentiary label this same directive requires to
be a real pointer, "never a paraphrase", per its own EXECUTION JUDGMENT evidence rule two
paragraphs above) that in fact points at nothing reproducible: no incident record, no other file,
no external directive present in this repo substantiates "a phase-1-only issue left the record
empty."

### Expected
A "(Measured: ...)" citation appended to a rule about evidentiary rigor should itself be backed by
a locatable prior incident (a report, an issue, a commit) — or, if the source directive is external
to this repo (e.g. ux-design-rulebook, as the issue text says), the survey should say so plainly
and not claim it was verified "in-session" from a file that does not exist here. As written, the
directive now instructs review-role agents to cite measured evidence for every finding while
itself carrying a measured-evidence citation nobody can trace.
