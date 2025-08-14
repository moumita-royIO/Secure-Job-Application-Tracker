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
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

########################################
# IAM Policy for DynamoDB Access
########################################
resource "aws_iam_role_policy" "lambda_dynamodb_policy" {
  name = "lambda_dynamodb_policy"
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
          "dynamodb:DeleteItem"
        ]
        Resource = aws_dynamodb_table.job_tracker.arn
      }
    ]
  })
}

########################################
# Lambda Function
########################################
resource "aws_lambda_function" "job_tracker_lambda" {
  filename         = "lambda.zip"
  function_name    = "JobTrackerLambda"
  role             = aws_iam_role.lambda_exec_role.arn
  handler          = "index.handler" # index.py → handler() function
  runtime          = "python3.9"

  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.job_tracker.name
    }
  }
}

########################################
# API Gateway
########################################
resource "aws_apigatewayv2_api" "job_tracker_api" {
  name          = "JobTrackerAPI"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id           = aws_apigatewayv2_api.job_tracker_api.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.job_tracker_lambda.invoke_arn
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

########################################
# Lambda Permission for API Gateway
########################################
resource "aws_lambda_permission" "apigw_invoke_lambda" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.job_tracker_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.job_tracker_api.execution_arn}/*/*"
}
