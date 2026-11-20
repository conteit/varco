#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Maven ignores HTTPS_PROXY. When the sandbox proxy is set, write a settings file for it and print its path.
set -euo pipefail
[ -n "${HTTPS_PROXY:-}" ] || exit 0

hostport="${HTTPS_PROXY#*://}"; hostport="${hostport##*@}"; hostport="${hostport%%/*}"
host="${hostport%%:*}" port="${hostport##*:}"
[ "$port" != "$host" ] || port=80
out="$(cd "$(dirname "$0")/../.." && pwd)/build/maven-proxy-settings.xml"
mkdir -p "$(dirname "$out")"
cat > "$out" <<XML
<settings>
  <proxies>
    <proxy>
      <id>sandbox</id><active>true</active><protocol>https</protocol>
      <host>$host</host><port>$port</port>
      <nonProxyHosts>localhost|127.0.0.1</nonProxyHosts>
    </proxy>
  </proxies>
</settings>
XML
echo "$out"
