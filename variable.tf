variable "s3_bucket_name" {
  type = string
}

variable "s3_prefix" {
  type    = string
  default = "project/star-wars/lambda/"
}

variable "lambda_runtime" {
  type = string
}

variable "lambda_handler" {
  type = string
}

variable "lambda_input" {
  type = string
}

variable "schedule_expression" {
  type = string
}

variable "branches" {
  type    = set(string)
  default = ["main"]
}

variable "github_repository" {
  type = string
}
