
resource "aws_vpc" "csye_vpc" {
  cidr_block                       = var.vpc_cider_block
  enable_dns_hostnames             = var.enable_dns_hostnames
  enable_dns_support               = var.enable_dns_support
  enable_classiclink_dns_support   = var.enable_classiclink_dns_support
  assign_generated_ipv6_cidr_block = var.assign_generated_ipv6_cidr_block
  tags = {
    Name = var.vpc_name
  }
}


resource "aws_subnet" "subnet1" {

  cidr_block              = element(var.cidr_block, 0)
  vpc_id                  = aws_vpc.csye_vpc.id
  availability_zone       = element(var.az_subnet, 0)
  map_public_ip_on_launch = true

  tags = {
    Name = "csye6225-subnet"
  }
}

resource "aws_subnet" "subnet2" {

  cidr_block              = element(var.cidr_block, 1)
  vpc_id                  = aws_vpc.csye_vpc.id
  availability_zone       = element(var.az_subnet, 1)
  map_public_ip_on_launch = true

  tags = {
    Name = "csye6225-subnet"
  }
}

resource "aws_subnet" "subnet3" {

  cidr_block              = element(var.cidr_block, 2)
  vpc_id                  = aws_vpc.csye_vpc.id
  availability_zone       = element(var.az_subnet, 2)
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
    cidr_block = var.route_table_cidr_block
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

