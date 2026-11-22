# SPDX-License-Identifier: Apache-2.0
# Toolchain mixin for agent sandboxes (ADR-0019 § 5): the exact versions of mise.toml, installed once
# per kit build instead of once per sandbox. Built by `make sbx-kit`, which places mise.toml beside this file.
FROM debian:trixie-slim@sha256:a72b4433de1cf7d6bae0c4cee74d0547f58601a643b3375f070c51600d63b6b2 AS build
ARG TARGETARCH
ARG MISE_VERSION=v2026.11.12
ARG MISE_SHA256_ARM64=52f4a75495bde5571d5d0a45b4d9b5227c2c099b92f9be85328569e67b12c553
ARG MISE_SHA256_X64=9c12c24f5eac6b6357e5265e2629166cc3005459037f5d747680a99e375ff2ab
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# hadolint ignore=DL3008
RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl xz-utils libatomic1 \
    && rm -rf /var/lib/apt/lists/*

RUN case "$TARGETARCH" in \
      arm64) platform=arm64 sha="$MISE_SHA256_ARM64" ;; \
      amd64) platform=x64 sha="$MISE_SHA256_X64" ;; \
      *) echo "unsupported TARGETARCH: $TARGETARCH" >&2; exit 1 ;; \
    esac \
    && curl -fsSLo /usr/local/bin/mise \
        "https://github.com/jdx/mise/releases/download/${MISE_VERSION}/mise-${MISE_VERSION}-linux-${platform}" \
    && echo "${sha}  /usr/local/bin/mise" | sha256sum -c - \
    && chmod 0755 /usr/local/bin/mise

# System-level config: every directory in the sandbox resolves the same versions as the project.
COPY mise.toml /etc/mise/config.toml
ENV MISE_DATA_DIR=/opt/mise
RUN mise install && mise reshim && mise exec -- java -version

# Node 26's Linux binaries link libatomic, which the claude kit's image lacks; ship trixie's copy.
RUN mkdir /out && cp -a --parents /usr/lib/*-linux-gnu/libatomic.so.1* /out/

FROM scratch
COPY --from=build /usr/local/bin/mise /usr/local/bin/mise
COPY --from=build /etc/mise /etc/mise
COPY --from=build /out/ /
COPY --from=build --chown=1000:1000 /opt/mise /opt/mise
COPY --chmod=0755 install.sh /usr/local/share/varco/install.sh
