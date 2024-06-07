module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 4.0"

  name = var.vpc_name
  cidr = var.vpc_cidr

  azs             = var.vpc_azs
  private_subnets = var.subnets.private_subnets
  public_subnets  = var.subnets.public_subnets
  intra_subnets   = var.subnets.intra_subnets

  enable_nat_gateway = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }
}


resource "aws_security_group" "allow_efs" {
  name        = "allow_tls"
  description = "allows inbound network file system (NFS) traffic for Amazon EFS mount points"
  vpc_id      = module.vpc.vpc_id

  tags = {
    Name = "allow_efs"
  }
}

resource "aws_vpc_security_group_ingress_rule" "allow_efs_all_ingress" {
  security_group_id = aws_security_group.allow_efs.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}


resource "aws_vpc_security_group_egress_rule" "allow_efs_all_egress" {
  security_group_id = aws_security_group.allow_efs.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}


resource "aws_security_group" "rds_sg" {
  name        = "rds_sg"
  description = "Security group for RDS"
  vpc_id      = module.vpc.vpc_id
  tags = {
    Name = "rds_sg"
  }
}

resource "aws_security_group_rule" "rds_sg_ingress" {
  type              = "ingress"
  from_port         = 3306
  to_port           = 3306
  protocol          = "tcp"
  security_group_id = aws_security_group.rds_sg.id
  # source_security_group_id = module.eks.node_security_group_id
  cidr_blocks = ["0.0.0.0/0"]
}


resource "aws_security_group_rule" "rds_sg_egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.rds_sg.id
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_vpc_security_group_ingress_rule" "cluster_rds_ingress" {
  security_group_id = module.eks.node_security_group_id

  from_port                    = 3306
  to_port                      = 3306
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.rds_sg.id
}