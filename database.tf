resource "aws_dynamodb_table" "dynamo_db" {
  name         = "LupangUsers"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "UserId"
  attribute {
    name = "UserId"
    type = "S"
  }
  tags = { Name = "DynamoDB Table" }
}
