# variable "profile" {
#   description = "AWS profile"
#   type        = string
# }

variable "region" {
  description = "AWS region to deploy to"
  default = "us-east-1"
  type        = string
}

variable "cluster_name" {
  description = "EKS cluster Name"
  default = "loci-new-infra-test"
  type = string
}