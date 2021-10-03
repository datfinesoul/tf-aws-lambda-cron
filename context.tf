resource "time_static" "default" {
  count = local.count
  triggers = {
    name = var.name
  }
}

locals {
  enabled           = var.enabled == true ? true : false
  count             = local.enabled ? 1 : 0
  name              = var.name
  environment       = var.environment
  purpose           = var.purpose
  project_namespace = var.project_namespace

  created_on = local.enabled ? formatdate(
    "YYYY-MM-DD", join("", time_static.default.*.rfc3339)
  ) : ""
  tags = merge({
    # TODO: Name should likely be renamed to something else
    "Name"             = local.name
    "Environment"      = local.environment
    "Purpose"          = local.purpose
    "ProjectNamespace" = local.project_namespace
    "CreatedOn"        = local.created_on
    "ManagedBy"        = "Terraform"

    # TODO: How could this be an override in the module, but not as a var
    "Module" = "terraform-lambda-cron"
  }, var.tags)
}

variable "name" {
  type        = string
  description = <<-DOC
  Solution name
  DOC
}

variable "environment" {
  type        = string
  description = <<-DOC
  An environement (default, prod, dev, etc.)
  DOC
}

variable "purpose" {
  type        = string
  description = <<-DOC
  Short description around the purpose or request for this resource
  DOC
}

variable "project_namespace" {
  # should not start or end with slashes
  type        = string
  description = <<-DOC
  A root namespace, that will group resources in AWS where possible so it's easier
  to grant access to them based on a project.
  DOC
}

variable "enabled" {
  type        = bool
  default     = true
  description = <<-DOC
  Set to false to prevent resource creation or to destroy existing resource
  DOC
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = <<-DOC
  Tags to assign to all resources
  DOC
}

