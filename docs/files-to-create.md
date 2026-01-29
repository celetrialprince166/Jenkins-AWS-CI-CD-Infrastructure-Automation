# Files to Create - Jenkins AWS Infrastructure

This document lists ALL files that will be created for this project, organized by component.

## Project Structure Overview

```
jenkins_config/
│
├── .cursor/rules/                         # ✅ CREATED - AI coding guidelines
├── .github/workflows/                     # 🔲 TO CREATE - CI/CD pipeline
├── packer/                                # 🔲 TO CREATE - AMI building
├── ansible/                               # 🔲 TO CREATE - Configuration
├── terraform/                             # 🔲 TO CREATE - Infrastructure
├── scripts/                               # 🔲 TO CREATE - Helper scripts
└── docs/                                  # ✅ CREATED - Documentation
```

---

## 1. Cursor Rules (AI Guidelines) ✅ CREATED

```
.cursor/rules/
├── 00-project-standards.mdc      ✅ Core standards (always applies)
├── terraform-standards.mdc       ✅ Terraform patterns (*.tf files)
├── ansible-standards.mdc         ✅ Ansible patterns (*.yml files)
├── packer-standards.mdc          ✅ Packer patterns (*.pkr.hcl files)
├── github-actions-standards.mdc  ✅ CI/CD patterns (workflows/*.yml)
├── jenkins-architecture.mdc      ✅ Controller-agent patterns
├── aws-patterns.mdc              ✅ AWS infrastructure patterns
└── project-structure.mdc         ✅ File structure reference
```

---

## 2. GitHub Actions (CI/CD Pipeline) 🔲 TO CREATE

```
.github/
└── workflows/
    └── jenkins-infra.yml         # Complete CI/CD pipeline
                                  # - Validate Packer, Ansible, Terraform
                                  # - Build Controller AMI
                                  # - Build Agent AMI
                                  # - Terraform Plan
                                  # - Terraform Apply (with approval)
```

---

## 3. Packer (AMI Building) 🔲 TO CREATE

```
packer/
├── jenkins-controller.pkr.hcl    # Controller AMI template
│                                 # - Ubuntu 22.04 base
│                                 # - Calls Ansible for configuration
│                                 # - Tags for identification
│
├── jenkins-agent.pkr.hcl         # Agent AMI template
│                                 # - Ubuntu 22.04 base
│                                 # - Lighter than controller
│                                 # - Build tools only
│
└── variables.pkr.hcl             # Shared variables
                                  # - AWS region
                                  # - Instance types
                                  # - AMI naming
```

---

## 4. Ansible (Configuration Management) 🔲 TO CREATE

```
ansible/
├── ansible.cfg                   # Ansible configuration
│
├── playbooks/
│   ├── jenkins-controller.yml    # Controller playbook
│   │                             # - Includes: common, java, jenkins-controller, efs
│   │
│   └── jenkins-agent.yml         # Agent playbook
│                                 # - Includes: common, java, jenkins-agent
│
├── roles/
│   ├── common/                   # Base server setup
│   │   └── tasks/
│   │       └── main.yml          # - Update packages
│   │                             # - Install base utilities
│   │                             # - Configure timezone
│   │
│   ├── java/                     # Java installation
│   │   ├── tasks/
│   │   │   └── main.yml          # - Install OpenJDK 17
│   │   └── defaults/
│   │       └── main.yml          # - java_version: "17"
│   │
│   ├── jenkins-controller/       # Jenkins server installation
│   │   ├── tasks/
│   │   │   └── main.yml          # - Add Jenkins repo
│   │   │                         # - Install Jenkins
│   │   │                         # - Configure Jenkins
│   │   │                         # - Install plugins
│   │   ├── templates/
│   │   │   ├── jenkins.j2        # - Jenkins config template
│   │   │   └── plugins.txt.j2    # - Plugin list template
│   │   ├── handlers/
│   │   │   └── main.yml          # - Restart Jenkins handler
│   │   └── defaults/
│   │       └── main.yml          # - jenkins_port: 8080
│   │                             # - jenkins_home: /var/lib/jenkins
│   │
│   ├── jenkins-agent/            # Agent setup (no Jenkins server)
│   │   ├── tasks/
│   │   │   └── main.yml          # - Create jenkins user
│   │   │                         # - Install build tools
│   │   │                         # - Configure SSH
│   │   └── defaults/
│   │       └── main.yml          # - agent_tools: [git, docker, maven]
│   │
│   └── efs/                      # EFS mounting (controller only)
│       ├── tasks/
│       │   └── main.yml          # - Install NFS client
│       │                         # - Create mount point
│       │                         # - Configure fstab
│       └── defaults/
│           └── main.yml          # - efs_mount_point: /var/lib/jenkins
│
└── group_vars/
    └── all.yml                   # Global variables
                                  # - jenkins_version
                                  # - java_version
                                  # - common settings
```

