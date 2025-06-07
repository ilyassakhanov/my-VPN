variable "region" {
    description = "AWS Region"
    type = string
    default = "eu-central-1"
}

variable "ami_id" {
    description = "AWS AMI ID"
    type = string
    default = "ami-02b7d5b1e55a7b5f1"
}

variable "key_name" {
    description = "my ssh key"
    type = string
    default = "my-key"
}