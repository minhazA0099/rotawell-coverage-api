## What and why

<!-- Link the ticket. One deployable change per PR; aim for fewer than 400 changed lines. -->

## How it was tested

- [ ] Tests added or updated for the change
- [ ] CI green: lint, tests and coverage gate, image build, smoke test and scan, IaC checks

## Risk and rollback

- [ ] Any database migration is expand-only (no table rewrite or long-held lock)
- [ ] Unfinished behaviour is behind a feature flag with an owner and an expiry date
- Rollback plan (normally: redeploy the previous release digest):
