
variable "cluster_name" {
  type    = string
  default = "school-cluster"
}
variable "app_username" {
  type    = string
  default = "admin"
}

variable "app_password" {
  type      = string
  default   = "aA!12345678"
  sensitive = true
}
variable "db_name" {
  type    = string
  default = "school_database"
}

variable "db_username" {
  type      = string
  default   = "admin"
  sensitive = true
}

variable "db_password" {
  type      = string
  default   = "school_password"
  sensitive = true
}

variable "region" {
  type    = string
  default = "us-east-1"
}

variable "vpc_name" {
  type    = string
  default = "school-vpc"
}
variable "vpc_cidr" {
  type    = string
  default = "10.123.0.0/16"
}
variable "vpc_azs" {
  type    = list(string)
  default = ["us-east-1a", "us-east-1b", "us-east-1c"]
}
variable "subnets" {
  type = map(list(string))
  default = {
    "public_subnets"  = ["10.123.1.0/24", "10.123.2.0/24"],
    "private_subnets" = ["10.123.3.0/24", "10.123.4.0/24"],
    "intra_subnets"   = ["10.123.5.0/24", "10.123.6.0/24", "10.123.7.0/24"]
  }
}

variable "efs_id" {
  type    = string
  default = "fs-09c9468d49fe81195"
}