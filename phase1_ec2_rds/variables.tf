variable "aws_region" {
  description = "AWS Region"
  type        = string
  default     = "ap-northeast-2"
}

variable "vpc_cidr" {
  description = "VPC CIDR Block"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnets" {
  description = "Public Subnet CIDR Blocks"
  type        = map(string)
  default = {
    "ap-northeast-2a" = "10.0.1.0/24"
    "ap-northeast-2c" = "10.0.2.0/24"
  }
}

variable "private_subnets" {
  description = "Private Subnet CIDR Blocks"
  type        = map(string)
  default = {
    "ap-northeast-2a" = "10.0.11.0/24"
    "ap-northeast-2c" = "10.0.12.0/24"
  }
}

variable "db_username" {
  description = "RDS Master Username"
  type        = string
  default     = "admin"
  sensitive   = true
}

variable "db_password" {
  description = "RDS Master Password"
  type        = string
  default     = "changeme123!"
  sensitive   = true
}

variable "db_name" {
  description = "Initial Database Name"
  type        = string
  default     = "lupangdb"
}
