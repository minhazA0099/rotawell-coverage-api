# ADR 0003: Build once, promote by digest

- Status: Accepted
- Date: 2026-09-15
- Deciders: CTO, founding engineer

## Context

In May 2026 `deploy.sh` ran from a laptop that held an uncommitted hotfix. Production then ran
code that was not in Git, the next deploy silently removed the fix, and diagnosis took three
hours because nobody could tell which code was running. Rebuilding for each environment has a
subtler version of the same flaw: the artefact that was tested is not the artefact that ships.

## Decision

- CI builds one container image per commit (`.github/workflows/ci.yml`). It lints the
  Dockerfile, starts the container with a read-only root filesystem, fails unless `/healthz`
  answers and `/version` reports the commit being built, and scans the image with Trivy
  (fixable critical or high vulnerabilities fail the build).
- Only on `main` does CI push that exact image, tagged `sha-<commit>`.
- A release is an annotated tag on `main`. `.github/workflows/release.yml` adds the version tag
  to the existing image without rebuilding, checks the digest has not changed, and publishes a
  GitHub Release that records the commit and digest. It refuses lightweight tags, tags not on
  `main`, and commits for which CI has not published an image.
- Deployments reference images by digest only. The `image` variable in
  `infra/modules/ecs-service` rejects anything not pinned by digest.
- The image bakes in the commit SHA and the commit timestamp. The release version is
  deploy-time configuration (`APP_VERSION`), so promotion never needs a rebuild.
- Next step (Phase 1): sign images with cosign in CI and verify signatures before deployment;
  publish to Amazon ECR with immutable tags. This demonstration uses GitHub Container Registry
  because it has no AWS account.

## Alternatives rejected

- **Rebuild per environment.** Base images and dependencies can change between builds, so
  staging tests one artefact and production runs another.
- **Deploy with `git pull` on servers.** The current method, and the cause of the ghost-commit
  incident.
- **Mutable tags such as `latest`.** You cannot tell what is running or roll back to an exact
  artefact.

## Consequences

- The registry becomes a critical dependency; production pulls only from it.
- Security fixes mean a new build and promotion, never patching a running image. Dependabot
  proposes base-image digest updates as pull requests.
- A release cannot happen until CI on `main` has finished for that commit.
