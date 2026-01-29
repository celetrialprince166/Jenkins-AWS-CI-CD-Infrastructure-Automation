# Jenkins AWS Infrastructure - Architecture Guide

## Overview

This project creates a production-ready Jenkins CI/CD infrastructure on AWS with:
- **Controller Nodes**: Manage jobs, serve UI, store configuration (HA with Auto Scaling)
- **Agent Nodes**: Execute builds (on-demand EC2 instances via EC2 plugin)
- **Shared Storage**: EFS for persistent Jenkins home directory
- **Load Balancer**: ALB for traffic distribution and SSL termination

---

## Architecture Diagram

```
                              ┌─────────────────┐
                              │    INTERNET     │
                              └────────┬────────┘
                                       │
                                       ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│                              VPC (10.0.0.0/16)                               │
│                                                                              │
│  ┌────────────────────────────────────────────────────────────────────────┐ │
│  │                    PUBLIC SUBNETS (Multi-AZ)                           │ │
│  │                                                                        │ │
│  │    ┌────────────────────────────────────────────────────────────┐     │ │
│  │    │              Application Load Balancer                      │     │ │
│  │    │           (jenkins.yourcompany.com:443)                     │     │ │
│  │    │                                                             │     │ │
│  │    │  • SSL/TLS Termination                                      │     │ │
│  │    │  • Health Checks (/login)                                   │     │ │
│  │    │  • Sticky Sessions (cookie-based)                           │     │ │
│  │    └──────────────────────────┬─────────────────────────────────┘     │ │
│  │                               │                                        │ │
│  └───────────────────────────────┼────────────────────────────────────────┘ │
│                                  │                                          │
│  ┌───────────────────────────────┼────────────────────────────────────────┐ │
│  │                    PRIVATE SUBNETS (Multi-AZ)                          │ │
│  │                               │                                        │ │
│  │    ┌──────────────────────────▼─────────────────────────────────┐     │ │
│  │    │           CONTROLLER AUTO SCALING GROUP                     │     │ │
│  │    │                                                             │     │ │
│  │    │   ┌─────────────────┐    ┌─────────────────┐               │     │ │
│  │    │   │   Controller 1  │    │   Controller 2  │               │     │ │
│  │    │   │   (Primary)     │    │   (Standby)     │               │     │ │
│  │    │   │                 │    │                 │               │     │ │
│  │    │   │  • Jenkins UI   │    │  • Jenkins UI   │               │     │ │
│  │    │   │  • Job Mgmt     │    │  • Job Mgmt     │               │     │ │
│  │    │   │  • Scheduling   │    │  • Scheduling   │               │     │ │
│  │    │   └────────┬────────┘    └────────┬────────┘               │     │ │
│  │    │            │                      │                        │     │ │
│  │    │   Min: 1   │   Desired: 2        │   Max: 2               │     │ │
│  │    └────────────┼──────────────────────┼────────────────────────┘     │ │
│  │                 │                      │                              │ │
│  │                 └──────────┬───────────┘                              │ │
│  │                            │                                          │ │
│  │              ┌─────────────▼─────────────┐                            │ │
│  │              │           EFS             │                            │ │
│  │              │    (Shared Storage)       │                            │ │
│  │              │                           │                            │ │
│  │              │  /var/lib/jenkins         │                            │ │
│  │              │  • Jobs & Pipelines       │                            │ │
│  │              │  • Plugins                │                            │ │
│  │              │  • Credentials            │                            │ │
│  │              │  • Build History          │                            │ │
│  │              └───────────────────────────┘                            │ │
│  │                                                                        │ │
│  │    ┌─────────────────────────────────────────────────────────────┐    │ │
│  │    │              AGENT NODES (On-Demand via EC2 Plugin)         │    │ │
│  │    │                                                             │    │ │
│  │    │   ┌───────────┐  ┌───────────┐  ┌───────────┐              │    │ │
│  │    │   │  Agent 1  │  │  Agent 2  │  │  Agent N  │              │    │ │
│  │    │   │           │  │           │  │           │              │    │ │
│  │    │   │ • Java    │  │ • Java    │  │ • Java    │              │    │ │
│  │    │   │ • Docker  │  │ • Docker  │  │ • Docker  │              │    │ │
│  │    │   │ • Git     │  │ • Git     │  │ • Git     │              │    │ │
│  │    │   │ • Maven   │  │ • Maven   │  │ • Maven   │              │    │ │
│  │    │   └───────────┘  └───────────┘  └───────────┘              │    │ │
│  │    │                                                             │    │ │
│  │    │   Launched on-demand • Terminated when idle                │    │ │
│  │    └─────────────────────────────────────────────────────────────┘    │ │
│  │                                                                        │ │
│  └────────────────────────────────────────────────────────────────────────┘ │
│                                                                              │
└──────────────────────────────────────────────────────────────────────────────┘
```

---

## Component Responsibilities

