# tf-aws-lambda-cron

## Overview

An infrastructure focused Terraform module, that sets up an AWS lambda function placeholder, which is executed on a schedule, but deployed completely via GitHub.

### Requirements

| Terraform Provider    | Version    |
| --------------------- | ---------- |
| `integrations/github` | `~> 4.14`  |
| `hashicorp/aws`       | `~> 3.59`  |
| `hashicorp/time`      | `~> 0.7.2` |

## Usage

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
    "Extra" : "Hello World!"
  }

  # S3 bucket that will be used for the lambda
  s3_bucket_name = "aws-dn-prod-main"
  # Prefix s3 key for the lambda artifact
  s3_prefix = "projects/star-wars/lambda/"

  # https://docs.aws.amazon.com/lambda/latest/dg/lambda-runtimes.html
  lambda_runtime = "nodejs14.x"
  lambda_handler = "main.handler"
  lambda_input   = ""
  # https://docs.aws.amazon.com/AmazonCloudWatch/latest/events/ScheduledEvents.html
  schedule_expression = "rate(1 hour)"
  # GitHub branches
  branches = ["main"] # default: ["main"]
}
```

## Development

### Notes

- S3 bucket/prefix with versioning is required if publish=true
- Currently only works with JS
- branches list (first branch will be the actual cron)

### To Do

- See if how to add aliased provider
- other option, maybe let GitHub create and manage aliases? 
- Automate updating the version

### Setup

```bash
mkdir -p ./modules
ln -rs ~/github/tf-aws-lambda-cron/ ./modules/tf-aws-lambda-cron
```

