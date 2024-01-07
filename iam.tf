#======================== Lambda IAM Role and Policy ========================#
data "aws_iam_policy_document" "lambda_assume_role_policy" {
  statement {
    sid    = "LambdaAssumeRole"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }

  statement {
    sid    = "CloudwatchAssumeRole"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["cloudwatch.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }

  statement {
    sid    = "CloudtrailAssumeRole"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }

  statement {
    sid    = "EventsAssumeRole"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }

  statement {
    sid    = "S3AssumeRole"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["s3.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "lambda_exec_role" {
  name               = "lambda-autotag"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role_policy.json
  inline_policy {
    name   = "AutotagFunctionPermissions"
    policy = data.aws_iam_policy_document.lambda_inline_policy.json
  }
}

data "aws_iam_policy_document" "lambda_inline_policy" {
  statement {
    sid    = "AllowTaggingOfSNSTopic"
    effect = "Allow"
    actions = [
      "SNS:TagResource",
      "iam:ListRoleTags",
      "iam:ListUserTags"
    ]
    resources = ["*"]
  }
  statement {
    sid       = "AllowLambdaCreateLogGroup"
    effect    = "Allow"
    actions   = ["logs:CreateLogGroup"]
    resources = ["arn:aws:logs:${var.aws_region}:*:log-group:*"]
  }
  statement {
    sid    = "AllowLambdaCreateLogStreamsAndWriteEventLogs"
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = ["${aws_cloudwatch_log_group.lambda_log_grp.arn}:*"]
  }
}

#======================== Cloudtrail Bucket Policy ========================#
data "aws_iam_policy_document" "cloudtrail_bucket_policy_doc" {
  count = var.create_trail ? 1 : 0

  statement {
    sid    = "AllowCloudTrailCheckBucketAcl"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    actions   = ["s3:GetBucketAcl"]
    resources = [aws_s3_bucket.cloudtrail_bucket[count.index].arn]
  }

  statement {
    sid    = "AllowCloudTrailWriteLogs"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.cloudtrail_bucket[count.index].arn}/AWSLogs/*"]
  }
}
