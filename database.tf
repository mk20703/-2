# LupangUsers 테이블
resource "aws_dynamodb_table" "lupang_users" {
  name         = "LupangUsers"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "userId"
  range_key    = "CreatedAt"

  attribute {
    name = "userId"
    type = "S"
  }

  attribute {
    name = "CreatedAt"
    type = "S"
  }

  tags = { Name = "LupangUsers Table" }
}

# LupangOrders 테이블
resource "aws_dynamodb_table" "lupang_orders" {
  name         = "LupangOrders"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "userId"
  range_key    = "orderId"

  attribute {
    name = "userId"
    type = "S"
  }

  attribute {
    name = "orderId"
    type = "S"
  }

  tags = { Name = "LupangOrders Table" }
}
