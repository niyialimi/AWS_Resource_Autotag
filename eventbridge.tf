#============ Eventbridge Rules ============#
resource "aws_cloudwatch_event_rule" "resource_creation_rule" {
  name          = "rule-resource-creation"
  description   = "Triggers Lambda when resources are created"
  event_pattern = <<EOF
    {
      "detail-type": ["AWS API Call via CloudTrail"],
      "detail": {
          "eventSource": ["sns.amazonaws.com", "s3.amazonaws.com", "ec2.amazonaws.com", "iam.amazonaws.com"],
          "eventName": [
              "CreateTopic",
              "CreateBucket",
              "RunInstances",
              "CreateRole"
          ]
      }
    }
  EOF
}


#============ Eventbridge Targets ============
resource "aws_cloudwatch_event_target" "lambda" {
  rule       = aws_cloudwatch_event_rule.resource_creation_rule.id
  target_id  = "SendToLambda"
  arn        = aws_lambda_function.autotag.arn
  depends_on = [aws_lambda_function.autotag]
}

resource "aws_lambda_permission" "event_bridge_rule" {
  statement_id  = "AllowExecutionFromEventBridgeRule"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.autotag.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.resource_creation_rule.arn
  depends_on = [
    aws_lambda_function.autotag,
    aws_cloudwatch_event_rule.resource_creation_rule
  ]
}
