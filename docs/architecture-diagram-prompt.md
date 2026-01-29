# AI Image Generation Prompt - Jenkins AWS Architecture Diagram

## Quick Copy-Paste Prompts

### For ChatGPT/DALL-E (Copy This Exactly):

```
Create a professional AWS cloud architecture diagram in the style of official AWS documentation.

EXACT STYLE REQUIREMENTS:
- Light blue grid/graph paper background
- Clean, flat design with AWS orange (#FF9900) icons
- White/light gray containers with rounded corners
- Dark blue (#232F3E) header banners for route tables
- Professional technical diagram, NOT artistic or 3D

DIAGRAM STRUCTURE:

TITLE: "Jenkins CI/CD Infrastructure - Controller/Agent Architecture"

OUTER CONTAINER: "AWS Cloud Region" with AWS logo

INNER CONTAINER: "VPC 10.0.0.0/16" with orange border

TWO COLUMNS: "Availability Zone A" | "Availability Zone B"

ROW 1 - PUBLIC SUBNETS (light green #E8F5E9 background):
Left box "Public Subnet A (10.0.1.0/24)":
- NAT Gateway icon
- EC2 icon labeled "Jump Server (Bastion)"

Right box "Public Subnet B (10.0.2.0/24)":  
- ALB icon labeled "Application Load Balancer"
- Security group badge "SG: Web"

Green banner: "Public Route Table"
Show: SSH (22) arrow to Jump Server, HTTPS (443) arrow to ALB

ROW 2 - PRIVATE APP SUBNETS (light blue #E3F2FD background):
Left box "Private App Subnet A (10.0.3.0/24)":
- EC2 icon labeled "Jenkins Controller (Primary)"
- EC2/ASG icons labeled "Jenkins Agents"
- Security group badge "SG: App"

Right box "Private App Subnet B (10.0.4.0/24)":
- EC2 icon labeled "Jenkins Controller (Standby)"  
- EC2/ASG icons labeled "Jenkins Agents"
- Security group badge "SG: App"

Blue banner: "Private App Route Table"
Show: HTTP (8080) arrows from ALB to Controllers
Show: JNLP (50000) arrows from Agents to Controllers

ROW 3 - PRIVATE STORAGE SUBNETS (light purple #F3E5F5 background):
Left box "Private Storage Subnet A (10.0.5.0/24)":
- EFS icon labeled "EFS (Primary)"

Right box "Private Storage Subnet B (10.0.8.0/24)":
- EFS icon labeled "EFS Mount Target"

Purple banner: "Private Storage Route Table"
Show: NFS (2049) arrows from Controllers to EFS
Show: "Synchronous Replication" arrow between EFS icons

EXTERNAL ELEMENTS:
- "Admin User" stick figure on far left
- "Internet Users" cloud icon on far right
- "GitHub" icon at top with webhook arrow

RIGHT SIDE PANEL - "Route Tables Configuration":
White box listing:
- Public Route Table: Dest 10.0.0.0/16 → Local, Dest 0.0.0.0/0 → IGW
- Private App Route Table: Dest 10.0.0.0/16 → Local, Dest 0.0.0.0/0 → NAT Gateway
- Private Storage Route Table: Dest 10.0.0.0/16 → Local

Make it look exactly like official AWS architecture diagrams with clean lines, proper spacing, and professional labeling.
```

---

### For Midjourney (Copy This):

```
Professional AWS cloud architecture diagram, Jenkins CI/CD infrastructure, controller-agent model, light blue grid background, AWS official orange icons, VPC with two availability zones, public subnets with NAT gateway and load balancer in green, private subnets with Jenkins controllers and agents in blue, EFS storage layer in purple, route tables panel on right side, security group badges, connection arrows with port numbers (443, 8080, 50000, 2049, 22), clean technical diagram style, flat design, white labels, dark blue banners --ar 16:9 --v 6
```

---

### For Claude/Anthropic (Detailed Version):

