# red: VPC with one public subnet (nodes and the ingress NLB) and two private subnets (RDS and the
# EKS control-plane ENIs; both need two AZs). No NAT gateway (~USD 1/day): nodes get public IPs
# and pull images through the internet gateway; the cluster security group allows no inbound
# from the internet except the NodePorts the NLB controller opens (D-38).
#
# Only one public subnet exists on purpose: the EKS cloud controller places an internet-facing
# NLB in one public subnet per AZ, and one Elastic IP means one subnet.

resource "aws_vpc" "main" {
  cidr_block           = var.cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = "vpc-${var.name}" }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "igw-${var.name}" }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.cidr, 4, 0) # 10.0.0.0/20
  availability_zone       = var.azs[0]
  map_public_ip_on_launch = true
  tags = {
    Name                                        = "snet-${var.name}-public"
    "kubernetes.io/role/elb"                    = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
  tags = { Name = "rt-${var.name}-public" }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# No route to the internet: only VPC-local traffic (RDS, control-plane ENIs).
resource "aws_subnet" "private" {
  count             = length(var.azs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.cidr, 8, 64 + count.index) # 10.0.64.0/24, 10.0.65.0/24
  availability_zone = var.azs[count.index]
  tags              = { Name = "snet-${var.name}-private-${var.azs[count.index]}" }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "rt-${var.name}-private" }
}

resource "aws_route_table_association" "private" {
  count          = length(var.azs)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}
