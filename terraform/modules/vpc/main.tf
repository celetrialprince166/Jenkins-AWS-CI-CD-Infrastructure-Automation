# ============================================================================
# VPC MODULE - Main Configuration
# ============================================================================
# PURPOSE: Create VPC, subnets, gateways, and route tables
# LOCATION: terraform/modules/vpc/main.tf
# ============================================================================
#
# ARCHITECTURE:
# ┌─────────────────────────────────────────────────────────────────────────┐
# │                           VPC (10.0.0.0/16)                             │
# │                                                                         │
# │  ┌─────────────────────────────┐  ┌─────────────────────────────┐      │
# │  │   PUBLIC SUBNET A           │  │   PUBLIC SUBNET B           │      │
# │  │   10.0.1.0/24               │  │   10.0.2.0/24               │      │
# │  │   - NAT Gateway             │  │   - ALB                     │      │
# │  │   - Bastion (optional)      │  │                             │      │
# │  └─────────────────────────────┘  └─────────────────────────────┘      │
# │                                                                         │
# │  ┌─────────────────────────────┐  ┌─────────────────────────────┐      │
# │  │   PRIVATE SUBNET A          │  │   PRIVATE SUBNET B          │      │
# │  │   10.0.10.0/24              │  │   10.0.20.0/24              │      │
# │  │   - Jenkins Controller      │  │   - Jenkins Controller      │      │
# │  │   - Jenkins Agents          │  │   - Jenkins Agents          │      │
# │  │   - EFS Mount Target        │  │   - EFS Mount Target        │      │
# │  └─────────────────────────────┘  └─────────────────────────────┘      │
# │                                                                         │
# └─────────────────────────────────────────────────────────────────────────┘
#
# ============================================================================

# ============================================================================
# VPC
# ============================================================================

resource "aws_vpc" "main" {
  # CIDR block for the VPC
  # /16 gives us 65,536 IP addresses
  cidr_block = var.vpc_cidr

  # Enable DNS hostnames
  # WHY: Required for EFS DNS resolution
  enable_dns_hostnames = true

  # Enable DNS support
  # WHY: Required for DNS resolution within VPC
  enable_dns_support = true

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-vpc"
  })
}

# ============================================================================
# INTERNET GATEWAY
# ============================================================================
# Allows resources in public subnets to reach the internet

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-igw"
  })
}

# ============================================================================
# PUBLIC SUBNETS
# ============================================================================
# Subnets with direct internet access (via Internet Gateway)

resource "aws_subnet" "public" {
  count = length(var.public_subnet_cidrs)

  vpc_id            = aws_vpc.main.id
  cidr_block        = var.public_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  # Auto-assign public IP to instances launched in this subnet
  map_public_ip_on_launch = true

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-public-${var.availability_zones[count.index]}"
    Tier = "Public"
  })
}

# ============================================================================
# PRIVATE SUBNETS
# ============================================================================
# Subnets without direct internet access (use NAT Gateway)

resource "aws_subnet" "private" {
  count = length(var.private_subnet_cidrs)

  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  # No public IP for private subnets
  map_public_ip_on_launch = false

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-private-${var.availability_zones[count.index]}"
    Tier = "Private"
  })
}

# ============================================================================
# ELASTIC IP FOR NAT GATEWAY
# ============================================================================
# Static IP address for NAT Gateway

resource "aws_eip" "nat" {
  domain = "vpc"

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-nat-eip"
  })

  # Ensure IGW exists before creating EIP
  depends_on = [aws_internet_gateway.main]
}

# ============================================================================
# NAT GATEWAY
# ============================================================================
# Allows private subnet resources to reach internet (outbound only)

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id  # Place in first public subnet

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-nat"
  })

  # Ensure IGW exists before creating NAT Gateway
  depends_on = [aws_internet_gateway.main]
}

# ============================================================================
# ROUTE TABLES
# ============================================================================

# PUBLIC ROUTE TABLE
# ------------------
# Routes traffic to Internet Gateway
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  # Route to internet via Internet Gateway
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-public-rt"
  })
}

# PRIVATE ROUTE TABLE
# -------------------
# Routes traffic to NAT Gateway
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  # Route to internet via NAT Gateway
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-private-rt"
  })
}

# ============================================================================
# ROUTE TABLE ASSOCIATIONS
# ============================================================================

# Associate public subnets with public route table
resource "aws_route_table_association" "public" {
  count = length(aws_subnet.public)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Associate private subnets with private route table
resource "aws_route_table_association" "private" {
  count = length(aws_subnet.private)

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# ============================================================================
# VPC FLOW LOGS (Optional but recommended)
# ============================================================================
# Captures network traffic for debugging and security analysis

resource "aws_cloudwatch_log_group" "flow_log" {
  name              = "/aws/vpc/${var.name_prefix}-flow-logs"
  retention_in_days = 30

  tags = var.tags
}

resource "aws_flow_log" "main" {
  vpc_id          = aws_vpc.main.id
  traffic_type    = "ALL"
  iam_role_arn    = aws_iam_role.flow_log.arn
  log_destination = aws_cloudwatch_log_group.flow_log.arn

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-flow-log"
  })
}


resource "aws_iam_role" "flow_log" {
  name = "${var.name_prefix}-flow-log-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "vpc-flow-logs.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "flow_log" {
  name = "${var.name_prefix}-flow-log-policy"
  role = aws_iam_role.flow_log.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}