```
Please create a detailed AWS architecture diagram description that I can use to build in draw.io or Lucidchart. The diagram should show a Jenkins CI/CD infrastructure with Controller/Agent (Master/Slave) architecture.

Structure it exactly like this:

1. CANVAS: Light blue grid background (like graph paper)

2. MAIN CONTAINERS (nested):
   - Outermost: "AWS Cloud Region" 
   - Inside: "VPC 10.0.0.0/16" with orange border

3. SPLIT INTO 2 AVAILABILITY ZONES (side by side)

4. THREE HORIZONTAL LAYERS:

   LAYER 1 - PUBLIC (Green background):
   - Subnet A (10.0.1.0/24): NAT Gateway + Bastion Host
   - Subnet B (10.0.2.0/24): Application Load Balancer
   - Banner: "Public Route Table"
   
   LAYER 2 - PRIVATE APP (Blue background):
   - Subnet A (10.0.3.0/24): Jenkins Controller (Primary) + Agent ASG
   - Subnet B (10.0.4.0/24): Jenkins Controller (Standby) + Agent ASG
   - Banner: "Private App Route Table"
   
   LAYER 3 - PRIVATE STORAGE (Purple background):
   - Subnet A (10.0.5.0/24): EFS Primary
   - Subnet B (10.0.8.0/24): EFS Mount Target
   - Banner: "Private Storage Route Table"

5. CONNECTIONS (with port labels):
   - Internet → ALB: HTTPS (443)
   - ALB → Controllers: HTTP (8080)
   - Agents → Controllers: JNLP (50000)
   - Controllers → EFS: NFS (2049)
   - Admin → Bastion: SSH (22)
   - Bastion → Controllers: SSH (22)

6. RIGHT PANEL: Route table configurations

7. EXTERNAL: Admin user (left), Internet users (right), GitHub (top)
```

---

## Original Detailed Prompt

Use this prompt with image generation tools like Midjourney, DALL-E, or specialized diagram tools like Lucidchart AI, Cloudcraft, or draw.io.

---

### Primary Prompt

