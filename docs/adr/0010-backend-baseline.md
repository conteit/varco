# ADR-0010 — Backend baseline: Java 25, Spring Boot 4, Spring Modulith, PostgreSQL

**Status:** Accepted · **Date:** 2026-11-18

## Context
Owner background is Java/Spring. Spring Boot 3.5's open-source support window has ended by late 2026; Boot 4.x is current. Java 25 is the current LTS.

## Decision
- Java 25 (Temurin), Spring Boot 4.x latest GA (verify on start.spring.io at scaffold time and pin in `pom.xml`), Maven wrapper.
- Spring Modulith for module boundaries and transactional domain events (JPA event publication registry).
- PostgreSQL 17+ (latest stable official image), Flyway, Testcontainers for integration tests.
- Virtual threads enabled; `Clock` injected; ShedLock for scheduled jobs.
- Formatting: Spotless (palantir-java-format). Coverage: JaCoCo ≥ 80 % lines for domain/service packages.
- **Fallback rule:** if a required library is incompatible with Boot 4 (e.g. contract validator), prefer replacing the library over downgrading Boot; document in PR.

## Consequences
+ Long support runway; modern APIs; boundaries enforced by tests.
− Agents' training data skews to Boot 3 idioms: AGENTS.md lists Boot 4 pitfalls (Jackson 3 packages, Security 7 lambda DSL only, `jakarta.*`).