---

## 5. Terraform (Infrastructure) 🔲 TO CREATE

```
terraform/
├── main.tf                       # Root module - calls child modules
├── variables.tf                  # Input variable declarations
├── outputs.tf                    # Output definitions (ALB DNS, etc.)
├── providers.tf                  # AWS provider configuration
├── versions.tf                   # Version constraints
├── locals.tf                     # Local values and computed variables
├── terraform.tfvars.example      # Example variable values
│
└── modules/
    ├── vpc/                      # VPC and networking
    │   ├── main.tf               # - VPC
    │   │                         # - Public subnets (2 AZs)
    │   │                         # - Private subnets (2 AZs)
    │   │                         # - Internet Gateway
    │   │                         # - NAT Gateway
    │   │                         # - Route tables
    │   ├── variables.tf
    │   └── outputs.tf
    │
    ├── security-groups/          # Security groups
    │   ├── main.tf               # - ALB security group
    │   │                         # - Controller security group
    │   │                         # - Agent security group
    │   │                         # - EFS security group
    │   ├── variables.tf
    │   └── outputs.tf
    │
    ├── efs/                      # Elastic File System
    │   ├── main.tf               # - EFS file system
    │   │                         # - Mount targets (per AZ)
    │   │                         # - Access points
    │   ├── variables.tf
    │   └── outputs.tf
    │
    ├── alb/                      # Application Load Balancer
    │   ├── main.tf               # - ALB
    │   │                         # - Target group
    │   │                         # - Listeners (HTTP/HTTPS)
    │   │                         # - Health checks
    │   ├── variables.tf
    │   └── outputs.tf
    │
    ├── iam/                      # IAM roles and policies
    │   ├── main.tf               # - Controller instance role
    │   │                         # - Agent instance role
    │   │                         # - Instance profiles
    │   ├── variables.tf
    │   └── outputs.tf
    │
    └── controller-asg/           # Controller Auto Scaling
        ├── main.tf               # - Launch template
        │                         # - Auto Scaling Group
        │                         # - User data script
        ├── variables.tf
        └── outputs.tf
```

---

## 6. Scripts (Helper Scripts) 🔲 TO CREATE

```
scripts/
├── mount-efs.sh                  # EFS mount script (user data)
│                                 # - Wait for EFS availability
│                                 # - Mount EFS to Jenkins home
│                                 # - Set permissions
│                                 # - Start Jenkins
│
├── validate-local.sh             # Local validation script
│                                 # - Run packer validate
│                                 # - Run ansible-lint
│                                 # - Run terraform validate
│
└── cleanup.sh                    # Cleanup script
                                  # - Destroy Terraform resources
                                  # - Deregister AMIs
                                  # - Delete snapshots
```

---

## 7. Documentation 🔲 TO CREATE

```
docs/
├── architecture.md               ✅ Architecture overview
├── setup-guide.md                # Step-by-step setup instructions
├── troubleshooting.md            # Common issues and solutions
├── runbook.md                    # Operational procedures
└── interview-prep.md             # Interview questions and answers
```

---

## 8. Root Files 🔲 TO CREATE

```
jenkins_config/
├── .gitignore                    # Git ignore patterns
│                                 # - *.tfstate
│                                 # - *.tfvars (secrets)
│                                 # - .terraform/
│
├── README.md                     # Project documentation
│                                 # - Overview
│                                 # - Architecture
│                                 # - Prerequisites
│                                 # - Quick start
│                                 # - Usage
│
└── LICENSE                       # MIT License
```

---

## Build Order

When we start coding, follow this order:

1. **Ansible roles** (configuration layer)
   - `common` → `java` → `jenkins-controller` → `jenkins-agent` → `efs`

2. **Packer templates** (image layer)
   - `variables.pkr.hcl` → `jenkins-controller.pkr.hcl` → `jenkins-agent.pkr.hcl`

3. **Terraform modules** (infrastructure layer)
   - `vpc` → `security-groups` → `efs` → `iam` → `alb` → `controller-asg`

4. **GitHub Actions** (automation layer)
   - `jenkins-infra.yml`

5. **Documentation**
   - `README.md` → remaining docs

---

## Ready to Start?

When you're ready, say:
- "Let's start with Ansible" - We'll build the configuration layer
- "Let's start with Packer" - We'll build the image layer
- "Let's start with Terraform" - We'll build the infrastructure layer

I'll explain each file line-by-line as we create it.
