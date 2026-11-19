# ADR-0018 — Agent runtime: host Claude Code sessions in git worktrees (replaces sbx)

**Status:** Accepted · **Date:** 2026-11-18 · **Amends:** ADR-0016 § 1 (runtime, identities, secret handling), ADR-0015 ("sandbox kit")

## Context
ADR-0016 ran every agent in its own sbx microVM, with GitHub credentials injected by the sbx host proxy. On the owner's Mac, sbx stores its VM disks on the internal drive and cannot be relocated to the external drive where the project lives; a wave of sandboxes fills the system disk. The owner decided not to use sbx for this project.

## Decision
1. **Runtime.** Every agent (planner, implementer, reviewer) is a headless Claude Code session (`claude -p … --permission-mode dontAsk --permission-prompts none < /dev/null`, never `--dangerously-skip-permissions`) running on the host, launched by `scripts/agents/dispatch.sh`, with its working directory set to a dedicated **git worktree**: `../varco-worktrees/<TASK-ID>` (sibling of the main checkout, same volume). One task = one worktree = one branch. The reviewer gets a fresh, detached worktree at the PR head SHA, removed after the review. Worktrees are removed when the PR merges or the task is escalated.
2. **Guardrail, not boundary.** Agents run with Claude Code's built-in sandbox for shell commands (Seatbelt on macOS), passed per session with `--settings` so the repository cannot weaken it: `sandbox.enabled`, `failIfUnavailable` and `allowUnsandboxedCommands: false` (no unsandboxed retry); writes limited to the worktree, `$TMPDIR` and the Maven/pnpm/Playwright caches; reads denied for `~/Library/Keychains`, `~/.config/gh`, `~/.ssh`, `~/.aws`, `~/.docker/config.json`; network limited to the allowlist of ADR-0016 § 1 (package registries, GitHub, Docker registries, Anthropic API). Pushes go over HTTPS with the session's App token (per-worktree remote URL); the owner's SSH agent is unreachable because Unix sockets are blocked except the Docker socket.

   **The Docker socket is allowed** (Testcontainers, `make up`). The owner accepted that this makes the sandbox bypassable: an agent can start a container that mounts the host filesystem. The sandbox therefore prevents accidents and casual misuse; it is **not** a security boundary. The hard limits are on the GitHub side: per-role App tokens valid ≤ 1 h, no Administration permission, the `main` ruleset without bypass, owner-gated paths and the deterministic `review-gate` (ADR-0016 § 5). The exact sandbox configuration is part of A1 and verified by its rehearsal (a write outside the worktree, a request to a non-allowlisted host and a Keychain read must fail).
3. **Identities and credentials.** The machine user of ADR-0016 § 1 is replaced by a second GitHub App, so both agent identities are Apps installed on this repository only, with no Administration permission:

   | App (bot user) | Roles | Repository permissions | Private key (macOS Keychain, base64 PEM) |
   |---|---|---|---|
   | `varco-impl` (`varco-impl[bot]`, id 358864472) | planner, implementer, fixer | Contents RW, Pull requests RW, Issues RW, Workflows RW, Metadata R | service `varco-impl-key` |
   | `varco-reviewer` (`varco-reviewer[bot]`, id 358865721) | reviewer | Pull requests RW, Contents R, Issues R, Checks R, Metadata R | service `varco-reviewer-key` |

   **Rule: each role uses only its own App credential, always.** Implementer/planner/fixer sessions authenticate exclusively as `varco-impl`; reviewer sessions exclusively as `varco-reviewer`. No session ever receives both, the owner's `gh` login, or a private key. Only `scripts/agents/dispatch.sh` reads a private key: it mints a ≤ 1 h installation token for the role it is launching and writes it into that session's own `GH_CONFIG_DIR` (refreshed before expiry while the session runs). Commits carry the App's bot identity (`<id>+<app>[bot]@users.noreply.github.com`), DCO-signed by it. The `review-gate` only accepts approvals from `varco-reviewer[bot]`, so a review posted with any other identity cannot merge a PR.

   Agents run as the owner's macOS user (accepted by the owner). Because a session could in principle read its own token or query the Keychain, the PreToolUse hook and permission deny rules block commands that print or fetch credentials (`gh auth token`, `printenv`/`env` dumps, `echo $GH_TOKEN`, `security find-*-password`, reads of other sessions' `GH_CONFIG_DIR`); A1's rehearsal must show these attempts fail. gitleaks and push protection from ADR-0016 still apply. If a key may have leaked, revoke it on the App settings page and generate a new one.
4. **Shared host resources.** Maven, pnpm and Playwright caches are shared between worktrees (no per-agent copies). Host ports are shared, so at most **one** agent at a time runs the full stack (`make up` / `make e2e`); Testcontainers-based tests run concurrently. The dispatcher enforces both the concurrency cap and this stack lock.
5. Wherever earlier ADRs, AGENTS.md or task cards say "sandbox", read "the agent's worktree session".

## Consequences
+ No per-agent VM disks on the system drive; worktrees live next to the repo on the external volume. Faster start (no VM boot, shared caches).
− Weaker isolation than a microVM: agents run as the owner's OS user, the Claude Code sandbox is bypassable through the Docker socket, and a session can read its own App token. Mitigated by role-scoped short-lived/fine-grained tokens, the command-blocking hook, owner-gated paths and deterministic gates (ADR-0016 § 5).
− Full-stack E2E is serialised across agents.
