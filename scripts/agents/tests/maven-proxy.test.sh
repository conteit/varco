#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
set -uo pipefail
script="$(cd "$(dirname "$0")" && pwd)/../maven-proxy.sh"
failed=0

[ -z "$(env -u HTTPS_PROXY "$script")" ] || { echo "FAIL: prints a path without HTTPS_PROXY"; failed=1; }
f="$(HTTPS_PROXY=http://127.0.0.1:5555 "$script")"
for want in '<host>127.0.0.1</host>' '<port>5555</port>' 'localhost|127.0.0.1'; do
  grep -qF "$want" "$f" || { echo "FAIL: proxy settings lack $want"; failed=1; }
done

[ "$failed" -eq 0 ] && echo "maven-proxy.test: ok"
exit "$failed"
