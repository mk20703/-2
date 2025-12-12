# Lambda IAM Role
resource "aws_iam_role" "lambda_role" {
  name = "lupang-lambda-role"

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

  tags = { Name = "Lupang Lambda Role" }
}

# Lambda Policy for DynamoDB and CloudWatch Logs
resource "aws_iam_role_policy" "lambda_policy" {
  name = "lupang-lambda-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ]
        Resource = [
          aws_dynamodb_table.lupang_users.arn,
          aws_dynamodb_table.lupang_orders.arn
        ]
      },
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

# Package Lambda functions (need to install dependencies first)
data "archive_file" "signup_lambda" {
  type        = "zip"
  source_dir  = "${path.module}/lambda_functions/signup"
  output_path = "${path.module}/lambda_functions/signup.zip"
}

data "archive_file" "login_lambda" {
  type        = "zip"
  source_dir  = "${path.module}/lambda_functions/login"
  output_path = "${path.module}/lambda_functions/login.zip"
}

data "archive_file" "create_order_lambda" {
  type        = "zip"
  source_dir  = "${path.module}/lambda_functions/create_order"
  output_path = "${path.module}/lambda_functions/create_order.zip"
}

# Lambda Functions
resource "aws_lambda_function" "signup" {
  filename         = data.archive_file.signup_lambda.output_path
  function_name    = "LupangSignupFunction"
  role            = aws_iam_role.lambda_role.arn
  handler         = "index.handler"
  source_code_hash = data.archive_file.signup_lambda.output_base64sha256
  runtime         = "nodejs18.x"
  timeout         = 30

  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.lupang_users.name
    }
  }

  tags = { Name = "Lupang Signup Function" }
}

resource "aws_lambda_function" "login" {
  filename         = data.archive_file.login_lambda.output_path
  function_name    = "LupangLoginFunction"
  role            = aws_iam_role.lambda_role.arn
  handler         = "index.handler"
  source_code_hash = data.archive_file.login_lambda.output_base64sha256
  runtime         = "nodejs18.x"
  timeout         = 30

  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.lupang_users.name
    }
  }

  tags = { Name = "Lupang Login Function" }
}

resource "aws_lambda_function" "create_order" {
  filename         = data.archive_file.create_order_lambda.output_path
  function_name    = "LupangCreateOrderFunction"
  role            = aws_iam_role.lambda_role.arn
  handler         = "index.handler"
  source_code_hash = data.archive_file.create_order_lambda.output_base64sha256
  runtime         = "nodejs18.x"
  timeout         = 30

  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.lupang_orders.name
    }
  }

  tags = { Name = "Lupang Create Order Function" }
}

# Lambda Permissions for API Gateway
resource "aws_lambda_permission" "signup_api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.signup.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.main.execution_arn}/*/*"
}

resource "aws_lambda_permission" "login_api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.login.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.main.execution_arn}/*/*"
}

resource "aws_lambda_permission" "create_order_api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.create_order.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.main.execution_arn}/*/*"
}
