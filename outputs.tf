output "vpc_id" { value = aws_vpc.main.id }
output "unicorn_ip" { value = aws_instance.web_a.public_ip }
output "jenkins_ip" { value = aws_instance.jenkins.public_ip }

# 접속 명령어 안내 (자동 생성된 key.pem 사용)
output "connect_unicorn" { 
  value = "ssh -i key.pem ubuntu@${aws_instance.web_a.public_ip}" 
}
