output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "bastion_public_ip" {
  description = "Bastion Server Public IP"
  value       = aws_instance.bastion.public_ip
}

output "jenkins_private_ip" {
  description = "Jenkins Server Private IP"
  value       = aws_instance.jenkins.private_ip
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

output "dynamodb_users_table" {
  description = "DynamoDB LupangUsers Table Name"
  value       = aws_dynamodb_table.lupang_users.name
}

output "dynamodb_orders_table" {
  description = "DynamoDB LupangOrders Table Name"
  value       = aws_dynamodb_table.lupang_orders.name
}

# SSH 접속 명령어
output "connect_bastion" {
  description = "SSH command to connect to Bastion"
  value       = "ssh -i key.pem ubuntu@${aws_instance.bastion.public_ip}"
}

output "connect_jenkins" {
  description = "SSH command to connect to Jenkins via Bastion"
  value       = "ssh -i key.pem -J ubuntu@${aws_instance.bastion.public_ip} ubuntu@${aws_instance.jenkins.private_ip}"
}

# 웹 접속 URL
output "jenkins_url" {
  description = "Jenkins Web UI URL (accessible via Bastion port forwarding)"
  value       = "http://localhost:8080 (use: ssh -i key.pem -L 8080:${aws_instance.jenkins.private_ip}:8080 ubuntu@${aws_instance.bastion.public_ip})"
}

output "app_url" {
  description = "Application URL via ALB"
  value       = "http://${aws_lb.app_alb.dns_name}"
}
