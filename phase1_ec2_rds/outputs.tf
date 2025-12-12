# VPC Outputs
output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "Public Subnet IDs"
  value       = { for k, v in aws_subnet.public : k => v.id }
}

output "private_subnet_ids" {
  description = "Private Subnet IDs"
  value       = { for k, v in aws_subnet.private : k => v.id }
}

# Compute Outputs
output "bastion_public_ip" {
  description = "Bastion Host Public IP"
  value       = aws_instance.bastion.public_ip
}

output "bastion_private_ip" {
  description = "Bastion Host Private IP"
  value       = aws_instance.bastion.private_ip
}

output "asg_name" {
  description = "Auto Scaling Group Name"
  value       = aws_autoscaling_group.app.name
}

output "asg_desired_capacity" {
  description = "Auto Scaling Group Desired Capacity"
  value       = aws_autoscaling_group.app.desired_capacity
}

output "ssh_private_key_path" {
  description = "Path to SSH Private Key"
  value       = local_file.private_key.filename
}

# ALB Outputs
output "alb_dns_name" {
  description = "Application Load Balancer DNS Name"
  value       = aws_lb.main.dns_name
}

output "alb_zone_id" {
  description = "Application Load Balancer Zone ID"
  value       = aws_lb.main.zone_id
}

output "alb_url" {
  description = "Application Load Balancer URL"
  value       = "http://${aws_lb.main.dns_name}"
}

# RDS Outputs
output "rds_primary_endpoint" {
  description = "RDS Primary Instance Endpoint"
  value       = aws_db_instance.primary.endpoint
}

output "rds_primary_address" {
  description = "RDS Primary Instance Address"
  value       = aws_db_instance.primary.address
}

output "rds_replica_endpoint" {
  description = "RDS Read Replica Endpoint"
  value       = aws_db_instance.replica.endpoint
}

output "rds_replica_address" {
  description = "RDS Read Replica Address"
  value       = aws_db_instance.replica.address
}

output "rds_database_name" {
  description = "RDS Database Name"
  value       = aws_db_instance.primary.db_name
}

# S3 Outputs
output "s3_images_bucket_name" {
  description = "S3 Images Bucket Name"
  value       = aws_s3_bucket.images.id
}

output "s3_images_bucket_arn" {
  description = "S3 Images Bucket ARN"
  value       = aws_s3_bucket.images.arn
}

output "s3_images_bucket_domain" {
  description = "S3 Images Bucket Domain Name"
  value       = aws_s3_bucket.images.bucket_regional_domain_name
}

# Connection Instructions
output "connection_instructions" {
  description = "How to connect to instances"
  sensitive   = true
  value       = <<-EOT
    ====================================
    Phase 1 Infrastructure Connection Guide
    ====================================

    1. SSH to Bastion Host:
       ssh -i ${local_file.private_key.filename} ec2-user@${aws_instance.bastion.public_ip}

    2. View Auto Scaling Group instances:
       aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names ${aws_autoscaling_group.app.name}

    3. SSH to ASG instances (from Bastion):
       # Get instance IPs first, then SSH to them
       ssh ec2-user@<ASG_INSTANCE_PRIVATE_IP>

    4. Access Application:
       http://${aws_lb.main.dns_name}

    5. MySQL Connection from App Servers:
       Primary (Write): mysql -h ${aws_db_instance.primary.address} -u ${var.db_username} -p
       Replica (Read):  mysql -h ${aws_db_instance.replica.address} -u ${var.db_username} -p

    6. S3 Images Bucket:
       Bucket: ${aws_s3_bucket.images.id}
       Public URL: https://${aws_s3_bucket.images.bucket_regional_domain_name}/your-image.jpg

    ====================================
  EOT
}
