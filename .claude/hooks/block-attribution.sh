#!/usr/bin/env bash
# PreToolUse hook (ADR-0016 §2). Blocks AI co-authorship/attribution in commits,
# PR and issue text, pushes to main and hook bypasses. Exit 2 = block; stderr goes back to the agent.
set -euo pipefail

input="$(cat)"
cmd="$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null || true)"
[ -z "$cmd" ] && exit 0

ATTRIBUTION_RE='(co-authored-by:[^\n]*(claude|anthropic|copilot|openai|gpt|gemini|cursor|codex))|noreply@anthropic\.com|generated (with|by) \[?(claude|ai)|🤖'

block() { echo "BLOCKED by .claude/hooks/block-attribution.sh: $1" >&2; exit 2; }

scan_text() {
  if printf '%s' "$1" | grep -Eiq "$ATTRIBUTION_RE"; then
    block "AI co-authorship/attribution is forbidden in this repo (ADR-0016). Remove it and retry."
  fi
}

case "$cmd" in
  *"git commit"*|*"gh pr create"*|*"gh pr edit"*|*"gh pr comment"*|*"gh issue create"*|*"gh issue comment"*|*"gh issue edit"*)
    scan_text "$cmd"
    # also scan files passed with -F/--file/--body-file
    for f in $(printf '%s' "$cmd" | grep -Eo '(--body-file|--file|-F)[ =][^ ]+' | sed -E 's/^(--body-file|--file|-F)[ =]//'); do
      [ -f "$f" ] && scan_text "$(cat "$f")"
    done
    ;;
esac

if printf '%s' "$cmd" | grep -Eq 'git push.*([[:space:]]|:)main([[:space:]]|$)'; then
  block "Direct pushes to main are forbidden. Push your feature branch and open a PR."
fi
if printf '%s' "$cmd" | grep -Eq -- '--no-verify|git commit[^|;&]* -n( |$)'; then
  block "Bypassing git hooks is forbidden."
fi
exit 0