```
Create a professional AWS cloud architecture diagram for a Jenkins CI/CD infrastructure with the following specifications:

STYLE:
- Clean, professional AWS architecture diagram style
- Light blue grid background (graph paper style)
- AWS official orange and dark blue color scheme
- Flat design with official AWS service icons
- Clear labeling with white backgrounds on labels
- Rounded rectangle containers for subnets and groups
- Color-coded sections: green for public subnets, blue for private subnets, purple for storage

LAYOUT (Left to Right, Top to Bottom):

TOP SECTION - External Access:
- "Internet Users" cloud icon on the far right with a cloud symbol
- "Admin User" stick figure icon on the far left
- "GitHub" logo in top center showing webhook connection

MAIN CONTAINER - "AWS Cloud Region (us-east-1)":
Large rounded rectangle containing everything below

VPC CONTAINER - "VPC 10.0.0.0/16":
Second container inside AWS Cloud with orange border

SPLIT INTO TWO AVAILABILITY ZONES:
- Left side: "Availability Zone A (us-east-1a)"
- Right side: "Availability Zone B (us-east-1b)"
- Separated by dotted vertical line

PUBLIC SUBNETS (Green background, top row):
- "Public Subnet A (10.0.1.0/24)" - Left side containing:
  - NAT Gateway icon (orange)
  - Bastion Host EC2 icon (orange) - labeled "Jump Server"
- "Public Subnet B (10.0.2.0/24)" - Right side containing:
  - Application Load Balancer icon (orange) - labeled "Jenkins ALB"
- Green banner across top: "Public Route Table"
- Show "HTTPS (443)" arrow from Internet to ALB
- Show "SSH (22)" arrow from Admin to Bastion

PRIVATE APP SUBNETS (Blue background, middle row):
- "Private Subnet A (10.0.10.0/24)" - Left side containing:
  - EC2 icon labeled "Jenkins Controller 1"
  - EC2 icon labeled "Jenkins Agent" (multiple, shown as ASG)
- "Private Subnet B (10.0.20.0/24)" - Right side containing:
  - EC2 icon labeled "Jenkins Controller 2"
  - EC2 icon labeled "Jenkins Agent" (multiple, shown as ASG)
- Blue banner: "Private App Route Table"
- Security Group badges: "SG: Controller", "SG: Agent"
- Show "HTTP (8080)" arrows from ALB to Controllers
- Show "JNLP (50000)" arrows from Agents to Controllers

PRIVATE STORAGE SUBNET (Purple background, bottom row):
- "Private Storage Subnet A (10.0.100.0/24)" - Left side containing:
  - EFS icon (orange file system icon)
- "Private Storage Subnet B (10.0.100.0/24)" - Right side containing:
  - EFS Mount Target icon
- Purple banner: "Private Storage Route Table"
- Show "NFS (2049)" arrows from Controllers to EFS
- Label: "EFS - Jenkins Home (/var/lib/jenkins)"
- Show synchronization arrow between EFS mount targets

RIGHT SIDE PANEL - "Route Tables Configuration":
White panel with:
- "Public Route Table"
  - Dest: 10.0.0.0/16 -> Local
  - Dest: 0.0.0.0/0 -> IGW
- "Private App Route Table"
  - Dest: 10.0.0.0/16 -> Local
  - Dest: 0.0.0.0/0 -> NAT Gateway
- "Private Storage Route Table"
  - Dest: 10.0.0.0/16 -> Local

CONNECTIONS AND ARROWS:
- Solid lines for data flow
- Dashed lines for management/SSH
- Arrow labels showing port numbers
- Bidirectional arrows where appropriate

ICONS TO USE:
- AWS VPC icon (orange)
- AWS EC2 icon (orange compute)
- AWS EFS icon (orange file)
- AWS ALB icon (orange load balancer)
- AWS NAT Gateway icon (orange)
- AWS Internet Gateway icon (orange globe)
- Security Group badge (shield icon)
- Auto Scaling Group indicator (circular arrows around EC2s)

LABELS AND TEXT:
- All subnet CIDR blocks clearly labeled
- Service names in bold
- Port numbers on connection lines
- Security group names as small badges
- "Jenkins Controller" and "Jenkins Agent" labels on EC2s

ADDITIONAL ELEMENTS:
- Small Jenkins logo on the Controller EC2 icons
- "ASG" label on Agent groups indicating Auto Scaling
- "Primary" and "Standby" labels on Controllers
- "On-Demand" label on Agent ASG
```

---

### Simplified Prompt (for tools with character limits)

```
Professional AWS architecture diagram, Jenkins CI/CD infrastructure:

- Light blue grid background, AWS official icons
- VPC (10.0.0.0/16) with 2 Availability Zones
- Public subnets: NAT Gateway, Bastion Host, Application Load Balancer
- Private subnets: Jenkins Controller EC2s (2), Jenkins Agent EC2s (Auto Scaling Group)
- Storage subnet: EFS for shared Jenkins home directory
- Show connections: Internet->ALB (443), ALB->Controllers (8080), Controllers->EFS (2049), Agents->Controllers (50000)
- Security groups labeled, route tables panel on right side
- Color coding: green=public, blue=private app, purple=storage
- Clean, professional, labeled with CIDR blocks and port numbers
```

---

### Tool-Specific Recommendations

| Tool | Best For | Notes |
|------|----------|-------|
| **Lucidchart** | Most accurate AWS diagrams | Has official AWS icon library |
| **draw.io (diagrams.net)** | Free, accurate | Import AWS icon stencils |
| **Cloudcraft** | 3D AWS diagrams | Great for presentations |
| **AWS Architecture Icons** | Official icons | Download from AWS |
| **Excalidraw** | Hand-drawn style | Good for informal docs |
| **Mermaid.js** | Code-based diagrams | Good for version control |

---

