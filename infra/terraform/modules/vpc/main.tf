resource "aws_vpc" "this" {
  cidr_block           = var.cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = { Name = "${var.name}-vpc" }
}

resource "aws_internet_gateway" "igw" { 
  vpc_id = aws_vpc.this.id 
}



# ---------- Locals for convenience ----------
locals {
  public_subnet_ids  = [for s in aws_subnet.public  : s.id]
  private_subnet_ids = [for s in aws_subnet.private : s.id]
  first_public_subnet_id = length(local.public_subnet_ids) > 0 ? local.public_subnet_ids[0] : null
}

# ---------- NAT (optional) ----------
# Elastic IP for NAT
resource "aws_eip" "nat" {
  count = var.enable_nat ? 1 : 0
  vpc   = true
  tags  = { Name = "${var.name}-nat-eip" }
}

# NAT Gateway in the first public subnet
resource "aws_nat_gateway" "this" {
  count         = var.enable_nat ? 1 : 0
  allocation_id = aws_eip.nat[0].id
  subnet_id     = local.first_public_subnet_id
  tags          = { Name = "${var.name}-nat" }
  depends_on    = [aws_internet_gateway.igw]
}


# ---------- Route tables ----------
# Public route table: 0.0.0.0/0 via Internet Gateway
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${var.name}-public-rt" }
}

resource "aws_route" "public_default" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

# Associate all public subnets with the public route table
resource "aws_route_table_association" "public" {
  for_each       = aws_subnet.public
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

# Private route table (single RT for simplicity)
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${var.name}-private-rt" }
}

# Default route in private RT to NAT (only if NAT enabled)
resource "aws_route" "private_default_via_nat" {
  count                  = var.enable_nat ? 1 : 0
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this[0].id
}

# Associate all private subnets with the private route table
resource "aws_route_table_association" "private" {
  for_each       = aws_subnet.private
  subnet_id      = each.value.id
  route_table_id = aws_route_table.private.id
}

###

data "aws_availability_zones" "available" {
  state = "available"
}

# Public subnets across AZs
resource "aws_subnet" "public" {
  for_each          = { for idx, cidr in var.public_subnets : idx => cidr }
  vpc_id            = aws_vpc.this.id
  cidr_block        = each.value
  map_public_ip_on_launch = true
  availability_zone = data.aws_availability_zones.available.names[tonumber(each.key) % length(data.aws_availability_zones.available.names)]
  tags = { Name = "${var.name}-public-${each.key}" }
}

# Private subnets across AZs
resource "aws_subnet" "private" {
  for_each          = { for idx, cidr in var.private_subnets : idx => cidr }
  vpc_id            = aws_vpc.this.id
  cidr_block        = each.value
  availability_zone = data.aws_availability_zones.available.names[tonumber(each.key) % length(data.aws_availability_zones.available.names)]
  tags = { Name = "${var.name}-private-${each.key}" }

}
