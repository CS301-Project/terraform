terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.92"
    }
  }

  required_version = ">= 1.2"
}

provider "aws" {
  region = "ap-southeast-1"
}

#us-east-1 provider alias for CloudFront ACM + WAF (CLOUDFRONT)
provider "aws" {
  alias  = "use1"
  region = "us-east-1"
}
