# Gateway Ops: Cloud-Native Test Infrastructure Pipeline

> "Through the gate lies a world of infinite possibilities."

One push provisions AWS infrastructure and deploys to EKS Fargate. Safety gates (Iris), routing intelligence (DHD), and automated validation (SGC) ensure nothing travels through unchecked.

This project bridges Terraform + Kubernetes automation, designed to demonstrate cloud-native test infrastructure architecture for senior QA/Test Infrastructure roles. Part of the Nexus/Orion portfolio series inspired by science fiction and fantasy universes.

## Franchise Lineage

| Project | Universe | Purpose |
|---------|----------|---------|
| **OrionAI** / `orion-validate` | *Chuck* | AI evaluation framework |
| **NexusQA** | Multi-franchise | Test automation core (LOTR, Narnia, HP, Stargate, Star Trek, etc.) |
| **Nexus Trials** | *Mario* + *Pokémon* | Integration test harness |
| **SpareOom** | *Chronicles of Narnia* | Personal utilities |
| **Gateway Ops** | *Stargate* | **Cloud infrastructure pipeline** ← *this project* |

## Architecture Overview

```mermaid
flowchart TB
    subgraph GitHub["GitHub"]
        Repo[Repositories<br/>main + feature branches]
        Actions[GitHub Actions<br/>CI/CD Pipeline]
    end
    
    subgraph AWS["AWS (us-east-1)"]
        VPC[VPC<br/>Private Subnets + NAT]
        
        subgraph Compute["EKS Fargate"]
            Pod1[App Pod v1<br/>Flask + Health Checks]
            Pod2[App Pod v2<br/>High Availability]
        end
        
        subgraph Storage["State & Secrets"]
            S3[S3 Bucket<br/>Terraform State]
            SS[AWS SSM Parameter Store<br/>Secrets]
        end
        
        subgraph Observability["Monitoring"]
            CW[CloudWatch<br/>Logs & Billing Alerts]
        end
    end
    
    Repo -->|Push Event| Actions
    Actions -->|1. ZPM Build| S3
    Actions -->|2. Iris Validation| VPC
    Actions -->|3. Gate Deploy| Compute
    Actions -->|4. SGC Smoke| Compute
    Compute -->|Telemetry| CW
    Compute -->|Route via| Pod1
    Compute -->|Route via| Pod2
