# tf-aws-lambda-cron

## Overview

An infrastructure focused Terraform module, that sets up an AWS lambda function placeholder, which is executed on a schedule, but deployed completely via GitHub.

### Requirements

| Terraform Provider    | Version    | Notes                           |
| --------------------- | ---------- | ------------------------------- |
| `integrations/github` | `~> 4.14`  | Needs ability to create secrets |
| `hashicorp/aws`       | `~> 3.59`  |                                 |
| `hashicorp/time`      | `~> 0.7.2` |                                 |

## Example Use Case

```terraform
module "my_lambda" {
  # It's best practice to postfix the source with a version or SHA
  # eg. "?ref=v0.1-alpha.1"
  source    = "github.com/datfinesoul/tf-aws-lambda-cron"
  providers = { aws = aws }

  # Required general information
  name              = "deathstar-3"
  project_namespace = "star-wars"
  environment       = "development"
  purpose           = "readme sample for datfinesoul/tf-aws-lambda-cron"

  enabled = true # default: true
  # Additional tags (the "general information" fields above become tags by default)
  tags = {       # default: {}
    "Extra" : "Hello World"
  }

  # S3 bucket that will be used for the lambda
  s3_bucket_name = "my-bucket-name"
  # Prefix s3 key for the lambda artifact
  s3_prefix = "projects/star-wars/lambda/"

  # https://docs.aws.amazon.com/lambda/latest/dg/lambda-runtimes.html
  lambda_runtime = "nodejs14.x"
  lambda_handler = "main.handler"
  lambda_input   = ""
  # https://docs.aws.amazon.com/AmazonCloudWatch/latest/events/ScheduledEvents.html
  schedule_expression = "rate(1 hour)"
  # GitHub branches
  branches          = ["main"] # default: ["main"]
  github_repository = "lambda-collection"
}
    
terraform {
  required_version = "~> 1.0.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
    github = {
      source  = "integrations/github"
      version = "~> 4.0"
    }
  }
}

# Need to be configured individual use case
provider "aws" {
  region = "ap-northeast-1"
}
provider "github" {
  owner = "mygithubusername"
}
```

### What Gets Created In The Example

S3

- Placeholder S3 object `s3://my-bucket-name/projects/star-wars/lambda/deathstar-3.zip`
  - Not a functional lambda, but instead a placeholder for future build artifacts.

SecretsManager

- [`lambda/deathstar-3/env`](https://ap-northeast-1.console.aws.amazon.com/secretsmanager/home?region=ap-northeast-1#!/secret?name=lambda%2Fdeathstar-3%2Fenv) secret (not value), which is accessible by the lambda

Lambda

- `deathstar-3` lambda function
- [`deathstar-3:main`](https://ap-northeast-1.console.aws.amazon.com/lambda/home?region=ap-northeast-1#/functions/deathstar-3?tab=versions) alias pointed at the lambda function

EventBridge

- [`lambda-deathstar-3-cron`](https://ap-northeast-1.console.aws.amazon.com/events/home?region=ap-northeast-1#/eventbus/default/rules/lambda-deathstar-3-cron) rule that invokes the lambda on a schedule

IAM

- [`lambda-deathstar-3`](https://console.aws.amazon.com/iam/home#/roles/lambda-deathstar-3) IAM role

- `lambda-deathstar-3` IAM policy that allows lambda access to CloudWatch and SecretsManager via the previous IAM role
- `lambda-deathstar-3-github` IAM policy to allow GitHub to deploy updates to the function

CloudWatch

- [`/aws/lambda/deathstar-3`](https://ap-northeast-1.console.aws.amazon.com/cloudwatch/home?region=ap-northeast-1#logsV2:log-groups/log-group/$252Faws$252Flambda$252Fdeathstar-3) log group

### Roadmap

- Allow IAM User to be passed into the module and make IAM User creation optional
- GitHub policy needs ability to update secret??  Or maybe custom policy override for github user.
- Secret needs to use project-namespace
- Check use of "Name" tag
- Project Namespace in lambda name, or optional?

## GitHub Deployment

## Development

### Notes

- S3 bucket/prefix with versioning is required if publish=true
- Currently only works with JS
- branches list (first branch will be the actual cron)

### Thoughts

- other option, maybe let GitHub create and manage aliases? 
- Automate updating the version

### Setup

```bash
mkdir -p ./modules
ln -rs ~/github/tf-aws-lambda-cron/ ./modules/tf-aws-lambda-cron
```

