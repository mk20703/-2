output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "bastion_public_ip" {
  description = "Bastion Server Public IP"
  value       = aws_instance.bastion.public_ip
}

output "jenkins_public_ip" {
  description = "Jenkins Server Public IP"
  value       = aws_instance.jenkins.public_ip
}

output "app_server_private_ips" {
  description = "App Server Private IPs"
  value       = { for k, v in aws_instance.app : k => v.private_ip }
}

output "alb_dns_name" {
  description = "Application Load Balancer DNS Name"
  value       = aws_lb.app_alb.dns_name
}

output "s3_bucket_name" {
  description = "S3 Bucket Name"
  value       = aws_s3_bucket.app_bucket.id
}

output "dynamodb_table_name" {
  description = "DynamoDB Table Name"
  value       = aws_dynamodb_table.dynamo_db.name
}

# SSH 접속 명령어
output "connect_bastion" {
  description = "SSH command to connect to Bastion"
  value       = "ssh -i key.pem ubuntu@${aws_instance.bastion.public_ip}"
}

output "connect_jenkins" {
  description = "SSH command to connect to Jenkins"
  value       = "ssh -i key.pem ubuntu@${aws_instance.jenkins.public_ip}"
}

# 웹 접속 URL
output "jenkins_url" {
  description = "Jenkins Web UI URL"
  value       = "http://${aws_instance.jenkins.public_ip}:8080"
}

output "app_url" {
  description = "Application URL via ALB"
  value       = "http://${aws_lb.app_alb.dns_name}"
}
