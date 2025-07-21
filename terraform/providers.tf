
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.18.0"
    }
  }

  backend "s3" {
    bucket         	   = "jamby-tfstate"
    key              	   = "state/terraform.tfstate"
    region         	   = "us-east-2"
    encrypt        	   = true
    use_lockfile = true
  }
}