### Controller Node
| Responsibility | Description |
|----------------|-------------|
| Job Management | Stores and manages job configurations |
| Web UI | Serves the Jenkins dashboard |
| Scheduling | Decides which agent runs which job |
| Plugin Management | Installs and manages plugins |
| Credential Storage | Securely stores secrets |
| Build History | Maintains logs and artifacts |

**Does NOT**: Run builds (delegates to agents)

### Agent Node
| Responsibility | Description |
|----------------|-------------|
| Build Execution | Runs the actual build/test/deploy steps |
| Tool Execution | Runs Maven, Docker, npm, etc. |
| Workspace Management | Manages job workspaces |

**Does NOT**: Store permanent data, serve UI, manage jobs

---

## Data Flow

```
1. Developer pushes code to GitHub
                │
                ▼
2. GitHub webhook triggers Jenkins
                │
                ▼
3. ALB routes request to Controller
                │
                ▼
4. Controller reads job config from EFS
                │
                ▼
5. Controller finds/launches Agent via EC2 Plugin
                │
                ▼
6. Agent clones repo, runs build
                │
                ▼
7. Agent reports results to Controller
                │
                ▼
8. Controller stores results on EFS
                │
                ▼
9. Agent terminates (if idle timeout reached)
```

---

## Why This Architecture?

### Why Controller-Agent Separation?

| Problem | Solution |
|---------|----------|
| Controller overloaded with builds | Agents handle all build execution |
| Different build environments needed | Different agent AMIs for different tools |
| Cost optimization | Agents spin up only when needed |
| Security isolation | Builds run in isolated agents |

### Why EFS for Storage?

| Problem | Solution |
|---------|----------|
| Data loss on controller failure | EFS persists independently |
| Multiple controllers need same data | EFS supports concurrent mounts |
| Need to scale controllers | All controllers share same EFS |

### Why EC2 Plugin for Agents?

| Problem | Solution |
|---------|----------|
| Idle agents waste money | EC2 plugin terminates idle agents |
| Build queue grows during peaks | EC2 plugin launches more agents |
| Manual agent management | Fully automated provisioning |

---

## Security Model

```
┌─────────────────────────────────────────────────────────────────┐
│                    SECURITY LAYERS                              │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  NETWORK LAYER                                                  │
│  ├─ Controllers in private subnets (no public IP)              │
│  ├─ Agents in private subnets (no public IP)                   │
│  ├─ Only ALB exposed to internet                               │
│  └─ NAT Gateway for outbound traffic                           │
│                                                                 │
│  SECURITY GROUPS                                                │
│  ├─ ALB SG: 80/443 from internet                               │
│  ├─ Controller SG: 8080 from ALB only                          │
│  ├─ Controller SG: 50000 from Agent SG (JNLP)                  │
│  ├─ Agent SG: 22 from Controller SG (SSH)                      │
│  └─ EFS SG: 2049 from Controller SG only                       │
│                                                                 │
│  IAM ROLES                                                      │
│  ├─ Controller Role: EC2 (launch agents), EFS, SSM             │
│  └─ Agent Role: ECR (pull images), S3 (artifacts)              │
│                                                                 │
│  DATA ENCRYPTION                                                │
│  ├─ EFS: Encrypted at rest                                     │
│  ├─ ALB: TLS termination                                       │
│  └─ Jenkins: Credentials encrypted                             │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Failure Scenarios

### Controller Failure
1. ALB health check fails (30s)
2. ALB stops routing to failed controller
3. ASG detects unhealthy instance
4. ASG launches replacement from AMI
5. New controller mounts EFS
6. New controller has all data immediately
7. **Recovery time: ~5 minutes**

### Agent Failure
1. Build fails on agent
2. Controller marks agent as offline
3. Controller reschedules build on another agent
4. EC2 plugin terminates failed agent
5. **Recovery time: Immediate (reschedule)**

### EFS Failure
1. AWS manages EFS redundancy across AZs
2. If mount point fails, controller retries
3. **This is rare - EFS has 99.99% availability**

---

## Interview Talking Points

1. **"Why not run builds on the controller?"**
   > "Separation of concerns. The controller manages state and UI - it should be stable. Builds are unpredictable and resource-intensive. By running builds on agents, a runaway build can't crash the controller."

2. **"How do agents connect to the controller?"**
   > "We use the EC2 plugin with SSH. The controller launches EC2 instances from our agent AMI, connects via SSH, and runs the Jenkins agent. When builds finish and the agent is idle, it's terminated to save costs."

3. **"What happens if both controllers fail?"**
   > "The ASG maintains desired capacity. If both fail, it launches replacements. Since all state is on EFS, new controllers have immediate access to all jobs and history. Worst case recovery is about 5 minutes."

4. **"Why EFS instead of EBS?"**
   > "EBS can only attach to one instance. With multiple controllers for HA, they all need access to the same Jenkins home directory. EFS supports concurrent mounts from multiple instances."
