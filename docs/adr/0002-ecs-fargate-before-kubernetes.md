# ADR 0002: Run containers on Amazon ECS with Fargate before considering Kubernetes

- Status: Accepted
- Date: 2026-09-15
- Review date: August 2027
- Deciders: CTO, founding engineer

## Context

Rotawell is one Django monolith with four workload types: web/API, Celery workers, a scheduler
and a nightly forecasting job. Twelve people work in engineering and data, and nobody works on
the platform full time. The founding engineer is the only person who can operate production
today, and the strategy's first aim is to remove that single point of knowledge.

## Decision

Run the containerised workloads on Amazon ECS with AWS Fargate, defined in Terraform
(`infra/modules/ecs-service`). The web/API service uses CodeDeploy blue-green deployments
with alarm-based automatic rollback. Workers use ECS rolling updates with the deployment
circuit breaker.

## Alternatives rejected

- **Amazon EKS (Kubernetes).** The control-plane fee is small; the operating cost is not.
  Kubernetes minor versions get roughly 14 months of patch support, so upgrades never stop.
  Ingress, networking, IAM integration, add-ons and hardening need at least two engineers
  fluent in Kubernetes, which Rotawell does not have. Adopting it now would create a new
  key-person risk while removing the old one.
- **EC2 Auto Scaling groups with AMIs.** No container scheduling, slower deploys, and hosts
  still to patch.
- **Docker Compose on virtual machines.** No self-healing across hosts.
- **A Heroku-style PaaS.** The simplest to run, but it integrates less well with the existing
  VPC and RDS database, raises EU data-residency questions in enterprise security reviews, and
  costs more at scale.

## Consequences

- Fargate costs more per vCPU-hour than self-managed EC2 and allows less low-level tuning. This
  is accepted because engineering time is the scarcer resource.
- Workloads are standard OCI images, so moving to Kubernetes later stays cheap.

## Revisit if any of these becomes true

- More than 15 independently deployed services.
- A platform team of three or more people exists.
- Enterprise customers require on-premises or multi-cloud deployment.
- Kubernetes-specific needs appear (for example, large-scale GPU scheduling or a service mesh).
- The steady-state Fargate premium exceeds 25% of compute spend.
