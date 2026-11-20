#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Offline tests for scripts/agents/review-gate.sh: each case edits the happy-path fixture with jq.
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
gate="$here/../review-gate.sh"
base="$here/testdata/gate-ok.json"
failed=0

# expect <name> <pass|fail> <jq edit> [stdout-grep]
expect() {
  local name="$1" want="$2" edit="$3" pat="${4:-}" out rc=0
  out="$(jq "$edit" "$base" | "$gate" --owner the-owner --budget 600 2>&1)" || rc=$?
  if { [ "$want" = pass ] && [ "$rc" -ne 0 ]; } || { [ "$want" = fail ] && [ "$rc" -ne 1 ]; }; then
    echo "FAIL: $name (exit $rc): $out"; failed=1
  elif [ -n "$pat" ] && ! printf '%s' "$out" | grep -q "$pat"; then
    echo "FAIL: $name (output lacks '$pat'): $out"; failed=1
  fi
}

reviewer='{"login":"varco-reviewer[bot]","type":"Bot"}'
needs_human='{"name":"needs-human"}'

expect "[A1] happy path passes" pass '.'
expect "[A1] stale approval after new push fails" fail '.pr.head.sha = "def456"' '(a)'
expect "[A1] later REQUEST_CHANGES fails" fail ".reviews += [{user: $reviewer, state:\"CHANGES_REQUESTED\", commit_id:\"abc123\", submitted_at:\"2026-01-02T11:00:00Z\"}]" '(a)'
expect "[A1] later REQUEST_CHANGES by another user fails" fail '.reviews += [{user:{login:"x",type:"User"}, state:"CHANGES_REQUESTED", commit_id:"abc123", submitted_at:"2026-01-02T11:00:00Z"}]' '(a)'
expect "[A1] dismissed REQUEST_CHANGES passes" pass '.reviews += [{user:{login:"x",type:"User"}, state:"DISMISSED", commit_id:"abc123", submitted_at:"2026-01-02T11:00:00Z"}]'
expect "[A1] approval by another identity fails" fail '.reviews[0].user = {login:"conteit",type:"User"}' '(a)'
expect "[A1] approval from a user named like the bot fails" fail '.reviews[0].user.type = "User"' '(a)'

expect "[A1] needs-human present fails" fail ".pr.labels = [$needs_human]" '(b)'
expect "[A1] needs-human removed by bot fails" fail '.events = [{event:"labeled",label:{name:"needs-human"},actor:{login:"o"},created_at:"2026-01-01T00:00:00Z"},{event:"unlabeled",label:{name:"needs-human"},actor:{login:"varco-impl[bot]"},created_at:"2026-01-01T01:00:00Z"}]' '(b)'
expect "[A1] needs-human removed by owner passes" pass '.events = [{event:"labeled",label:{name:"needs-human"},actor:{login:"o"},created_at:"2026-01-01T00:00:00Z"},{event:"unlabeled",label:{name:"needs-human"},actor:{login:"the-owner"},created_at:"2026-01-01T01:00:00Z"}]'

expect "[A1] failed other check fails" fail '.checks += [{name:"e2e",result:"failure"}]' '(c)'
expect "[A1] failed status fails" fail '.checks += [{name:"ci/x",result:"error"}]' '(c)'
expect "[A1] pending other check passes" pass '.checks += [{name:"e2e",result:null}]'

expect "[A1] missing Closes fails" fail '.pr.body = "## Summary"' '(e)'
expect "[A1] two references fail" fail '.pr.body += "\nFixes #8"' '(e)'
expect "[A1] closed issue fails" fail '.issue.state = "closed"' '(e)'
expect "[A1] reference to a PR fails" fail '.issue.pull_request = {}' '(e)'
expect "[A1] Part of passes" pass '.pr.body = "Part of #7"'
expect "[A1] dependabot exempt from (e) only" pass '.pr.user = {login:"dependabot[bot]",type:"Bot"} | .pr.body = "" | .issue = null'
expect "[A1] dependabot still needs approval" fail '.pr.user = {login:"dependabot[bot]",type:"Bot"} | .pr.body = "" | .issue = null | .reviews = []' '(a)'

expect "[A1] size over budget fails" fail '.files[0].additions = 700' '(d)'
expect "[A1] owner approval overrides budget" pass '.files[0].additions = 700 | .reviews += [{user:{login:"the-owner",type:"User"},state:"APPROVED",commit_id:"abc123",submitted_at:"2026-01-02T12:00:00Z"}]'
expect "[A1] generated files excluded" pass '.files += [{filename:"pnpm-lock.yaml",additions:9000,deletions:0},{filename:"e2e/__screenshots__/a.png",additions:5000,deletions:0},{filename:"x.snap",additions:5000,deletions:0}]'

printf '{"pr":' | "$gate" --owner o --budget 600 >/dev/null 2>&1; [ $? -eq 2 ] || { echo "FAIL: bad input must exit 2"; failed=1; }

[ "$failed" -eq 0 ] && echo "review-gate.test: ok"
exit "$failed"
