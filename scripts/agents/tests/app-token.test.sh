#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Offline test for app-token.sh: throwaway RSA key, stubbed `security` and `curl`; nothing is committed.
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
t="$(mktemp -d)"; trap 'rm -rf "$t"' EXIT
mkdir "$t/bin"; failed=0
fail() { echo "FAIL: $*"; failed=1; }

openssl genrsa -out "$t/key.pem" 2048 2>/dev/null
openssl rsa -in "$t/key.pem" -pubout -out "$t/pub.pem" 2>/dev/null
cat > "$t/bin/security" <<STUB
#!/bin/sh
openssl base64 -A < "$t/key.pem"
STUB
cat > "$t/bin/curl" <<STUB
#!/bin/sh
for a in "\$@"; do case "\$a" in @*) cat "\${a#@}" > "$t/header" ;; esac; url="\$a"; done
case "\$url" in
  */installation) echo '{"id":42}' ;;
  */access_tokens) echo '{"token":"ghs_FAKE0123456789abcdef"}' ;;
esac
STUB
chmod +x "$t/bin/"*

out="$(HOME="$t" PATH="$t/bin:$PATH" VARCO_IMPL_APP_ID=123 "$here/../app-token.sh" varco-impl "$t/gh" o/r 2>&1)" || fail "app-token exited non-zero: $out"
[ -z "$out" ] || fail "[A1] app-token printed output"
grep -q 'oauth_token: ghs_FAKE0123456789abcdef' "$t/gh/hosts.yml" || fail "hosts.yml lacks the token"
[ "$(stat -c %a "$t/gh/hosts.yml" 2>/dev/null || stat -f %Lp "$t/gh/hosts.yml")" = 600 ] || fail "hosts.yml is not mode 600"

jwt="$(sed -n 's/^Authorization: Bearer //p' "$t/header")"
IFS=. read -r h p s <<<"$jwt"
b64d() { local x="${1//-/+}"; x="${x//_//}"; while [ $(( ${#x} % 4 )) -ne 0 ]; do x="$x="; done; printf '%s' "$x" | openssl base64 -d -A; }
b64d "$s" > "$t/sig.bin"
printf '%s' "$h.$p" | openssl dgst -sha256 -verify "$t/pub.pem" -signature "$t/sig.bin" >/dev/null || fail "JWT signature does not verify"
b64d "$p" | jq -e '.iss == "123" and (.exp - .iat) <= 600' >/dev/null || fail "JWT claims wrong (iss, or exp-iat > 600)"

[ "$failed" -eq 0 ] && echo "app-token.test: ok"
exit "$failed"
