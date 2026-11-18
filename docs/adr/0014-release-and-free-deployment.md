# ADR-0014 — Releases, images, dist package and zero-cost deployment paths

**Status:** Accepted · **Date:** 2026-11-18

## Context
The owner wants easy adoption, maintained Docker images, documented self-builds, a release "dist" package to start an instance locally, and **everything free of charge** for himself. GitHub gives public repos free Actions minutes, GHCR, Pages and security features. Free always-on compute is scarce and changes without notice, so no deployment path may depend on a single provider's free tier.

## Decision

### Releases
- Conventional Commits enforced in CI (commitlint on PR commits; PR title lint).
- **release-please** maintains `CHANGELOG.md`, the version and a release PR; merging it tags `vX.Y.Z` and creates the GitHub Release (notes = changelog section + upgrade notes + image digests).

### Docker images (published and maintained)
- Images: `ghcr.io/<owner>/varco-backend`, `varco-edge` (SPA + Caddy), `varco-keycloak` (Keycloak + login theme, `kc.sh build` done). Multi-arch `linux/amd64` + `linux/arm64`, non-root, OCI labels (source, version, licence `Apache-2.0`).
- Tags: `X.Y.Z`, `X.Y`, `X`, `latest` (latest release), `edge` (every merge to `main`), `sha-<short>`.
- **Supply chain:** build provenance + SBOM attestations (`actions/attest-build-provenance`, free for public repos); `gh attestation verify` documented.
- **Maintenance:** a weekly scheduled workflow scans the latest release's images with Trivy; if fixable HIGH/CRITICAL findings exist it rebuilds the same app version on refreshed base images and re-pushes `X.Y.Z`/`X.Y`/`X`/`latest`, appending the new digests to the release notes (the dist package's digest-pinned compose is updated by publishing a patch release instead); Dependabot updates base images; scheduled Trivy scan of published images reports to code scanning. Support policy: latest minor gets fixes.

### Self-build
- `compose.yaml` references images by `image: ghcr.io/<owner>/varco-*:${VARCO_VERSION:-dev}` only; **`compose.build.yaml`** overlay adds `build:` contexts. The repo `Makefile` always uses both → `make up` builds from source; the dist package uses only `compose.yaml` → pulls.
- `docker-bake.hcl` defines `backend`, `edge`, `keycloak` targets (+ group `all`), args for version and registry. Commands: `make images` (local arch, `docker buildx bake --load`), `make images-multiarch REGISTRY=…` (`--push`, both arches), or plain `docker compose -f compose.yaml -f compose.build.yaml build`. Reproducibility: pinned base digests, `SOURCE_DATE_EPOCH`.
- Docs page *Build from source* with the three commands and how to point the dist package at a private registry (`VARCO_REGISTRY`).

### Dist package (release asset `varco-X.Y.Z.tar.gz`)
```
varco-X.Y.Z/
├── varco                  # POSIX shell CLI (shellcheck-clean)
├── compose.yaml           # image-based, pinned to X.Y.Z by digest
├── compose.prod.yaml  compose.demo.yaml  compose.tunnel.yaml
├── .env.example           # annotated (same file the docs are generated from)
├── branding/              # default assets to customise
├── keycloak/              # realm config + LDAP presets (openldap, ad)
├── ldap-demo/             # seed LDIF for demo mode (public test data)
├── VERSION  CHECKSUMS  LICENSE  NOTICE  README.md
```
CLI commands: `./varco init --mode demo|local|prod` (writes `.env` with generated secrets; *demo* = localhost + 2 test LDAPs + demo seed, ready in one command; *local* = localhost + your LDAP; *prod* = domain + ACME TLS, preflight checks), `up`, `down`, `status`, `logs [svc]`, `backup`, `restore <file>`, `upgrade <version>` (downloads the new dist, verifies checksum + image attestations, backs up, migrates), `verify` (attestations). Never pipes remote scripts; nothing outside its folder is modified.

### Deployment paths (all free), documented on the site with a smoke check each
1. **Dist package, demo mode** — `tar xzf varco-X.Y.Z.tar.gz && cd varco-X.Y.Z && ./varco init --mode demo && ./varco up` → `https://localhost:8443`.
2. **From source** — `git clone … && cp .env.example .env && make up`.
3. **GitHub Codespaces "try it"** — `.devcontainer/` starts the demo stack and computes `VARCO_PUBLIC_URL` from the forwarded-port domain. Personal accounts get a free monthly quota (120 core-hours ≈ 60 h on 2 cores); the devcontainer targets 4 cores/16 GB and documents that this halves the hours.
4. **Single VM, production** — dist package `--mode prod` on any VPS; documented free option: **Oracle Cloud Always Free Ampere A1** (2 OCPU / 12 GB since mid-2026 — enough for Varco; arm64 images; capacity and idle-reclaim caveats).
5. **Home server / spare machine + Cloudflare Tunnel** (free plan) — no public IP or open ports; `compose.tunnel.yaml` adds `cloudflared`.
6. **Public demo** (optional) — path 4 or 5 with `compose.demo.yaml` and a nightly reset job; banner "Demo — dati di prova".

Not in v1: Helm/Kubernetes (community contribution opportunity), PaaS free tiers (too small for Keycloak + Postgres or sleep on idle).

## Consequences
+ Zero cost for the owner; three adoption entry points (dist, source, Codespaces).
+ Signed, attested, multi-arch, regularly rebuilt images = credible supply chain.
− Dist CLI is extra code to test (CI runs `init --mode demo` + `up` + smoke + `backup/restore` + `upgrade` from previous release).
− Free tiers change (Oracle halved A1 in 2026): docs state "verified on <date>".
