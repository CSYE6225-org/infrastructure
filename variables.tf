variable "vpc_cider_block" {
  type        = string
  description = "Cider Block"
  // default     = "10.0.0.0/16"
}

variable "cidr_block" {
  type = list(any)
  // default = [
  //   "10.0.0.0/16",
  //   "10.0.1.0/24",
  //   "10.0.2.0/24",
  //   "10.0.3.0/24",
  //   "10.0.4.0/24"
  // ]

}

variable "az_subnet" {
  type = list(any)
}

variable "vpc_region" {
  type        = string
  description = "region of VPC"
}

variable "aws_profile" {
  type        = string
  description = "region of VPC"
}

variable "vpc_name" {
  type        = string
  description = "Name of VPC"
}

variable "enable_dns_support" {
  type = string
}

variable "enable_dns_hostnames" {
  type = string
}

variable "enable_classiclink_dns_support" {
  type = string
}
variable "assign_generated_ipv6_cidr_block" {
  type = string
}

variable "route_table_cidr_block" {
  type = string
}