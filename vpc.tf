## creating vpc ##
resource "aws_vpc" "main" {
  cidr_block       = var.vpc_cidr
  instance_tenancy = "default"
  enable_dns_hostnames = var.enable_dns_hostnames

  tags = merge (
    var.common_tags,
    var.vpc_tags,
    {
        Name = local.resource_name
    }
  )
}
## creating and attaching IGW ##
resource "aws_internet_gateway" "gw" {
    vpc_id = aws_vpc.main.id    #attaching to vpc
    tags = merge (
        var.common_tags,
        var.igw_tags,
        {
            Name = local.resource_name
        }
    )
}
## creating subnets ##
# public subnet #
resource "aws_subnet" "public" { # first name is public[0], second name is public[1]
    count = length(var.public_subnet_cidrs) #to create 2 subnets
    availability_zone = local.az_names[count.index] 
    map_public_ip_on_launch = true
    vpc_id = aws_vpc.main.id
    cidr_block = var.public_subnet_cidrs[count.index]
    tags = merge (
        var.common_tags,
        var.public_subnet_cidr_tags,
        {
            Name = "${local.resource_name}-public-${local.az_names[count.index]}"
        }
    )
}
# private subnet #
resource "aws_subnet" "private" {  # first name is public[0], second name is public[1]
    count = length(var.private_subnet_cidrs) #to create 2 subnets
    availability_zone = local.az_names[count.index]
    vpc_id = aws_vpc.main.id
    cidr_block = var.private_subnet_cidrs[count.index]
    tags = merge (
        var.common_tags,
        var.private_subnet_cidr_tags,
        {
            Name = "${local.resource_name}-private-${local.az_names[count.index]}"
        }
    )
}
# database subnet #
resource "aws_subnet" "database" {  # first name is public[0], second name is public[1]
    count = length(var.database_subnet_cidrs) #to create 2 subnets
    availability_zone = local.az_names[count.index]
    vpc_id = aws_vpc.main.id
    cidr_block = var.database_subnet_cidrs[count.index]
    tags = merge (
        var.common_tags,
        var.database_subnet_cidr_tags,
        {
            Name = "${local.resource_name}-database-${local.az_names[count.index]}"
        }
    )
}
#creating database subnet group #
resource "aws_db_subnet_group" "default" {
    name = "${local.resource_name}"
    subnet_ids = aws_subnet.database[*].id

    tags = merge (
        var.common_tags,
        var.database_subnet_group_tags,
        {
            Name = "${local.resource_name}"  #expense-dev
        }
    )
}
## creating elastic ip ##
resource "aws_eip" "nat" {
    domain = "vpc"
}
## creating NAT gateway ##
resource "aws_nat_gateway" "nat" {
    allocation_id = aws_eip.nat.id
    subnet_id = aws_subnet.public[0].id #to add public subnet us-east-1a
    tags = merge (
        var.common_tags,
        var.nat_gateway_tags,
        {
            Name = "${local.resource_name}" #expense-dev
        }
    )
    # To ensure proper ordering, it is recommended to add an explicit dependency
    # on the Internet Gateway for the VPC.
    depends_on = [aws_internet_gateway.gw] 
}
## creating route tables ##
# public route table #
resource "aws_route_table" "public" {
    vpc_id = aws_vpc.main.id
    tags = merge (
        var.common_tags,
        var.public_route_table_tags,
        {
            Name = "${local.resource_name}-public" #expense-dev-public
        }
    )
}
# private route table #
resource "aws_route_table" "private" {
    vpc_id = aws_vpc.main.id
    tags = merge (
        var.common_tags,
        var.private_route_table_tags,
        {
            Name = "${local.resource_name}-private" #expense-dev-private
        }
    )
}
# database route table #
resource "aws_route_table" "database" {
    vpc_id = aws_vpc.main.id
    tags = merge (
        var.common_tags,
        var.database_route_table_tags,
        {
            Name = "${local.resource_name}-database" #expense-dev-database
        }
    )
}
## adding route to route table ##
# public route table to internet gateway #
resource "aws_route" "public_route" {
    route_table_id = aws_route_table.public.id
    destination_cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
}
 # private route table to NAT gateway #
resource "aws_route" "private_route" {
    route_table_id = aws_route_table.private.id
    destination_cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
}
# database route table to NAT gateway #
resource "aws_route" "database_route" {
    route_table_id = aws_route_table.database.id
    destination_cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
}
## associating route to subnets ##
# public #
resource "aws_route_table_association" "public" {
    count = length(var.public_subnet_cidrs)
    subnet_id = element(aws_subnet.public[*].id, count.index)
    route_table_id = aws_route_table.public.id
}
# private #
resource "aws_route_table_association" "private" {
    count = length(var.private_subnet_cidrs)
    subnet_id = element(aws_subnet.private[*].id, count.index)
    route_table_id = aws_route_table.private.id
}
# database #
resource "aws_route_table_association" "database" {
    count = length(var.database_subnet_cidrs)
    subnet_id = element(aws_subnet.database[*].id, count.index)
    route_table_id = aws_route_table.database.id
}
variable "vpc_peering_tags" {
    type = map
    default = {}
}

