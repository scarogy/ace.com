variable "name"                 { type = string }
variable "region"               { type = string }
variable "vpc_cidr"             { type = string }
variable "public_subnets"       { type = list(string) }
variable "private_subnets"      { type = list(string) }
variable "enable_nat"           { type = bool   default = true }
variable "cluster_version"      { type = string }
variable "node_instance_types"  { type = list(string) default = ["t3.medium"] }
variable "desired_size"         { type = number default = 2 }
variable "domain_suffix"        { type = string }
variable "env_host"             { type = string }
variable "hosted_zone_id"       { type = string }
