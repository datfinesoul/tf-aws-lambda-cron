# TODO: add paths with IAM maybe a project-name/scope?

data "aws_s3_bucket" "default" {
  bucket = var.s3_bucket_name
}

locals {
  # a placeholder file, so that the s3 key of the lambda can be established
  file        = "${path.module}/templates/index.zip"
  key         = "${var.s3_prefix}${local.name}.zip"
  lo_name     = replace(local.name, "-", "_")
  main_branch = join("", var.branches)
}

resource "aws_s3_bucket_object" "default" {
  count = local.count

  key                    = local.key
  bucket                 = data.aws_s3_bucket.default.id
  source                 = local.file
  server_side_encryption = "AES256"

  tags = local.tags

  lifecycle {
    ignore_changes = [
      tags,
      etag,
      version_id,
    ]
  }
}

resource "aws_cloudwatch_log_group" "default" {
  count = local.count

  # "name" cannot be changed to a different path, this is a lambda restriction
  name              = "/aws/lambda/${local.name}"
  retention_in_days = 1

  tags = local.tags
}

# TODO: could we make the secret trust the lambda vs the lambda getting access to the secret?
resource "aws_secretsmanager_secret" "default" {
  count = local.count

  # The reasoning behind the naming convention is just ease of lookup.
  # All lambdas are grouped, then looked up by name, and then any related secrets
  # are in that namespace.
  name                    = "lambda/${local.name}/env"
  recovery_window_in_days = 0
  description             = "${local.name} lambda environment variables"

  tags = local.tags
}

# IAM role which dictates what other AWS services the Lambda function
# may access.
resource "aws_iam_role" "default" {
  count = local.count

  name               = "lambda-${local.name}"
  path               = "/project/${var.project_namespace}/" #TODO: maybe make a local append slashes
  assume_role_policy = file("${path.module}/templates/default.role.json")

  tags = local.tags
}

