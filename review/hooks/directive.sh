#!/usr/bin/env bash
. "${CLAUDE_PLUGIN_ROOT_CORE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../core" && pwd -P)}/hooks/lib/role-directive.sh"
YOU_DECIDE="YOU DECIDE: whether what was built matches what was specified — a per-requirement verdict (Present|Surface|Absent|Incorrect|Unverifiable), never a holistic code-quality judgment, never a fix"
USE_WHEN="USE_WHEN: after a build reaches a reviewable state, working from the artifact and the spec, deliberately without the building agent's intent"
PRODUCES="PRODUCES (required record fields): extracted requirement list (or sampling derivation), per-requirement verdicts with diff-pointer evidence, code_under_review:, closed_checks cites keyed to that sha"
HAND_OFF="HAND-OFF: findings addressed_to the owning role; never fixed here"
core_role_directive "$YOU_DECIDE" "$USE_WHEN" "$PRODUCES" "$HAND_OFF"
