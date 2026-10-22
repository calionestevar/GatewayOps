# INFRASTRUCTURE_MIGRATION.md

## From Local Kind to AWS EKS Fargate

This document describes how to migrate Gateway Ops from the zero-cost local
development environment (Kind + Docker Desktop) to a production-grade AWS EKS
cluster with Fargate compute. It is written as an executable plan: every step
includes the commands to run and the verification that proves it worked.

**Current posture:** validated, not deployed. The Terraform in `infra/` passes
`terraform fmt`, `terraform validate`, and checkov with zero unchecked
suppressions. The application and pipeline are fully exercised against Kind.
The migration is deferred by choice — to keep the project at $0/month — not by
missing work.

---

## Why This Document Exists

A portfolio project that only runs locally proves local execution. A migration
plan that specifies state backends, IAM boundaries, network topology, and
teardown procedures proves architectural understanding. The cost of deploying
(~$89/month) buys a screenshot; the plan itself demonstrates the reasoning.

---

## Validation Gate Matrix (Carried Across the Migration)

The layered validation strategy is environment-independent by design. Every
gate below survives the migration unchanged:

| Gate | Artifact inspected | Question answered | Environment-agnostic? |
|------|-------------------|-------------------|---------------------|
| Iris (`iris-validation.sh`) | Source: shell, Terraform, repo hygiene | Is the source valid, formatted, and secret-free? | Yes |
| ZPM unit tests | Python source | Does the logic hold (incl. /dial-out allowlist)? | Yes |
| Asgard — gitleaks | Repository history | Did a credential leak in? | Yes |
| Asgard — hadolint | Dockerfile | Does the build violate container practice? | Yes |
| Asgard — checkov | Terraform HCL | Does the IaC violate cloud hardening policy? | Yes (AWS-specific rules) |
| Asgard — trivy | Container image | Does the artifact carry known CVEs? | Yes |
| kubeconform | Rendered manifests | Do the manifests match the K8s schema? | Yes |
| Lantean Shield | Rendered manifests | Do the manifests meet pod hardening policy? | Yes |
| SGC Smoke | **Runtime behavior** | Does the deployed system actually work? | Yes (port-forward changes) |

Only the deployment mechanics change between Kind and EKS — the gates are
the same because they validate artifacts, not environments. See
LESSONS_LEARNED.md #21 for the incident that proved the gates are disjoint.

---

## Current State (Free Tier)

| Component | Implementation | Monthly Cost |
|-----------|---------------|--------------|
| Cluster | Kind on Docker Desktop | $0 |
| Registry | GHCR | $0 |
| CI/CD | GitHub Actions (free tier) | $0 |
| Terraform | Validated locally, unapplied | $0 |

## Target State (AWS)

| Component | Implementation | Est. Monthly Cost |
|-----------|---------------|-------------------|
| Cluster | EKS control plane | ~$73 |
| Compute | Fargate (pods) | usage-based, ~$5-15 |
| State | S3 + DynamoDB | ~$1 |
| Observability | CloudWatch Logs | ~$5-10 |
| Registry / CI | GHCR / Actions (unchanged) | $0 |
| **Total** | | **~$89-100** |

---

## Migration Steps

### Step 0: Prerequisites

```powershell
aws configure            # access key, secret, region
aws sts get-caller-identity   # verify credentials work