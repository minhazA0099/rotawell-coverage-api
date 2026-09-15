# rotawell-coverage-api

Supporting artefact repository for the report *Rotawell: A DevOps Delivery Strategy for a Growing
SaaS Platform* (Learnkey Institute, Award in Introduction to DevOps: Principles and Practices,
Scenario B). Rotawell Ltd is a fictional company.

The service is deliberately small. It compares scheduled shifts with hourly staffing demand and
produces a baseline demand forecast. The point of the repository is the delivery machinery
around it, which demonstrates the strategy's main decisions at small scale.

## What to look at

| Artefact | Where | What it demonstrates | Report |
|---|---|---|---|
| Container image | `Dockerfile` | Multi-stage build, digest-pinned base image, hash-locked dependencies, non-root user, read-only root filesystem, health check, commit stamped for traceability | 4.4 |
| CI pipeline | `.github/workflows/ci.yml` | Lint, tests with a 90% coverage gate, Dockerfile lint, image built once, smoke test that `/version` reports the commit, Trivy scan, image published only from `main`, Terraform validation and Checkov policy checks | 3.1, 3.3, 3.4 |
| Release | `.github/workflows/release.yml` | An annotated tag on `main` promotes the already-tested image by digest, with no rebuild | 2.3, 3.1 |
| Infrastructure as code | `infra/` | ECS on Fargate with CodeDeploy blue-green and alarm-based rollback; staging and production built from one module; images accepted only by digest; ECR with immutable tags | 4.2–4.5 |
| Drift detection | `.github/workflows/drift-detection.yml` | Nightly `terraform plan -detailed-exitcode` (skipped until an AWS OIDC role is configured) | 4.3 |
| Policy as code | `.checkov.yaml`, inline `#checkov:skip` reasons | Infrastructure policy failures fail CI; every exception is justified next to the code | 3.4, 5.5 |
| Review routing | `.github/CODEOWNERS`, `.github/pull_request_template.md` | Specialist review for pipeline, container and infrastructure changes | 2.2 |
| Dependency updates | `.github/dependabot.yml` | Python packages, base image, actions and Terraform providers update through pull requests and the same gates | 5.5 |
| Decisions | `docs/adr/` | Trunk-based development; ECS on Fargate before Kubernetes; build once, promote by digest | 2, 3, 4 |

## History

Work happened on short-lived branches merged through pull requests with merge commits, followed
by an annotated release tag:

```bash
git log --graph --oneline --all      # branches and merge commits
git log --first-parent --oneline main  # one entry per merged pull request
git show v1.0.0                        # annotated release tag
```

## Run locally

```bash
python3.12 -m venv .venv && . .venv/bin/activate
pip install --require-hashes -r requirements.txt
pip install --require-hashes -r requirements-dev.txt
ruff check . && pytest
flask --app "app:create_app()" run
```

Or as the container CI tests it:

```bash
docker build --build-arg GIT_SHA="$(git rev-parse HEAD)" -t coverage-api .
docker run --rm --read-only -p 8000:8000 -e APP_VERSION=local coverage-api
curl localhost:8000/version
```

## API

| Method | Path | Purpose |
|---|---|---|
| `GET` | `/healthz` | Liveness check |
| `GET` | `/version` | Release version, commit SHA and build time |
| `POST` | `/api/v1/coverage` | Hourly staffing gaps for a day |
| `POST` | `/api/v1/forecast` | Baseline weekday-seasonal forecast and its backtest error |

```bash
curl -X POST localhost:8000/api/v1/coverage -H 'content-type: application/json' \
  -d '{"demand":[{"hour":8,"required":3},{"hour":9,"required":4}],"shifts":[{"start":7,"end":15},{"start":8,"end":16}]}'
```

## How this differs from the target state in the report

- Images are published to GitHub Container Registry instead of Amazon ECR, because no AWS
  account is attached to this demonstration.
- Signing images with cosign and verifying signatures before deploy are Phase 1 work.
- Terraform is validated and policy-checked in CI but never applied. The drift-detection
  workflow is skipped until an AWS role is configured.
- Rotawell's `main` ruleset requires an approval plus code-owner review. A single-maintainer
  repository cannot approve its own pull requests, so here the pull requests show the checks
  and the merge commits rather than approvals.
