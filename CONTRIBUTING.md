# Contributing to Gateway Ops

Thank you for your interest in contributing! This project follows a **franchise-inspired naming convention** pattern to make the infrastructure more navigable and memorable. If you're extending this project, please respect the naming conventions below.

## Naming Convention: Stargate Universe

All new pipeline stages, scripts, and configuration files should follow the Stargate franchise naming pattern. There's an important distinction between **ships** (workflows that move things) and **hardware** (manifests that define destinations).

### Ships vs Hardware Rule

| Type | Location | Naming Pattern | Examples |
|------|----------|---------------|----------|
| **Ships/Workflows** | `.github/workflows/` | `[ship-name]-[action].yml` | zpm-build.yml, prometheus-launch.yml, x301-preview.yml |
| **Hardware/Manifests** | `k8s/` | `[component-type]-[object].yaml` | gate-deployment.yaml, gate-service.yaml, dhd-config.yaml |
| **Operations/Scripts** | `scripts/` | `[gate-element]-[operation].sh` | iris-validation.sh, sgc-smoke.sh |
| **Ancient Tech/Terraform** | `infra/` | `[ally/tech]-[purpose].tf` | nox-vault.tf, destiny-monitor.tf |

| Component Type | Naming Pattern | Examples |
|---------------|----------------|----------|
| **Build Jobs** | [atlantis-tech]-[verb] | zpm-build, zpm-compile, asgard-encrypt |
| **Validation Gates** | [sg1-security]-[check] | iris-validation, chevron-lock, naquadah-check |
| **Deploy Jobs** | [ship-name]-[action] | prometheus-launch, x301-preview, daedalus-transport |
| **Monitoring** | [ufo/sensor]-[task] | destiny-monitor, asgard-beacon, symark-scan |
| **Cleanup Scripts** | [collapse-action]-[target] | dump-wormhole, recall-gate, evacuate-city |

### Why This Convention Exists

At Cerner, we named our web layer components after Spider-Man characters and our data layer after Star Wars characters. The same principle applies here - shared cultural vocabulary reduces cognitive load and makes debugging more human.

## Adding a New Pipeline Stage

1. **Choose a franchise element** that matches the function:
   - Security/validation → SG-1 Iris/Chevron metaphors
   - Power/compute → Atlantis ZPM/Asgard metaphors
   - Navigation/routing → Dial Home Device/Gate metaphors
   - Long-term ops → Destiny ship metaphors

2. **Follow the naming convention** — use kebab-case: `filename.yml` or `filename.sh`

3. **Document in README.md** — Add a row to the Pipeline Stages table

4. **Add comments** to help future contributors understand the reference:
   ```yaml
   # prometheus-launch.yml
   # X-303 Prometheus = Earth's flagship flagship that launched into space
   ```

## Code Quality Standards

### Terraform

- Run `terraform fmt -recursive` before committing
- All outputs must be tagged with `sensitive = true` if containing secrets
- Module structure: `modules/[component]/main.tf`

### Kubernetes Manifests

- Include resource requests and limits on all containers
- Health probes (liveness/readiness) mandatory on all deployments
- ConfigMaps for environment-specific values, Secrets for sensitive data
- Use Kustomize base/overlay structure for environment separation

### GitHub Actions

- Each job should have explicit `needs:` dependencies
- Fail-fast behavior where appropriate (don't deploy if validation fails)
- Secrets referenced only via `${{ secrets.X }}`, never hardcoded

## Development Workflow

```bash
# Local validation before pushing
terraform fmt -check
terraform validate
kubectl apply --dry-run=client -f k8s/

# Commit convention
git commit -m "feat(gate): add new Fargate profile"
git commit -m "fix(iris): correct IAM trust policy"
git commit -m "chore(zpm): bump Python base image to 3.11"
```

## Review Guidelines

Reviewers should check:

- Naming convention followed (ships vs hardware distinction maintained)
- Secrets properly excluded from git (.gitignore respected)
- Cost implications documented
- Rollback path described in comments

## Franchise Glossary

For contributors unfamiliar with Stargate:

| Term | Origin | Meaning in This Project |
|------|--------|-------------------------|
| **Comtrya** | Altairan (SG-1: "Tin Man", "Double Jeopardy") | Welcome endpoint / alternate handshake (Harlan used it as IDC alternative) |
| **Iris** | SG-1 (Earth) | Mechanical shield that blocks unauthorized traffic |
| **Lantean Shield** | Atlantis (Ancient energy barrier) | Stricter validation - blocks subatomic particles, watch for backdoors |
| **ZPM** | Atlantis | Power source (energizes the build pipeline) |
| **DHD** | All series (crystal variant in Atlantis) | Dial Home Device (controls where traffic routes) |
| **Gate** | All series | The portal/connection (infrastructure provisioning) |
| **Chevron** | All series | Address lock (deployment gate checks) |
| **SGC** | SG-1 (Earth command) | Stargate Command (validation/checkpoint stage) |
| **Destiny** | SGU | Autonomous long-running mission (monitoring) |
| **Asgard** | SG-1 | Advanced civilization (security/encryption layer) |
| **Prometheus** | SG-1 (X-303) | Earth's flagship (primary deployment pipeline) |
| **Nox** | SG-1 | Concealment (secrets management) |

### Notable Canon References

| Term | Episode/Context | Why It Matters |
|------|-----------------|----------------|
| **Comtrya** | Harlan ("Tin Man", "Double Jeopardy") | Alternate IDC when standard code unavailable |
| **Lantean Shield** | McKay backdoor (SGA: "Rising", "The Return") | Stronger but has hidden vulnerabilities |
| **Chevron Lock** | Gate activation sequence | 7-chevron lock required for stable connection |
| **ZPM** | Atlantis power source | Near-limitless energy until depleted |

## License

By contributing, you agree that your contributions will be licensed under the MIT License.

Questions? Open an issue or ping the maintainers with @calionestevar in the repo discussion.