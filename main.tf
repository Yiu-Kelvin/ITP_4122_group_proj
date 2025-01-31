terraform {

  backend "s3" {
    bucket = "terraform-state-0yqvjk6vls36nxe5kovq5rqabaof5zr9"
    key = "itp4122project/terraform.tfstate"
    region = "us-east-1"
  }
  required_providers {
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.7.0"
    }
    kubernetes = {
      source  = "registry.terraform.io/hashicorp/kubernetes"
      version = "2.29.0"
    }
    http = {
      source = "registry.terraform.io/hashicorp/http"
    }
    null = {
      source = "registry.terraform.io/hashicorp/null"
    }
  }
}
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
# Configure the AWS Provider
provider "aws" {
  region = "us-east-1"
}