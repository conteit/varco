#!/bin/bash
# SPDX-License-Identifier: Apache-2.0
# Host-side agent dispatcher (ADR-0016, ADR-0018). Stays compatible with macOS bash 3.2.
#   dispatch.sh plan <issue> | run [--max N] | status          (internal: _supervise <session-dir>)
# Env: DISPATCH_DRY_RUN=1  DISPATCH_REPO  DISPATCH_MILESTONE  DISPATCH_MAX  DISPATCH_SESSION_TIMEOUT_MIN
#      DISPATCH_WORKTREES  DISPATCH_ROOT  VARCO_AGENTS_HOME
set -euo pipefail
unset GH_TOKEN GITHUB_TOKEN GH_ENTERPRISE_TOKEN

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="${DISPATCH_ROOT:-$(cd "$HERE/../.." && pwd)}"
AGENTS_HOME="${VARCO_AGENTS_HOME:-$HOME/.varco-agents}"
DRY="${DISPATCH_DRY_RUN:-}"
MILESTONE="${DISPATCH_MILESTONE:-v1.0}"
MAX="${DISPATCH_MAX:-3}"
TIMEOUT_MIN="${DISPATCH_SESSION_TIMEOUT_MIN:-240}"
POLL="${DISPATCH_POLL:-5}"
WORKTREES="${DISPATCH_WORKTREES:-$ROOT/../varco-worktrees}"
APP_TOKEN="${VARCO_APP_TOKEN_CMD:-$HERE/app-token.sh}"
AGENT_PATH="${VARCO_AGENT_PATH:-$HOME/.local/share/mise/shims:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin}"
DGH_DIR="$AGENTS_HOME/dispatcher/gh"
LOCK="$AGENTS_HOME/dispatcher/lock"

umask 077
mkdir -p "$AGENTS_HOME/sessions" "$AGENTS_HOME/logs" "$AGENTS_HOME/dispatcher" "$AGENTS_HOME/hooks"
# shellcheck source=/dev/null
[ -f "$HOME/.config/varco-agents/env" ] && . "$HOME/.config/varco-agents/env"
REPO="${DISPATCH_REPO:-$(git -C "$ROOT" remote get-url origin | sed -E 's#^(git@github.com:|https://github.com/)##; s#\.git$##')}"

# --- output, dry-run, helpers ------------------------------------------------------------------
redact() { sed -E 's/gh[opsu]_[A-Za-z0-9_]{10,}/[redacted]/g; s/eyJ[A-Za-z0-9_=-]+\.[A-Za-z0-9_=-]+\.[A-Za-z0-9_=-]*/[redacted]/g'; }
say() { printf '%s\n' "$*" | redact; }
die() { say "dispatch: $*" >&2; exit 1; }
# act <description> <command...>: the only way to change anything. Dry-run prints instead of running.
act() {
  local desc="$1" out rc=0; shift
  if [ -n "$DRY" ]; then say "DRY-RUN: $desc"; return 0; fi
  out="$("$@" 2>&1)" || rc=$?
  [ -z "$out" ] || say "$out"
  return "$rc"
}
alive() { kill -0 "$1" 2>/dev/null; }
set_field() { jq --arg k "$2" --arg v "$3" '.[$k] = $v' "$1" > "$1.tmp" && mv "$1.tmp" "$1"; }

dgh() { GH_CONFIG_DIR="$DGH_DIR" gh "$@"; }
init_gh() { "$APP_TOKEN" varco-impl "$DGH_DIR" "$REPO"; }
api_all() { dgh api --paginate --slurp "$1" | jq -c 'add // []'; }

lock_instance() {
  if ! mkdir "$LOCK" 2>/dev/null; then
    ! alive "$(cat "$LOCK/pid" 2>/dev/null || echo 0)" || die "another dispatcher is running"
    rm -rf "$LOCK"; mkdir "$LOCK"
  fi
  echo $$ > "$LOCK/pid"
  trap 'rm -rf "$LOCK"' EXIT
}

