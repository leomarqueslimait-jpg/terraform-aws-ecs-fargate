locals {
  common_tags = {
    Project     = "terraform-aws-ecs-fargate"
    ManagedBy   = "Terraform"
    Environment = "Modules/Networking"
  }
}
resource "aws_vpc" "this" {
  
  cidr_block = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support = true
  tags       = merge(local.common_tags, { Name = "${var.name}-vpc-main" })
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(local.common_tags, { Name = "${var.name}-igw" })
}


resource "aws_nat_gateway" "this" {
  subnet_id     = aws_subnet.public[0].id
  allocation_id = aws_eip.nat.id
  depends_on    = [aws_internet_gateway.this]

  tags = merge(local.common_tags, { Name = "${var.name}-nat" })
}

resource "aws_eip" "nat" {
  domain = "vpc"

  tags = merge(local.common_tags, { Name = "${var.name}-eip" })
}



resource "aws_subnet" "private" {
  count             = length(var.private_subnets_cidr)
  vpc_id            = aws_vpc.this.id
  cidr_block        = var.private_subnets_cidr[count.index]
  availability_zone = var.azs[count.index]

  tags = merge(local.common_tags, { Name = "${var.name}-private-${count.index + 1}" })

}

resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this.id
  }

  tags = merge(local.common_tags, { Name = "${var.name}-private_rt" })
}


resource "aws_route_table_association" "private_rt" {
  count          = length(var.private_subnets_cidr)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private_rt.id

}


resource "aws_subnet" "public" {
  count                   = length(var.public_subnets_cidr)
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.public_subnets_cidr[count.index]
  availability_zone       = var.azs[count.index]
  map_public_ip_on_launch = true

  tags = merge(local.common_tags, { Name = "${var.name}-public-${count.index + 1}" })
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id

  }

  tags = merge(local.common_tags, { Name = "${var.name}-public_rt" })
}

resource "aws_route_table_association" "public_rt" {
  count          = length(var.public_subnets_cidr)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public_rt.id
}


resource "aws_subnet" "isolated" {
  count             = length(var.isolated_subnets_cidr)
  vpc_id            = aws_vpc.this.id
  cidr_block        = var.isolated_subnets_cidr[count.index]
  availability_zone = var.azs[count.index]

  tags = merge(local.common_tags, { Name = "${var.name}-isolated-${count.index + 1}" })

}

resource "aws_route_table" "isolated" {
  vpc_id = aws_vpc.this.id

  tags = merge(local.common_tags, { Name = "${var.name}-isolated_rt" })

}

resource "aws_route_table_association" "isolated" {
  count          = length(var.isolated_subnets_cidr)
  subnet_id      = aws_subnet.isolated[count.index].id
  route_table_id = aws_route_table.isolated.id

}