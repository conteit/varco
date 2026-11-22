#!/bin/sh
# SPDX-License-Identifier: Apache-2.0
# Install hook of the varco-toolchain mixin: runs once as root when a sandbox is created.
set -eu

proxy_ca=/usr/local/share/ca-certificates/proxy-ca.crt
export MISE_DATA_DIR=/opt/mise
# The hook runs as root with the agent's HOME; keep mise's root-owned state out of it.
export HOME=/root

# Java ignores the system trust store and JAVA_TOOL_OPTIONS already routes it through the sbx proxy,
# which re-signs TLS with its own CA: Maven and Testcontainers need that CA in the JDK's cacerts.
"$(mise where java)/bin/keytool" -importcert -noprompt -cacerts -storepass changeit \
  -alias sbx-proxy -file "$proxy_ca"

# Every bash in the sandbox (agent, Claude's Bash tool, `sbx exec`) sources this file via BASH_ENV.
cat >> /etc/sandbox-persistent.sh <<EOF
export MISE_DATA_DIR=/opt/mise
export MISE_TRUSTED_CONFIG_PATHS="${WORKSPACE_DIR}"
export PATH="/opt/mise/shims:\$PATH"
EOF
