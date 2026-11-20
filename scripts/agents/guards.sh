#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Deterministic PR hygiene checks (ADR-0016 §4). Input on stdin, exit 1 + message on violation.
#   attribution   free text (commit messages, PR title/body)
#   scratch-docs  one changed file path per line
#   pr-body       PR body
set -euo pipefail

ATTRIBUTION_RE='(co-authored-by:.*(claude|anthropic|copilot|openai|gpt|gemini|cursor|codex))|noreply@anthropic\.com|generated (with|by) \[?(claude|ai)|🤖'
SCRATCH_RE='^(docs/plans/|docs/superpowers/|\.plans/|\.planning/)|(^|/)(PLAN\.md|HANDOFF[^/]*\.md|NOTES[^/]*\.md)$'
LINK_RE='(^|[^[:alnum:]])((closes|fixes|resolves) |part of )#[0-9]+'

fail() { echo "guards: $*" >&2; exit 1; }

case "${1:-}" in
  attribution)
    if grep -Eiq "$ATTRIBUTION_RE"; then fail "AI co-authorship/attribution is forbidden (ADR-0016)."; fi ;;
  scratch-docs)
    hits="$(grep -E "$SCRATCH_RE" || true)"
    [ -z "$hits" ] || fail "scratch/plan files must not be committed (ADR-0016):
$hits" ;;
  pr-body)
    body="$(cat)"
    for h in Summary Tests; do
      printf '%s\n' "$body" | grep -Eq "^##[[:space:]]+${h}[[:space:]]*$" || fail "PR body is missing a '## $h' section."
    done
    n="$(printf '%s\n' "$body" | grep -Eio "$LINK_RE" | wc -l | tr -d ' ')"
    [ "$n" -eq 1 ] || fail "PR body must contain exactly one 'Closes #n' or 'Part of #n' reference (found $n)." ;;
  *) echo "usage: guards.sh attribution|scratch-docs|pr-body < input" >&2; exit 2 ;;
esac
