# resource "aws_vpc" "main" {
#   cidr_block = "10.0.0.0/16"
# }

# resource "aws_subnet" "public_a" {
#   vpc_id     = aws_vpc.main.id
#   cidr_block = "10.0.0.0/24"

#   availability_zone = "us-east-1a"

#   tags = {
#     Name = "Public Subnet A"
#   }
# }

# resource "aws_subnet" "public_b" {
#   vpc_id     = aws_vpc.main.id
#   cidr_block = "10.0.1.0/24"

#   availability_zone = "us-east-1b"

#   tags = {
#     Name = "Public Subnet B"
#   }
# }

# resource "aws_subnet" "private_a" {
#   vpc_id     = aws_vpc.main.id
#   cidr_block = "10.0.4.0/22"

#   availability_zone = "us-east-1a"

#   tags = {
#     Name = "Private Subnet A"
#   }
# }

# resource "aws_subnet" "private_b" {
#   vpc_id     = aws_vpc.main.id
#   cidr_block = "10.0.8.0/22"

#   availability_zone = "us-east-1b"

#   tags = {
#     Name = "Private Subnet B"
#   }
# }


# resource "aws_internet_gateway" "igw" {
#   vpc_id = aws_vpc.main.id
# }


# resource "aws_route_table" "public_route_table" {
#   vpc_id = aws_vpc.main.id

#   route {
#     cidr_block = "10.0.0.0/16"
#     gateway_id = "local"
#   }

#   route {
#     cidr_block = "0.0.0.0/0"
#     gateway_id = aws_internet_gateway.igw.id
#   }
# }
# resource "aws_route_table" "private_route_table" {
#   vpc_id = aws_vpc.main.id

#   route {
#     cidr_block = "10.0.0.0/16"
#     gateway_id = "local"
#   }
# }
# resource "aws_route_table_association" "private_a" {
#   subnet_id      = aws_subnet.private_a.id
#   route_table_id = aws_route_table.private_route_table.id
# }

# resource "aws_route_table_association" "private_b" {
#   subnet_id      = aws_subnet.private_b.id
#   route_table_id = aws_route_table.private_route_table.id
# }

# resource "aws_route_table_association" "public_a" {
#   subnet_id      = aws_subnet.public_a.id
#   route_table_id = aws_route_table.public_route_table.id
# }

# resource "aws_route_table_association" "public_b" {
#   subnet_id      = aws_subnet.public_b.id
#   route_table_id = aws_route_table.public_route_table.id
# }
