# Serverless Architecture Outputs

# CloudFront Distribution URL
output "cloudfront_url" {
  description = "CloudFront Distribution URL for Frontend"
  value       = "https://${aws_cloudfront_distribution.frontend.domain_name}"
}

# API Gateway URLs
output "api_gateway_url" {
  description = "API Gateway Base URL"
  value       = aws_apigatewayv2_api.main.api_endpoint
}

output "signup_api_url" {
  description = "Signup API Endpoint"
  value       = "${aws_apigatewayv2_api.main.api_endpoint}/signup"
}

output "login_api_url" {
  description = "Login API Endpoint"
  value       = "${aws_apigatewayv2_api.main.api_endpoint}/login"
}

output "create_order_api_url" {
  description = "Create Order API Endpoint"
  value       = "${aws_apigatewayv2_api.main.api_endpoint}/orders"
}

# S3 Buckets
output "frontend_s3_bucket" {
  description = "Frontend S3 Bucket Name"
  value       = aws_s3_bucket.frontend.id
}

output "app_s3_bucket" {
  description = "App Storage S3 Bucket Name"
  value       = aws_s3_bucket.app_bucket.id
}

# Lambda Functions
output "lambda_functions" {
  description = "Lambda Function Names"
  value = {
    signup       = aws_lambda_function.signup.function_name
    login        = aws_lambda_function.login.function_name
    create_order = aws_lambda_function.create_order.function_name
  }
}

# Deployment Instructions
output "deployment_instructions" {
  description = "Next Steps for Deployment"
  value       = <<-EOT

  ========================================
  Serverless Deployment Complete!
  ========================================

  1. Install Lambda Dependencies:
     cd lambda_functions/signup && npm install @aws-sdk/client-dynamodb @aws-sdk/lib-dynamodb
     cd ../login && npm install @aws-sdk/client-dynamodb @aws-sdk/lib-dynamodb
     cd ../create_order && npm install @aws-sdk/client-dynamodb @aws-sdk/lib-dynamodb

  2. Upload Frontend Files to S3:
     aws s3 sync ./frontend s3://${aws_s3_bucket.frontend.id}/

  3. Update HTML files with new API URLs:
     - Signup API: ${aws_apigatewayv2_api.main.api_endpoint}/signup
     - Login API: ${aws_apigatewayv2_api.main.api_endpoint}/login
     - Create Order API: ${aws_apigatewayv2_api.main.api_endpoint}/orders

  4. Access your application:
     Frontend: https://${aws_cloudfront_distribution.frontend.domain_name}

  ========================================
  EOT
}
