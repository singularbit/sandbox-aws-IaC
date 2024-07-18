provider "aws" {
  region = "eu-west-1"
}

# IAM Role for Lambda
resource "aws_iam_role" "lambda_execution_role" {
  name = "lambda_execution_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "lambda_policy" {
  name   = "lambda_policy"
  role   = aws_iam_role.lambda_execution_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

# Lambda Function
resource "aws_lambda_function" "my_lambda_function" {
  function_name = "MyLambdaFunction"
  role          = aws_iam_role.lambda_execution_role.arn
  handler       = "index.handler"
  runtime       = "nodejs14.x"

  source_code_hash = filebase64sha256("lambda.zip")
  filename         = "lambda.zip"

  environment {
    variables = {
      foo = "bar"
    }
  }
}

# API Gateway
resource "aws_api_gateway_rest_api" "my_api" {
  name = "MyApi"
}

# API Gateway Resource
resource "aws_api_gateway_resource" "my_api_resource" {
  rest_api_id = aws_api_gateway_rest_api.my_api.id
  parent_id   = aws_api_gateway_rest_api.my_api.root_resource_id
  path_part   = "hello"
}

# API Gateway Method
resource "aws_api_gateway_method" "my_api_method" {
  rest_api_id   = aws_api_gateway_rest_api.my_api.id
  resource_id   = aws_api_gateway_resource.my_api_resource.id
  http_method   = "GET"
  authorization = "NONE"
}

# API Gateway Integration
resource "aws_api_gateway_integration" "my_api_integration" {
  rest_api_id             = aws_api_gateway_method.my_api_method.rest_api_id
  resource_id             = aws_api_gateway_method.my_api_method.resource_id
  http_method             = aws_api_gateway_method.my_api_method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.my_lambda_function.invoke_arn
}

# API Gateway Deployment
resource "aws_api_gateway_deployment" "my_api_deployment" {
  depends_on = [
    aws_api_gateway_integration.my_api_integration
  ]
  rest_api_id = aws_api_gateway_rest_api.my_api.id
  stage_name  = "prod"
}

# Lambda Permission
resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.my_lambda_function.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.my_api.execution_arn}/*/*"
}
