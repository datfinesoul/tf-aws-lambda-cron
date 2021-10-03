terraform {
  required_version = "~> 1.0.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.59"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.7.2"
    }
    github = {
      source  = "integrations/github"
      version = "~> 4.14"
    }
  }
}