running() {
  local n=0 f p
  for f in "$AGENTS_HOME"/sessions/*/session.json; do
    [ -f "$f" ] || continue
    p="$(jq -r '.pid // empty' "$f")"
    if [ -n "$p" ] && alive "$p"; then n=$((n + 1)); fi
  done
  echo "$n"
}

# Fill {{PLACEHOLDERS}} from P_* variables, validated: numbers and branch names only.
render() {
  local issue="${P_ISSUE:-}" pr="${P_PR:-}" round="${P_ROUND:-}" branch="${P_BRANCH:-}" model="${P_MODEL:-}" owner="${REPO%%/*}"
  [[ "$issue$pr$round" =~ ^[0-9]*$ ]] || die "bad numeric placeholder"
  [[ "$branch" =~ ^([a-z]+/[A-Za-z0-9]+-[a-z0-9-]+)?$ && "$model" =~ ^[a-z]*$ && "$owner" =~ ^[A-Za-z0-9-]+$ ]] || die "bad placeholder"
  sed -e "s|{{ISSUE}}|$issue|g; s|{{PR}}|$pr|g; s|{{ROUND}}|$round|g; s|{{BRANCH}}|$branch|g; s|{{MODEL}}|$model|g; s|{{OWNER}}|$owner|g" "$HERE/prompts/$1"
}

# --- sessions ------------------------------------------------------------------------------------
# Per-session --settings: committed template + the deny rules from origin/main (not the worktree copy).
write_settings() { # <session-dir> <worktree>
  local tmp_a tmp_b volume own others vars
  tmp_a="$(getconf DARWIN_USER_TEMP_DIR 2>/dev/null || echo "${TMPDIR:-/tmp}")"; tmp_a="${tmp_a%/}"
  case "$tmp_a" in /private/*) tmp_b="${tmp_a#/private}" ;; *) tmp_b="/private$tmp_a" ;; esac
  case "$ROOT" in /Volumes/*) volume="/Volumes/$(cut -d/ -f1 <<<"${ROOT#/Volumes/}")" ;; *) volume="$HOME" ;; esac
  GITDIR="$(cd "$ROOT" && cd "$(git rev-parse --git-common-dir)" && pwd)"
  own="$(git -C "$2" rev-parse --absolute-git-dir)"
  others="$(for d in "$GITDIR"/worktrees/*; do [ -d "$d" ] && [ "$d" != "$own" ] && echo "$d"; done | jq -R . | jq -sc .)"
  vars="$(jq -nc '$ARGS.named' --arg HOME "$HOME" --arg WORKTREE "$2" --arg GITDIR "$GITDIR" --arg TMP_A "$tmp_a" \
    --arg TMP_B "$tmp_b" --arg UID "$(id -u)" --arg AGENTS "$AGENTS_HOME" --arg SESSION "$1" --arg VOLUME "$volume")"
  git -C "$ROOT" show origin/main:.claude/settings.json | jq -c --argjson vars "$vars" --argjson others "$others" --slurpfile t "$HERE/session-settings.json" '
    .permissions.deny as $deny
    | reduce ($vars | to_entries[]) as $e ($t[0]; walk(if type == "string" then split("@\($e.key)@") | join($e.value) else . end))
    | .permissions.deny += $deny | .sandbox.filesystem.denyWrite += $others'
}

# launch <name> <role> <worktree> <model> <effort> <prompt-template> <extra-json>: writes the session dir, detaches the supervisor.
launch() {
  local dir="$AGENTS_HOME/sessions/$1"
  rm -rf "$dir"; mkdir -p "$dir/gh"
  git -C "$ROOT" show origin/main:.claude/hooks/block-attribution.sh > "$AGENTS_HOME/hooks/block-attribution.sh"
  chmod 700 "$AGENTS_HOME/hooks/block-attribution.sh"
  write_settings "$dir" "$3" > "$dir/settings.json"
  render "$6" > "$dir/prompt.md"
  jq -n --arg name "$1" --arg role "$2" --arg wt "$3" --arg model "$4" --arg effort "$5" --arg started "$(date -u +%FT%TZ)" \
    --argjson extra "$7" '{name: $name, role: $role, worktree: $wt, model: $model, effort: $effort, started: $started} + $extra' > "$dir/session.json"
  (cd "$3" && command -v mise >/dev/null && { mise trust -q; mise install -q; } >/dev/null 2>&1 || true)
  /usr/bin/python3 -c 'import os,sys; os.setsid(); os.execv(sys.argv[1], sys.argv[1:])' "$HERE/dispatch.sh" _supervise "$dir" \
    < /dev/null > /dev/null 2>&1 &
}

# Runs detached, one per session: token refresh, timeout, claude under a whitelisted environment, cleanup.
supervise() {
  # No `local`: the EXIT trap runs after this function returns.
  dir="$1" f="$1/session.json" sid="" cpid="" start=$SECONDS refreshed=$SECONDS rc=0
  name="$(jq -r .name "$f")"; role="$(jq -r .role "$f")"; wt="$(jq -r .worktree "$f")"
  model="$(jq -r .model "$f")"; effort="$(jq -r .effort "$f")"
  log="$AGENTS_HOME/logs/$name.log"
  app=varco-impl; [ "$role" != review ] || app=varco-reviewer
  claude="${VARCO_CLAUDE:-$(command -v claude)}"
  cleanup() {
    [ -z "$cpid" ] || ! alive "$cpid" || kill "$cpid" 2>/dev/null || true
    rm -rf "$dir/gh" "$dir/out"
    [ "$role" = implement ] || git -C "$ROOT" worktree remove --force "$wt" >/dev/null 2>&1 || true
    VARCO_SESSION_ID="$name" "$HERE/stack-lock.sh" release || true
    set_field "$f" ended "$(date -u +%FT%TZ)"
  }
  trap cleanup EXIT
  jq --argjson p "$$" '.pid = $p' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
  "$APP_TOKEN" "$app" "$dir/gh" "$REPO" || { set_field "$f" exit "token-failed"; exit 1; }
  cd "$wt"
  mkfifo "$dir/out"
  redact < "$dir/out" >> "$log" &
  rpid=$!
  env -i HOME="$HOME" PATH="$AGENT_PATH" USER="${USER:-}" LANG="${LANG:-en_US.UTF-8}" TMPDIR="${TMPDIR:-/tmp}" \
      GH_CONFIG_DIR="$dir/gh" VARCO_SESSION_ID="$name" VARCO_AGENTS_HOME="$AGENTS_HOME" \
    "$claude" -p "$(cat "$dir/prompt.md")" --model "$model" ${effort:+--effort "$effort"} --settings "$dir/settings.json" \
      --permission-mode dontAsk --permission-prompts none --output-format stream-json --verbose \
    < /dev/null > "$dir/out" 2>&1 &
  cpid=$!
  while alive "$cpid"; do
    sleep "$POLL"
    if [ -z "$sid" ]; then
      sid="$(jq -r 'select(.session_id != null) | .session_id' "$log" 2>/dev/null | head -n1 || true)"
      [ -z "$sid" ] || set_field "$f" session_id "$sid"
    fi
    if [ $((SECONDS - refreshed)) -ge 2700 ]; then "$APP_TOKEN" "$app" "$dir/gh" "$REPO" || true; refreshed=$SECONDS; fi
    if [ $((SECONDS - start)) -ge $((TIMEOUT_MIN * 60)) ]; then kill "$cpid" 2>/dev/null || true; set_field "$f" timeout true; fi
  done
  wait "$cpid" || rc=$?
  wait "$rpid" || true
  set_field "$f" exit "$rc"
}

# --- commands --------------------------------------------------------------------------------------
setup_worktree() { # <path>
  local bot_id; bot_id="$(dgh api 'users/varco-impl%5Bbot%5D' --jq .id)"
  git -C "$ROOT" config extensions.worktreeConfig true
  git -C "$1" config --worktree push.default current
  git -C "$1" config --worktree 'url.https://github.com/.insteadOf' 'git@github.com:'
  git -C "$1" config --worktree credential.helper ''
  git -C "$1" config --worktree --add credential.helper '!gh auth git-credential'
  git -C "$1" config --worktree core.hooksPath .githooks
  git -C "$1" config --worktree user.name 'varco-impl[bot]'
  git -C "$1" config --worktree user.email "$bot_id+varco-impl[bot]@users.noreply.github.com"
}

start_implementer() { # <issue> <id> <branch> <model>
  git -C "$ROOT" fetch -q origin main
  git -C "$ROOT" worktree add -q --no-track -b "$3" "$WORKTREES/$2" origin/main
  setup_worktree "$WORKTREES/$2"
  dgh issue edit "$1" --repo "$REPO" --add-label in-progress >/dev/null
  P_ISSUE="$1" P_BRANCH="$3" P_MODEL="$4" launch "$2" implement "$WORKTREES/$2" "$4" "" implement.md \
    "$(jq -nc --argjson i "$1" --arg b "$3" '{issue: $i, branch: $b}')"
}

start_planner() { # <issue>
  git -C "$ROOT" fetch -q origin main
  git -C "$ROOT" worktree add -q --detach "$WORKTREES/plan-$1" origin/main
  P_ISSUE="$1" launch "plan-$1" plan "$WORKTREES/plan-$1" opus high plan.md "$(jq -nc --argjson i "$1" '{issue: $i}')"
}

cmd_plan() {
  [[ "${1:-}" =~ ^[0-9]+$ ]] || die "usage: plan <issue-number>"
  init_gh
  act "start planner (opus, effort high) for #$1 in a fresh worktree of origin/main" start_planner "$1"
}

cmd_run() {
  local cap="$MAX" slots rows row n id branch model t
  [ "${1:-}" != --max ] || cap="${2:?}"
  init_gh
  slots=$((cap - $(running)))
  t="$(mktemp -d)"; trap 'rm -rf "$t"' RETURN
  api_all "repos/$REPO/issues?state=open&per_page=100" > "$t/issues"
  api_all "repos/$REPO/pulls?state=open&per_page=100" > "$t/prs"
  api_all "repos/$REPO/branches?per_page=100" | jq -c 'map(.name)' > "$t/branches"
  rows="$(jq -nc -L "$HERE/lib" --slurpfile i "$t/issues" --slurpfile p "$t/prs" --slurpfile b "$t/branches" \
    'include "dispatch"; {issues: $i[0], prs: $p[0], branches: $b[0]} | next_issues($ENV.MILESTONE)' )"
  while IFS= read -r row; do
    [ -n "$row" ] || continue
    if [ "$slots" -le 0 ]; then say "cap of $cap sessions reached; nothing more started"; break; fi
    n="$(jq -r .number <<<"$row")"; id="$(jq -r .id <<<"$row")"; branch="$(jq -r .branch <<<"$row")"; model="$(jq -r .model <<<"$row")"
    [ ! -e "$WORKTREES/$id" ] || { say "skip #$n: worktree $id already exists"; continue; }
    act "start implementer for #$n on $branch (model $model, worktree $id)" start_implementer "$n" "$id" "$branch" "$model" && slots=$((slots - 1))
  done <<<"$rows"
}

cmd_status() {
  local f
  init_gh
  say "== sessions"
  for f in "$AGENTS_HOME"/sessions/*/session.json; do
    [ -f "$f" ] || continue
    jq -r --arg alive "$(alive "$(jq -r '.pid // 0' "$f")" && echo running || echo ended)" '"\(.name)\t\(.role)\t\($alive)\texit=\(.exit // "-")"' "$f"
  done
  say "== worktrees"; git -C "$ROOT" worktree list
  say "== in progress"; dgh issue list --repo "$REPO" --label in-progress --json number,title --jq '.[] | "#\(.number) \(.title)"'
  say "== awaiting design or replan"
  for l in needs-design needs-replan; do dgh issue list --repo "$REPO" --label "$l" --json number,title --jq ".[] | \"#\(.number) [$l] \(.title)\""; done
  say "== open pull requests"; dgh pr list --repo "$REPO" --json number,title,author,isDraft --jq '.[] | "#\(.number) \(.author.login)\(if .isDraft then " (draft)" else "" end) \(.title)"'
}

export MILESTONE
case "${1:-}" in
  plan) lock_instance; cmd_plan "${2:-}" ;;
  run) lock_instance; shift; cmd_run "$@" ;;
  status) cmd_status ;;
  _supervise) supervise "${2:?}" ;;
  *) echo "usage: dispatch.sh plan <issue> | run [--max N] | status" >&2; exit 2 ;;
esac
