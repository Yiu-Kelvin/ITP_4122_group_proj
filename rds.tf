resource "aws_rds_cluster" "school_db" {
  cluster_identifier = "school-db"
  engine             = "aurora-mysql"
  engine_mode        = "provisioned"
  engine_version     = "8.0"
  database_name      = "school_database"
  master_username    = "admin"
  master_password    = "school_password"
  storage_encrypted  = true
  skip_final_snapshot = true
  
  serverlessv2_scaling_configuration {
    max_capacity = 1.0
    min_capacity = 0.5
  }

}

resource "aws_rds_cluster_instance" "example" {
  cluster_identifier = aws_rds_cluster.school_db.id
  instance_class     = "db.serverless"
  engine             = aws_rds_cluster.school_db.engine
  engine_version     = aws_rds_cluster.school_db.engine_version
  
}