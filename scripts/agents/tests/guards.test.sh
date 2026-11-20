#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Offline tests for scripts/agents/guards.sh.
set -uo pipefail
g="$(dirname "$0")/../guards.sh"
failed=0

# expect <name> <pass|fail> <mode> <input>
expect() {
  local name="$1" want="$2" mode="$3" input="$4" rc=0
  printf '%s\n' "$input" | "$g" "$mode" >/dev/null 2>&1 || rc=$?
  if { [ "$want" = pass ] && [ "$rc" -ne 0 ]; } || { [ "$want" = fail ] && [ "$rc" -ne 1 ]; }; then
    echo "FAIL: $name (exit $rc)"; failed=1
  fi
}

ok_body=$'## Summary\n- x\n\n## Tests\n- y\n\nCloses #4'

expect "[A1] attribution trailer in commit fails" fail attribution $'feat: x\n\nCo-Authored-By: Claude <noreply@anthropic.com>'
expect "[A1] attribution in PR body fails" fail attribution $'## Summary\nGenerated with Claude Code'
expect "[A1] clean commit message passes" pass attribution $'feat: x\n\nSigned-off-by: A <a@example.com>'
expect "[A1] human co-author passes" pass attribution 'Co-authored-by: Jane <jane@example.com>'

expect "[A1] file under docs/plans/ fails" fail scratch-docs $'src/a.ts\ndocs/plans/x.md'
expect "[A1] PLAN.md fails" fail scratch-docs 'PLAN.md'
expect "[A1] nested HANDOFF-x.md fails" fail scratch-docs 'a/HANDOFF-x.md'
expect "[A1] NOTES.md fails" fail scratch-docs 'NOTES.md'
expect "[A1] .planning/ fails" fail scratch-docs '.planning/x.json'
expect "[A1] prompts/plan.md passes" pass scratch-docs 'scripts/agents/prompts/plan.md'

expect "[A1] valid PR body passes" pass pr-body "$ok_body"
expect "[A1] Part of passes" pass pr-body $'## Summary\n- x\n## Tests\n- y\nPart of #4'
expect "[A1] missing Tests fails" fail pr-body $'## Summary\n- x\nCloses #4'
expect "[A1] missing reference fails" fail pr-body $'## Summary\n- x\n## Tests\n- y'
expect "[A1] two references fail" fail pr-body "$ok_body"$'\nCloses #5'

[ "$failed" -eq 0 ] && echo "guards.test: ok"
exit "$failed"
