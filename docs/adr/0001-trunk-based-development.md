# ADR 0001: Trunk-based development with short-lived branches

- Status: Accepted
- Date: 2026-09-15
- Deciders: CTO, founding engineer, squad leads

## Context

Rotawell runs one multi-tenant production version, and customers never choose when to upgrade.
The current half-GitFlow model (`develop`, `release/*`, `hotfix/*`) makes merged work wait a mean
of three days for the Thursday release train. Twice in 2026 a hotfix merged to `main` was never
merged back to `develop`, and the bug returned in the next release. Engineering will grow from 12
to 25 people, and enterprise customers need evidence that every production change was reviewed
(SOC 2 change management, CC8.1).

## Decision

- Work on branches off `main` (`feature/`, `fix/`, `infra/`, `ci/`, `build/`, `docs/`) that live
  at most two working days. Every merge to `main` must be deployable.
- Merge through pull requests using merge commits, so `git log --first-parent main` lists one
  reviewed, deployable change per entry.
- Protect `main` with a ruleset: pull request required; one approval plus code-owner review
  (`.github/CODEOWNERS` routes infrastructure, migrations and pipeline files to platform owners,
  so those changes need a squad reviewer and a platform approval); required status checks; stale
  approvals dismissed; no force-push; no bypass except an audited break-glass role.
- Ship unfinished behaviour dark behind feature flags that have an owner and a 30-day expiry.
- Mark each production promotion with an annotated SemVer tag on the already-built image digest
  (see ADR 0003).

## Alternatives rejected

- **GitFlow / the current model.** It creates the release-train queue and the back-merge
  failures, and it exists for products that maintain several released versions at once.
  Rotawell has one.
- **Committing straight to trunk without pull requests.** It removes review just as many new
  engineers join, and loses the approval evidence auditors ask for.
- **Per-customer release branches.** Unnecessary with one production version. The public API
  is protected by `/api/v1` URL versioning and six months' deprecation notice instead.

## Consequences

- Needs fast CI (median under 12 minutes) and flag discipline; flags become debt if expiry is
  not enforced in CI.
- Merge commits make a busier history graph than squash merging.
- Two individually green pull requests can still break `main` together. A merge queue is added
  when the team passes 15 engineers; until then a red `main` is reverted within 15 minutes.

## Revisit if

A customer contract requires a separately upgraded version (for example, on-premises).
