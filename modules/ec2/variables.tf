variable "vpc_id" {
  type        = string
  description = "VPC ID"
}

variable "security_group_id" {
    type = string
    description = "security group for ec2 instance"
}

variable "s3_bucket" {
    type = string
    description = "s3 bucket name for the ec2 instance"
}

variable "ssh_key" {
    type = string
    description = "ssh public key to access the ec2 instance"
}

variable "code_deploy_bucket" {
    type = string
    description = "code deploy bucket"
}

variable "rds_identifier" {
  type        = string
  description = "Identifier for the RDS instance"
}

variable "database_username" {
  type        = string
  description = "Username for the RDS instance"
}

variable "database_password" {
  type        = string
  description = "password for the RDS instance"
}

variable "ami_id" {
    type = string
    description = "ami image to build the instance from"
}

variable "aws_profile" {
  type        = string
  description = "AWS account profile to create resources in"
}
