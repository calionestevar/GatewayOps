variable "name_prefix" {
  type = string
  default = "gateway-ops"
}

variable "cidr_block" {
  type = string
  default = "10.0.0.0/16"
}

variable "azs" {
  type = list(string)
  default = ["us-east-1a", "us-east-1b"]
}

variable "tags" {
  type    = map(string)
  default = {}
}