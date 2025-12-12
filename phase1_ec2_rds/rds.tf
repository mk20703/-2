# DB Subnet Group
resource "aws_db_subnet_group" "main" {
  name       = "phase1-lupang-db-subnet-group"
  subnet_ids = [for subnet in aws_subnet.private : subnet.id]

  tags = {
    Name        = "Lupang DB Subnet Group"
    Environment = "Phase1"
  }
}

# Primary RDS MySQL Instance
resource "aws_db_instance" "primary" {
  identifier     = "phase1-lupang-primary"
  engine         = "mysql"
  engine_version = "8.0"
  instance_class = "db.t3.micro"

  allocated_storage     = 20
  max_allocated_storage = 100
  storage_type          = "gp3"
  storage_encrypted     = true

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  multi_az               = false
  availability_zone      = "ap-northeast-2a"
  publicly_accessible    = false
  backup_retention_period = 7
  backup_window          = "03:00-04:00"
  maintenance_window     = "mon:04:00-mon:05:00"

  enabled_cloudwatch_logs_exports = ["error", "general", "slowquery"]

  skip_final_snapshot       = true
  final_snapshot_identifier = "phase1-lupang-primary-final-snapshot"
  deletion_protection       = false

  parameter_group_name = aws_db_parameter_group.mysql.name

  tags = {
    Name        = "Lupang Primary Database"
    Environment = "Phase1"
    Type        = "Primary"
  }
}

# Read Replica RDS MySQL Instance
resource "aws_db_instance" "replica" {
  identifier     = "phase1-lupang-replica"
  instance_class = "db.t3.micro"

  replicate_source_db = aws_db_instance.primary.identifier

  availability_zone   = "ap-northeast-2c"
  publicly_accessible = false

  backup_retention_period = 0

  enabled_cloudwatch_logs_exports = ["error", "general", "slowquery"]

  skip_final_snapshot       = true
  final_snapshot_identifier = "phase1-lupang-replica-final-snapshot"
  deletion_protection       = false

  tags = {
    Name        = "Lupang Read Replica"
    Environment = "Phase1"
    Type        = "Replica"
  }

  depends_on = [aws_db_instance.primary]
}

# DB Parameter Group
resource "aws_db_parameter_group" "mysql" {
  name   = "phase1-lupang-mysql-params"
  family = "mysql8.0"

  parameter {
    name  = "character_set_server"
    value = "utf8mb4"
  }

  parameter {
    name  = "collation_server"
    value = "utf8mb4_unicode_ci"
  }

  parameter {
    name  = "max_connections"
    value = "100"
  }

  tags = {
    Name        = "Lupang MySQL Parameters"
    Environment = "Phase1"
  }
}
