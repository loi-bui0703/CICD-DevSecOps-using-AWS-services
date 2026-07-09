## Summary
<!-- What does this PR change? Keep it short. -->

## Team ownership
<!-- Check the box for your team -->
- [ ] **Team 1 — Infra/CI** (changes in `infrastructure/`, `ci/Jenkinsfile`, `docker-compose.infra.yml`)
- [ ] **Team 2 — Security** (changes in `security/`, `ci/stages/`, `docker-compose.security.yml`)
- [ ] **Team 3 — App/CD/Obs** (changes in `app/`, `kubernetes/`, `cd/`, `monitoring/`)
- [ ] **Shared contracts** (changes in `shared/contracts/` — requires ALL teams to approve)

## Checklist
- [ ] I have only modified files owned by my team (see CODEOWNERS)
- [ ] GitHub Actions CI passes for my team's workflow
- [ ] If I changed `shared/contracts/`, I have notified all 3 teams in Slack/Discord
- [ ] No secrets or credentials added to any file
- [ ] `.env` is still in `.gitignore` and not committed

## How to test locally
```bash
# e.g.
make up-security   # Team 2 testing their changes
make status        # verify services healthy
```

## Related issue / ticket
Closes #