resource "aws_iam_policy" "default" {
  count = local.count

  name        = "lambda-${local.name}"
  path        = "/project/${var.project_namespace}/" #TODO: maybe make a local append slashes
  description = "${local.name} lambda default policy"

  policy = templatefile("${path.module}/templates/default.policy.json", {
    SecretArn = replace(
      aws_secretsmanager_secret.default[0].arn,
      "/(?:-)[a-zA-Z0-9]{6}$/",
      "-??????"
    )
    LogGroupArn = aws_cloudwatch_log_group.default[0].arn
  })

  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "default" {
  count = local.count

  role       = aws_iam_role.default[0].name
  policy_arn = aws_iam_policy.default[0].arn
}

# TODO: Right now it will create a new IAM User for this access, but the plan is
#       to have that as an optional argument, in which case we would not create it.
# TODO: This also should have policy tied to a role, and give the user only access to
#       assume the role with the actual policy

resource "aws_iam_user" "github" {
  count = local.count

  name          = "lambda-${local.name}"
  path          = "/project/${var.project_namespace}/" #TODO: maybe make a local append slashes
  force_destroy = true

  tags = local.tags
}

resource "aws_iam_access_key" "github" {
  count = local.count

  user = aws_iam_user.github[0].name
}

resource "aws_iam_policy" "github" {
  count = local.count

  name        = "lambda-${local.name}-github"
  path        = "/project/${var.project_namespace}/" #TODO: maybe make a local append slashes
  description = "${local.name} lambda github access"

  policy = templatefile(
    "${path.module}/templates/github.policy.json", {
      S3ArtifactARN = "${data.aws_s3_bucket.default.arn}/${local.key}",
      S3BucketARN   = data.aws_s3_bucket.default.arn,
      LambdaArn     = aws_lambda_function.default[0].arn
  })

  tags = local.tags
}

resource "aws_iam_user_policy_attachment" "github" {
  count = local.count

  user       = aws_iam_user.github[0].name
  policy_arn = aws_iam_policy.github[0].arn
}

resource "aws_lambda_function" "default" {
  count = local.count

  function_name = local.name

  s3_bucket         = data.aws_s3_bucket.default.id
  s3_key            = aws_s3_bucket_object.default[0].id
  s3_object_version = aws_s3_bucket_object.default[0].version_id
  # TODO: see if we can preserve any s3_object_version changes if other things change

  # handler needs to change based on runtime
  handler = var.lambda_handler
  runtime = var.lambda_runtime
  timeout = 15
  publish = true

  role = aws_iam_role.default[0].arn

  depends_on = [
    aws_iam_role_policy_attachment.default,
    aws_cloudwatch_log_group.default,
  ]

  tags   = local.tags
  layers = []

  lifecycle {
    ignore_changes = [
      s3_object_version,
      last_modified,
      source_code_hash,
      version,
    ]
  }
}

resource "aws_cloudwatch_event_rule" "default" {
  count = local.count

  name = "lambda-${local.name}-cron"

  #https://docs.aws.amazon.com/AmazonCloudWatch/latest/events/ScheduledEvents.html
  schedule_expression = var.schedule_expression
  description         = "${local.name} lambda schedule"
  is_enabled          = true
  tags                = local.tags
  # TODO: look into event_bus_name
  # TODO: look into role_arn
}

resource "aws_lambda_alias" "default" {
  for_each = local.enabled ? var.branches : []

  name             = each.key
  description      = "owner/repo:sha (placeholder)"
  function_name    = aws_lambda_function.default[0].arn
  function_version = aws_lambda_function.default[0].version

  # NOTE: you can add a routing_config here to partially roll out
  # the new lambda
  lifecycle {
    ignore_changes = [
      description,
      function_version
    ]
  }
}

resource "aws_cloudwatch_event_target" "cron_lambda_alias" {
  count = local.count

  rule      = aws_cloudwatch_event_rule.default[0].name
  target_id = "lambda-${local.name}-cron"
  arn       = aws_lambda_alias.default[local.main_branch].arn
  input     = var.lambda_input
  # TODO: look into event_bus_name
  # TODO: look into retry_policy
}

resource "aws_lambda_permission" "default" {
  # TODO: we can potentially think about cron for all aliases
  #for_each = local.enabled ? toset(["prod", "beta"]) : []
  for_each = local.enabled ? toset([local.main_branch]) : []

  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.default[0].arn
  qualifier     = aws_lambda_alias.default[each.key].name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.default[0].arn
}

resource "github_actions_secret" "github_aws_id" {
  count = local.count

  repository      = "lambda-collection"
  secret_name     = "lambda_${local.lo_name}_aws_id" # names will end up being uppercase in github
  plaintext_value = aws_iam_access_key.github[0].id
}

resource "github_actions_secret" "github_aws_secret" {
  count = local.count

  repository      = "lambda-collection"
  secret_name     = "lambda_${local.lo_name}_aws_secret" # names will end up being uppercase in github
  plaintext_value = aws_iam_access_key.github[0].secret
}

resource "github_actions_secret" "github_aws_region" {
  count = local.count

  repository      = "lambda-collection"
  secret_name     = "lambda_${local.lo_name}_aws_region" # names will end up being uppercase in github
  plaintext_value = data.aws_s3_bucket.default.region
}

resource "github_actions_secret" "github_s3_location" {
  count = local.count

  repository      = "lambda-collection"
  secret_name     = "lambda_${local.lo_name}_s3_bucket" # names will end up being uppercase in github
  plaintext_value = data.aws_s3_bucket.default.id
}

resource "github_actions_secret" "github_s3_key" {
  count = local.count

  repository      = "lambda-collection"
  secret_name     = "lambda_${local.lo_name}_s3_key" # names will end up being uppercase in github
  plaintext_value = aws_s3_bucket_object.default[0].key
}

output "s3" {
  value = {
    url = "s3://${data.aws_s3_bucket.default.id}/${join("", aws_s3_bucket_object.default[*].key)}"
  }
}

output "lambda" {
  value = {
    arn = join("", aws_lambda_function.default[*].arn)
  }
}
