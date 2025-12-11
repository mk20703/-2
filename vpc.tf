resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = "Main VPC" }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "Main IGW" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
  tags = { Name = "Public Route Table" }
}

# Elastic IP for NAT Gateway (AZ A)
resource "aws_eip" "nat_a" {
  domain = "vpc"
  tags   = { Name = "NAT Gateway EIP AZ-A" }
}

# Elastic IP for NAT Gateway (AZ C)
resource "aws_eip" "nat_c" {
  domain = "vpc"
  tags   = { Name = "NAT Gateway EIP AZ-C" }
}

# NAT Gateway in Public Subnet AZ-A
resource "aws_nat_gateway" "nat_a" {
  allocation_id = aws_eip.nat_a.id
  subnet_id     = aws_subnet.public["ap-northeast-2a"].id
  tags          = { Name = "NAT Gateway AZ-A" }

  depends_on = [aws_internet_gateway.main]
}

# NAT Gateway in Public Subnet AZ-C
resource "aws_nat_gateway" "nat_c" {
  allocation_id = aws_eip.nat_c.id
  subnet_id     = aws_subnet.public["ap-northeast-2c"].id
  tags          = { Name = "NAT Gateway AZ-C" }

  depends_on = [aws_internet_gateway.main]
}

# Private Route Table for AZ-A
resource "aws_route_table" "private_a" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_a.id
  }

  tags = { Name = "Private Route Table AZ-A" }
}

# Private Route Table for AZ-C
resource "aws_route_table" "private_c" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_c.id
  }

  tags = { Name = "Private Route Table AZ-C" }
}

resource "aws_subnet" "public" {
  for_each                = var.public_subnets
  vpc_id                  = aws_vpc.main.id
  cidr_block              = each.value
  availability_zone       = each.key
  map_public_ip_on_launch = true
  tags                    = { Name = "Public Subnet ${each.key}" }
}

resource "aws_subnet" "private" {
  for_each          = var.private_subnets
  vpc_id            = aws_vpc.main.id
  cidr_block        = each.value
  availability_zone = each.key
  tags              = { Name = "Private Subnet ${each.key}" }
}

resource "aws_route_table_association" "public" {
  for_each       = aws_subnet.public
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private_a" {
  subnet_id      = aws_subnet.private["ap-northeast-2a"].id
  route_table_id = aws_route_table.private_a.id
}

resource "aws_route_table_association" "private_c" {
  subnet_id      = aws_subnet.private["ap-northeast-2c"].id
  route_table_id = aws_route_table.private_c.id
}
