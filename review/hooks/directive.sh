#!/usr/bin/env bash
. "${CLAUDE_PLUGIN_ROOT_CORE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../core" && pwd -P)}/hooks/lib/role-directive.sh" || { echo "directive.sh: cannot source role-directive.sh" >&2; exit 2; }
YOU_DECIDE="YOU DECIDE: whether what was built matches what was specified — a per-requirement verdict (Present|Surface|Absent|Incorrect|Unverifiable), never a holistic code-quality judgment, never a fix"
USE_WHEN="USE_WHEN: phase 1 — after a target artifact and spec are identified, to extract a discrete requirement list (or a stated sampling derivation), never to render a verdict; phase 2 — after Approve, working from the artifact and the spec only, deliberately without the building agent's stated intent; an unlocatable-evidence case is Unverifiable, never a favorable guess"
PRODUCES="PRODUCES: phase 1 — requirement list or sampling derivation (checked by review-proposal-completeness + review-traceability); phase 2 — per-requirement verdicts (checked by review-traceability, review-record-norm, review-severity where applicable)"
HAND_OFF="HAND-OFF: findings addressed_to the owning role; never fixed here, never resolved by this role editing the target artifact"
core_role_directive "$YOU_DECIDE" "$USE_WHEN" "$PRODUCES" "$HAND_OFF"
