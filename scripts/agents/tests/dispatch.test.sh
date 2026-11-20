#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Offline tests for dispatch.sh: temp git origin, temp agents home, `gh`, `claude` and the token minter stubbed on PATH.
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
t="$(mktemp -d)"; trap 'rm -rf "$t"' EXIT
failed=0; fail() { echo "FAIL: $*"; failed=1; }

# --- fixtures -------------------------------------------------------------------------------------
git init -q --bare "$t/origin.git"
git clone -q "$t/origin.git" "$t/main" 2>/dev/null
mkdir -p "$t/main/.claude/hooks"
echo '{"permissions":{"deny":["Bash(env)"]}}' > "$t/main/.claude/settings.json"
echo '#!/bin/sh' > "$t/main/.claude/hooks/block-attribution.sh"
git -C "$t/main" add -A
git -C "$t/main" -c user.name=t -c user.email=t@example.com commit -q -m init
git -C "$t/main" push -q origin HEAD:main 2>/dev/null
git -C "$t/main" fetch -q origin

mkdir -p "$t/bin"
cat > "$t/bin/gh" <<STUB
#!/bin/sh
echo "\$*" >> "$t/gh.log"
case "\$*" in
  *issues?state=open*) echo '[[{"number":4,"title":"[A1] Test card","body":"","labels":[{"name":"agent-ready"},{"name":"wave:0"}],"author_association":"OWNER","user":{"login":"o"},"milestone":{"title":"v1.0"}}]]' ;;
  *pulls?state=open*) echo '[[]]' ;;
  *branches*) echo '[[{"name":"main"}]]' ;;
  *users/*) echo 111 ;;
esac
STUB
cat > "$t/bin/app-token" <<'STUB'
#!/bin/sh
mkdir -p "$2"; printf 'github.com:\n    oauth_token: ghs_FAKE0123456789abcdef\n' > "$2/hosts.yml"
STUB
cat > "$t/bin/claude" <<STUB
#!/bin/sh
echo "\$@" > "$t/claude.args"; env > "$t/claude.env"
echo '{"type":"system","session_id":"sess-1"}'
echo "leak ghs_FAKE0123456789abcdef and eyJhbGciOiJSUzI1NiJ9.eyJpc3MiOiIxIn0.c2lnbmF0dXJl"
STUB
chmod +x "$t/bin/"*

export PATH="$t/bin:$PATH" HOME="$t/home" VARCO_AGENTS_HOME="$t/agents" DISPATCH_ROOT="$t/main" DISPATCH_WORKTREES="$t/wt" \
  DISPATCH_REPO=o/r VARCO_APP_TOKEN_CMD="$t/bin/app-token" DISPATCH_POLL=0.2 GH_TOKEN="ghs_""LEAK0123456789abcdef"
mkdir -p "$HOME"
d="$here/../dispatch.sh"

# --- dry run ----------------------------------------------------------------------------------------
out="$(DISPATCH_DRY_RUN=1 "$d" run 2>&1)"
grep -q 'DRY-RUN: start implementer for #4 on feat/A1-test-card' <<<"$out" || fail "[A1] dry-run does not print the intended start: $out"
{ [ ! -e "$t/wt" ] && [ ! -e "$t/claude.args" ] && ! grep -q 'issue edit' "$t/gh.log"; } || fail "[A1] dry-run changed something"

out="$(DISPATCH_DRY_RUN=1 "$d" plan 4 2>&1)"
grep -q 'DRY-RUN: start planner (opus, effort high) for #4' <<<"$out" || fail "dry-run plan: $out"

# --- cap -----------------------------------------------------------------------------------------------
out="$(DISPATCH_MAX=0 "$d" run 2>&1)"
grep -q 'cap of 0' <<<"$out" && [ ! -e "$t/wt" ] || fail "[A1] cap reached must not start sessions: $out"

# --- real run ----------------------------------------------------------------------------------------------
out="$("$d" run 2>&1)"
sess="$t/agents/sessions/A1"
for _ in $(seq 1 100); do [ "$(jq -r '.ended // empty' "$sess/session.json" 2>/dev/null)" ] && break; sleep 0.2; done
[ -n "$(jq -r '.ended // empty' "$sess/session.json")" ] || fail "session did not finish"
[ "$(jq -r .exit "$sess/session.json")" = 0 ] && [ "$(jq -r .session_id "$sess/session.json")" = sess-1 ] || fail "session.json lacks exit/session_id"
git -C "$t/main" worktree list | grep -q 'feat/A1-test-card' || fail "worktree/branch not created"
grep -q 'issue edit 4 --repo o/r --add-label in-progress' "$t/gh.log" || fail "in-progress label not set"

if grep -q -e '--settings' "$t/claude.args" && grep -q -e '--model sonnet' "$t/claude.args"; then :; else fail "claude flags missing"; fi
grep -q '^GH_CONFIG_DIR=' "$t/claude.env" || fail "[A1] session lacks its own GH_CONFIG_DIR"
if grep -qE '^(GH_TOKEN|GITHUB_TOKEN|SSH_AUTH_SOCK|ANTHROPIC_[A-Z_]*)=' "$t/claude.env"; then fail "[A1] credential leaked into the session environment"; fi
grep -q 'GH_CONFIG_DIR=.*/sessions/A1/gh' "$t/claude.env" || fail "session uses another gh config dir"
[ ! -e "$sess/gh" ] || fail "[A1] session gh dir (token) not removed after exit"

s="$sess/settings.json"
jq -e '.sandbox.failIfUnavailable and (.sandbox.allowUnsandboxedCommands | not) and (.permissions.deny | index("Bash(env)")) and (.permissions.allow | index("Bash"))' "$s" >/dev/null \
  || fail "[A1] settings lack the guard set"
if grep -q '@[A-Z_]*@' "$s"; then fail "settings contain unreplaced placeholders"; fi
jq -e --arg g "$t/main/.git" '.sandbox.filesystem.denyWrite | index($g + "/hooks")' "$s" >/dev/null || fail "[A1] .git/hooks is not write-denied"

if grep -rqE 'ghs_FAKE|eyJhbGci' "$t/agents/logs" || grep -qE 'ghs_FAKE|ghs_LEAK|eyJhbGci' <<<"$out"; then fail "[A1] no secret in logs: token found"; fi
grep -q 'leak \[redacted\] and \[redacted\]' "$t/agents/logs/A1.log" || fail "[A1] redaction did not run on the session log"

status="$("$d" status 2>&1)"
grep -q 'A1.*implement.*ended' <<<"$status" || fail "status does not list the finished session"

[ "$failed" -eq 0 ] && echo "dispatch.test: ok"
exit "$failed"
