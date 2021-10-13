variable "vpc_cider_block" {
  type        = string
  description = "Cider Block"
  default     = "10.0.0.0/16"
}

variable "cidr_block" {
  type = list(any)
  default = [
    "10.0.0.0/16",
    "10.0.1.0/24",
    "10.0.2.0/24",
    "10.0.3.0/24",
    "10.0.4.0/24"
  ]

}