### ASCII Fallback (for documentation)

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                              AWS Cloud Region                                    │
│  ┌───────────────────────────────────────────────────────────────────────────┐  │
│  │                           VPC (10.0.0.0/16)                                │  │
│  │                                                                            │  │
│  │         Availability Zone A          │       Availability Zone B          │  │
│  │  ┌─────────────────────────────────┐ │ ┌─────────────────────────────────┐│  │
│  │  │ PUBLIC SUBNET A (10.0.1.0/24)   │ │ │ PUBLIC SUBNET B (10.0.2.0/24)   ││  │
│  │  │  ┌─────────┐  ┌─────────┐       │ │ │       ┌─────────────────┐       ││  │
│  │  │  │   NAT   │  │ Bastion │       │ │ │       │       ALB       │       ││  │
│  │  │  │ Gateway │  │  Host   │       │ │ │       │  (Jenkins URL)  │       ││  │
│  │  │  └─────────┘  └─────────┘       │ │ │       └────────┬────────┘       ││  │
│  │  └─────────────────────────────────┘ │ └────────────────┼────────────────┘│  │
│  │                                      │                  │                 │  │
│  │  ┌─────────────────────────────────┐ │ ┌────────────────┼────────────────┐│  │
│  │  │ PRIVATE SUBNET A (10.0.10.0/24) │ │ │ PRIVATE SUBNET B (10.0.20.0/24) ││  │
│  │  │  ┌─────────────┐  ┌──────────┐  │ │ │  ┌─────────────┐  ┌──────────┐  ││  │
│  │  │  │  Controller │  │  Agent   │  │◄┼─┼─►│  Controller │  │  Agent   │  ││  │
│  │  │  │   (Primary) │  │   ASG    │  │ │ │  │  (Standby)  │  │   ASG    │  ││  │
│  │  │  └──────┬──────┘  └──────────┘  │ │ │  └──────┬──────┘  └──────────┘  ││  │
│  │  └─────────┼───────────────────────┘ │ └─────────┼───────────────────────┘│  │
│  │            │                         │           │                        │  │
│  │  ┌─────────┼───────────────────────┐ │ ┌─────────┼───────────────────────┐│  │
│  │  │ STORAGE SUBNET (10.0.100.0/24)  │ │ │ STORAGE SUBNET (10.0.100.0/24)  ││  │
│  │  │         │                       │ │ │         │                       ││  │
│  │  │  ┌──────▼──────┐                │ │ │  ┌──────▼──────┐                ││  │
│  │  │  │    EFS      │◄───────────────┼─┼─┼─►│    EFS      │                ││  │
│  │  │  │ Mount Point │  Replication   │ │ │  │ Mount Point │                ││  │
│  │  │  └─────────────┘                │ │ │  └─────────────┘                ││  │
│  │  └─────────────────────────────────┘ │ └─────────────────────────────────┘│  │
│  │                                      │                                    │  │
│  └──────────────────────────────────────┴────────────────────────────────────┘  │
│                                                                                  │
└──────────────────────────────────────────────────────────────────────────────────┘

LEGEND:
├── Internet ──► ALB (HTTPS 443)
├── ALB ──► Controllers (HTTP 8080)
├── Controllers ──► EFS (NFS 2049)
├── Agents ──► Controllers (JNLP 50000)
└── Admin ──► Bastion (SSH 22) ──► Controllers (SSH 22)
```

---

## Color Codes (Hex Values)

| Element | Color | Hex Code |
|---------|-------|----------|
| AWS Cloud Background | Light Orange | #FFF4E5 |
| VPC Border | Orange | #FF9900 |
| Public Subnet | Light Green | #E8F5E9 |
| Private App Subnet | Light Blue | #E3F2FD |
| Private Storage Subnet | Light Purple | #F3E5F5 |
| Route Table Banner | Dark Blue | #232F3E |
| Security Group Badge | Red | #D32F2F |
| Connection Lines | Gray | #666666 |
| Labels | Black | #000000 |

---

## File Locations

Save generated diagrams to:
- `docs/images/architecture-diagram.png` - Main architecture diagram
- `docs/images/architecture-diagram.svg` - Vector version for scaling
- `README.md` - Embed in project documentation
