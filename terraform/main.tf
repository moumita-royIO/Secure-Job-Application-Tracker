########################################
# AWS Provider
########################################
provider "aws" {
  region = "us-east-1"
}

########################################
# DynamoDB Table
########################################
resource "aws_dynamodb_table" "job_tracker" {
  name           = "JobTracker"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "JobID"

  attribute {
    name = "JobID"
    type = "S"
  }

  tags = {
    Environment = "Dev"
    Project     = "Job Application Tracker"
  }
}

########################################
# IAM Role for Lambda
########################################
resource "aws_iam_role" "lambda_exec_role" {
  name = "lambda_execution_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

########################################
# IAM Policy for DynamoDB + SNS Access + CloudWatch
########################################
resource "aws_iam_role_policy" "lambda_policy" {
  name = "lambda_policy"
  role = aws_iam_role.lambda_exec_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:Scan",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem"
        ]
        Resource = aws_dynamodb_table.job_tracker.arn
      },
      {
        Effect = "Allow"
        Action = ["sns:Publish"]
        Resource = "*"  # can restrict to your SNS topic ARN manually
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      }
    ]
  })
}

########################################
# Add Job Lambda
########################################
resource "aws_lambda_function" "add_job_lambda" {
  filename      = "add_job_lambda.zip"
  function_name = "AddJobLambda"
  role          = aws_iam_role.lambda_exec_role.arn
  handler       = "add_job_lambda.add_job_handler"
  runtime       = "python3.11"

  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.job_tracker.name
    }
  }
}

########################################
# API Gateway for Add Job Lambda
########################################
resource "aws_apigatewayv2_api" "job_tracker_api" {
  name          = "JobTrackerAPI"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id           = aws_apigatewayv2_api.job_tracker_api.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.add_job_lambda.invoke_arn
}

resource "aws_apigatewayv2_route" "post_jobs" {
  api_id    = aws_apigatewayv2_api.job_tracker_api.id
  route_key = "POST /jobs"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

resource "aws_apigatewayv2_stage" "job_tracker_stage" {
  api_id      = aws_apigatewayv2_api.job_tracker_api.id
  name        = "$default"
  auto_deploy = true
}

resource "aws_lambda_permission" "apigw_invoke_lambda" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.add_job_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.job_tracker_api.execution_arn}/*/*"
}

########################################
# Notification Lambda
########################################
resource "aws_lambda_function" "notify_jobs_lambda" {
  filename      = "notify_jobs_lambda.zip"
  function_name = "NotifyJobsLambda"
  role          = aws_iam_role.lambda_exec_role.arn
  handler       = "notify_jobs_lambda.notify_old_jobs_handler"
  runtime       = "python3.11"

  environment {
    variables = {
      TABLE_NAME    = aws_dynamodb_table.job_tracker.name
      SNS_TOPIC_ARN = "arn:aws:sns:xxx:xxxxx:YourTopicName"  # Replace with the SNS topic ARN
    }
  }
}

########################################
# EventBridge Schedule for Notification Lambda
########################################
resource "aws_cloudwatch_event_rule" "daily_schedule" {
  name                = "DailyJobNotification"
  schedule_expression = "rate(1 day)"
}

resource "aws_cloudwatch_event_target" "notify_lambda_target" {
  rule      = aws_cloudwatch_event_rule.daily_schedule.name
  target_id = "NotifyJobsLambda"
  arn       = aws_lambda_function.notify_jobs_lambda.arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.notify_jobs_lambda.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.daily_schedule.arn
}
