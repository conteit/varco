#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Mints a GitHub App installation token limited to one repo and writes it to <gh-config-dir>/hosts.yml (mode 600).
# Usage: app-token.sh <varco-impl|varco-reviewer> <gh-config-dir> [<owner>/<name>]
# The private key (base64 PEM) comes from the macOS Keychain item "<role>-key" and only ever lives in a pipe.
# Prints nothing. The JWT stays off argv: curl reads its header from a process substitution.
set -euo pipefail

role="${1:?role}" dir="${2:?gh-config-dir}"
case "$role" in
  varco-impl) app_var=VARCO_IMPL_APP_ID ;;
  varco-reviewer) app_var=VARCO_REVIEWER_APP_ID ;;
  *) echo "app-token: unknown role" >&2; exit 2 ;;
esac
# shellcheck source=/dev/null
[ -n "${!app_var:-}" ] || { [ -f "$HOME/.config/varco-agents/env" ] && . "$HOME/.config/varco-agents/env"; } || true
app_id="${!app_var:?$app_var is not set}"
repo="${3:-${DISPATCH_REPO:-$(git remote get-url origin | sed -E 's#^(git@github.com:|https://github.com/)##; s#\.git$##')}}"

b64url() { openssl base64 -A | tr '+/' '-_' | tr -d '='; }
now="$(date +%s)"
unsigned="$(printf '{"alg":"RS256","typ":"JWT"}' | b64url).$(printf '{"iat":%d,"exp":%d,"iss":"%s"}' $((now - 60)) $((now + 540)) "$app_id" | b64url)"
pem="$(security find-generic-password -s "$role-key" -w | openssl base64 -d -A)"
jwt="$unsigned.$(printf '%s' "$unsigned" | openssl dgst -sha256 -sign <(printf '%s\n' "$pem") | b64url)"

api() { curl -fsS -H @<(printf 'Authorization: Bearer %s\n' "$jwt") -H 'Accept: application/vnd.github+json' "$@"; }
installation="$(api "https://api.github.com/repos/$repo/installation" | jq -r .id)"
token="$(api -X POST -d "{\"repositories\":[\"${repo#*/}\"]}" "https://api.github.com/app/installations/$installation/access_tokens" | jq -r .token)"
[ -n "$token" ] && [ "$token" != null ] || { echo "app-token: no token returned for $role" >&2; exit 1; }

umask 077
mkdir -p "$dir"
tmp="$(mktemp "$dir/hosts.XXXXXX")"
printf 'github.com:\n    oauth_token: %s\n    user: %s[bot]\n    git_protocol: https\n' "$token" "$role" > "$tmp"
chmod 600 "$tmp"
mv "$tmp" "$dir/hosts.yml"
