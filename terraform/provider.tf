terraform {
 required_providers {
   aws = {
     source  = "hashicorp/aws"
     version = "~> 5.83.0"
   }
 }

  backend "s3" {
   bucket = "ilyas-tfstate"
   key    = "state"
   region = "eu-central-1"
 }

}
