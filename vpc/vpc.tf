### VPC Network Setup
resource "aws_vpc" "custom_vpc" {
  # Your VPC must have DNS hostname and DNS resolution support. 
  # Otherwise, your worker nodes cannot register with your cluster. 

  cidr_block       = var.vpc_cidr_block
  enable_dns_support = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.vpc_tag_name}"
    "kubernetes.io/cluster/${var.eks_cluster_name}" = "shared"
  }
}

# Create the private subnet
resource "aws_subnet" "private_subnet" {
  count = length(var.availability_zones)
  vpc_id            = aws_vpc.custom_vpc.id
  cidr_block = element(var.private_subnet_cidr_blocks, count.index)
  availability_zone = element(var.availability_zones, count.index)

  tags = {
    Name = "${var.eks_cluster_name}-${var.private_subnet_tag_name}-${element(var.availability_zones, count.index)}"
    "kubernetes.io/cluster/${var.eks_cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb" = 1
  }
}

# Create the public subnet
resource "aws_subnet" "public_subnet" {
  count = length(var.availability_zones)
  vpc_id            = "${aws_vpc.custom_vpc.id}"
  cidr_block = element(var.public_subnet_cidr_blocks, count.index)
  availability_zone = element(var.availability_zones, count.index)

  tags = {
    Name = "${var.eks_cluster_name}-${var.public_subnet_tag_name}-${element(var.availability_zones, count.index)}"
    "kubernetes.io/cluster/${var.eks_cluster_name}" = "shared"
    "kubernetes.io/role/elb" = 1
  }

  map_public_ip_on_launch = true
}

# Create IGW for the public subnets
resource "aws_internet_gateway" "igw" {
  vpc_id = "${aws_vpc.custom_vpc.id}"

  tags = {
    Name = "${var.vpc_tag_name}-public-igw"
  }
}

# Route the public subnet traffic through the IGW
resource "aws_route_table" "main" {
  vpc_id = "${aws_vpc.custom_vpc.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.igw.id}"
  }

  tags = {
    Name = "${var.vpc_tag_name}-public"
  }
}

# Route table and subnet associations
resource "aws_route_table_association" "internet_access" {
  count = length(var.availability_zones)
  subnet_id      = "${aws_subnet.public_subnet[count.index].id}"
  route_table_id = "${aws_route_table.main.id}"
}


# Route the private subnet traffic 
resource "aws_route_table" "private" {
  vpc_id = "${aws_vpc.custom_vpc.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_nat_gateway.main.id}"
  }

  tags = {
    Name = "${var.vpc_tag_name}-private"
  }
}

# Route table and subnet associations
resource "aws_route_table_association" "nat_access" {
  count = length(var.availability_zones)
  subnet_id      = "${aws_subnet.private_subnet[count.index].id}"
  route_table_id = "${aws_route_table.private.id}"
}