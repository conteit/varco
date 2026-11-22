# SPDX-License-Identifier: Apache-2.0
# Single entry point (AGENTS.md § 2). Targets for parts that do not exist yet print "not yet available".
PNPM ?= pnpm
MVN_ARGS ?=
MVNW := ./mvnw -B $(MVN_ARGS)

.DEFAULT_GOAL := help
.PHONY: help bootstrap up down reset check test-backend test-frontend test-brand test-theme api-types \
        e2e trace storybook storybook-test screenshots docs-gen docs-dev docs-build images images-multiarch \
        lint-scripts sbx-kit

help:
	@echo "Targets are listed in AGENTS.md § 2."

bootstrap:
	mise install
	$(PNPM) install --frozen-lockfile
	cd backend && $(MVNW) dependency:go-offline -q
	git config core.hooksPath .githooks
	@echo "api-types: not yet available (T02)"

check: lint-scripts
	cd backend && $(MVNW) verify
	$(PNPM) -r run lint
	$(PNPM) exec eslint eslint.config.js commitlint.config.mjs
	$(PNPM) run format:check
	$(PNPM) -r run typecheck
	$(PNPM) -r run test
	gitleaks git --no-banner --redact

lint-scripts:
	shellcheck scripts/*.sh .githooks/* infra/sbx/*/install.sh
	scripts/trace.test.sh

test-backend:
	cd backend && $(MVNW) verify

test-frontend:
	$(PNPM) --filter @varco/frontend run test

test-brand:
	$(PNPM) --filter @varco/brand run test

test-theme up down reset api-types e2e storybook storybook-test screenshots docs-gen docs-dev docs-build images images-multiarch:
	@echo "$@: not yet available"

trace:
	scripts/trace.sh $(if $(STRICT),--strict)
	@head -12 build/trace.md

# sbx builds a local kit only from its own directory, so the kit gets its own copy of mise.toml (ADR-0019 § 5).
sbx-kit:
	rm -rf build/sbx-kit && mkdir -p build/sbx-kit
	cp -R infra/sbx/varco-toolchain build/sbx-kit/
	cp mise.toml build/sbx-kit/varco-toolchain/
