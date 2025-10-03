variable "enabled" {
  type    = bool
  default = true
}

variable "name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "db_name" {
  type    = string
  default = "appdb"
}

variable "engine_version" {
  type    = string
  default = "15"
}

variable "instance_class" {
  type    = string
  default = "db.t4g.micro"
}

variable "backup_retention" {
  type    = number
  default = 7
}

variable "deletion_protection" {
  type    = bool
  default = false
}

variable "ingress_security_group_ids" {
  type    = list(string)
  default = []
}
