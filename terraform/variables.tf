variable "region" {
  description = "AWS region to deploy the VPN server in"
  type        = string
  default     = "eu-central-1"
}

variable "AZ" {
  description = "Availability zone for the default subnet"
  type        = string
}

variable "key_name" {
  description = "Name of the SSH key pair"
  type        = string
  default     = "myKey"
}
