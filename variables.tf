variable "aws_region" {
  default = "ap-northeast-2"
}
variable "vpc_cidr" {
  default = "10.0.0.0/16"
}
variable "public_subnets" {
  type = map(string)
  default = {
    "ap-northeast-2a" = "10.0.1.0/24"
    "ap-northeast-2c" = "10.0.2.0/24"
  }
}
variable "private_subnets" {
  type = map(string)
  default = {
    "ap-northeast-2a" = "10.0.11.0/24"
    "ap-northeast-2c" = "10.0.12.0/24"
  }
}
