#============ Eventbridge Rules ============#
resource "aws_cloudwatch_event_rule" "sns_event_rule" {
  name          = "rule-sns-topics"
  description   = "Triggers Lambda when new sns topics are created"
  event_pattern = <<EOF
    {
    "source": ["aws.sns"],
    "detail-type": ["AWS API Call via CloudTrail"],
    "detail": {
        "eventSource" : ["sns.amazonaws.com"],
        "eventName": ["CreateTopic"]
    }
    }
  EOF
}

#============ Eventbridge Targets ============
resource "aws_cloudwatch_event_target" "lambda" {
  rule       = aws_cloudwatch_event_rule.sns_event_rule.id
  target_id  = "SendToLambda"
  arn        = aws_lambda_function.autotag.arn
  depends_on = [aws_lambda_function.autotag]
}

resource "aws_lambda_permission" "event_brige_rule" {
  statement_id  = "AllowExecutionFromEventBridgeRule"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.autotag.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.sns_event_rule.arn
  depends_on = [
    aws_lambda_function.autotag,
    aws_cloudwatch_event_rule.sns_event_rule
  ]
}

