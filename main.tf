locals {
  subnet_zone_mapping = {
    "us-east-1a" = "10.0.2.0/24",
    "us-east-1b" = "10.0.3.0/24",
    "us-east-1c" = "10.0.4.0/24",
  }
}


resource "aws_vpc" "csye_vpc" {
  cidr_block                       = var.vpc_cider_block
  enable_dns_hostnames             = true
  enable_dns_support               = true
  enable_classiclink_dns_support   = true
  assign_generated_ipv6_cidr_block = false
  tags = {
    Name = "csye6225-vpc"
  }
}


resource "aws_subnet" "subnet1" {

  cidr_block              = element(var.cidr_block, 1)
  vpc_id                  = aws_vpc.csye_vpc.id
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "csye6225-subnet"
  }
}

resource "aws_subnet" "subnet2" {

  cidr_block              = element(var.cidr_block, 2)
  vpc_id                  = aws_vpc.csye_vpc.id
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true

  tags = {
    Name = "csye6225-subnet"
  }
}

resource "aws_subnet" "subnet3" {

  cidr_block              = element(var.cidr_block, 3)
  vpc_id                  = aws_vpc.csye_vpc.id
  availability_zone       = "us-east-1c"
  map_public_ip_on_launch = true

  tags = {
    Name = "csye6225-subnet"
  }
}

resource "aws_internet_gateway" "ig" {
  vpc_id = aws_vpc.csye_vpc.id

  tags = {
    Name = "csye_6225_ig"
  }
}

resource "aws_route_table" "csye6225-crt" {
  vpc_id = aws_vpc.csye_vpc.id

  route {
    //associated subnet can reach everywhere
    cidr_block = "0.0.0.0/0"
    //CRT uses this IGW to reach internet
    gateway_id = aws_internet_gateway.ig.id
  }

  tags = {
    Name = "csye6225-crt"
  }
}


resource "aws_route_table_association" "csye6225-crt1" {
  subnet_id      = aws_subnet.subnet1.id
  route_table_id = aws_route_table.csye6225-crt.id
}

resource "aws_route_table_association" "csye6225-crt2" {
  subnet_id      = aws_subnet.subnet2.id
  route_table_id = aws_route_table.csye6225-crt.id
}

resource "aws_route_table_association" "csye6225-crt3" {
  subnet_id      = aws_subnet.subnet3.id
  route_table_id = aws_route_table.csye6225-crt.id
}

// resource "aws_route_table_association" "csye6225-crta" {
//   for_each       = toset(aws_subnet.subnet[*].id)
//   subnet_id      = each.value
//   route_table_id = aws_route_table.csye6225-crt.id
// }

