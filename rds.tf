# data "aws_db_cluster_snapshot" "snapshot" {
#   db_cluster_identifier = "school-db"
#   most_recent           = true
# }

resource "aws_rds_cluster" "school_db" {
  cluster_identifier     = "the-school-db"
  engine                 = "aurora-mysql"
  engine_mode            = "provisioned"
  engine_version         = "8.0"
  storage_encrypted      = true
  skip_final_snapshot    = true
  availability_zones     = var.vpc_azs
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]

  database_name           = "school_database"
  master_username         = "admin"
  master_password         = "school_password"
  serverlessv2_scaling_configuration {
    max_capacity = 1.0
    min_capacity = 0.5
  }


}

resource "aws_db_subnet_group" "main" {
  name       = "main"
  subnet_ids = module.vpc.intra_subnets
  tags = {
    Name = "My DB subnet group"
  }
}

resource "aws_rds_cluster_instance" "example" {
  cluster_identifier   = aws_rds_cluster.school_db.id
  instance_class       = "db.serverless"
  engine               = aws_rds_cluster.school_db.engine
  engine_version       = aws_rds_cluster.school_db.engine_version
  db_subnet_group_name = aws_db_subnet_group.main.name
}

