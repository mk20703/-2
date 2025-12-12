# SSH Key Pair
resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "main" {
  key_name   = "phase1-lupang-key"
  public_key = tls_private_key.ssh_key.public_key_openssh

  tags = {
    Name        = "Phase1 Lupang Key Pair"
    Environment = "Phase1"
  }
}

resource "local_file" "private_key" {
  content         = tls_private_key.ssh_key.private_key_pem
  filename        = "${path.module}/lupang-key.pem"
  file_permission = "0400"
}

# Data source for latest Amazon Linux 2 AMI
data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Bastion Host (Public Subnet)
resource "aws_instance" "bastion" {
  ami                         = data.aws_ami.amazon_linux_2.id
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.public["ap-northeast-2a"].id
  vpc_security_group_ids      = [aws_security_group.bastion.id]
  key_name                    = aws_key_pair.main.key_name
  associate_public_ip_address = true

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y telnet nc
              EOF

  tags = {
    Name        = "Bastion Host"
    Environment = "Phase1"
  }
}

# App Server 1 (Private Subnet AZ-A)
resource "aws_instance" "app_1" {
  ami                    = data.aws_ami.amazon_linux_2.id
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.private["ap-northeast-2a"].id
  vpc_security_group_ids = [aws_security_group.app.id]
  key_name               = aws_key_pair.main.key_name

  user_data = <<-EOF
              #!/bin/bash
              # Update system
              yum update -y

              # Install Node.js 18
              curl -sL https://rpm.nodesource.com/setup_18.x | bash -
              yum install -y nodejs

              # Install nginx
              amazon-linux-extras install nginx1 -y
              systemctl enable nginx
              systemctl start nginx

              # Install MySQL client
              yum install -y mysql

              # Install Git
              yum install -y git
              EOF

  tags = {
    Name        = "App Server 1"
    Environment = "Phase1"
    AZ          = "ap-northeast-2a"
  }
}

# App Server 2 (Private Subnet AZ-C)
resource "aws_instance" "app_2" {
  ami                    = data.aws_ami.amazon_linux_2.id
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.private["ap-northeast-2c"].id
  vpc_security_group_ids = [aws_security_group.app.id]
  key_name               = aws_key_pair.main.key_name

  user_data = <<-EOF
              #!/bin/bash
              # Update system
              yum update -y

              # Install Node.js 18
              curl -sL https://rpm.nodesource.com/setup_18.x | bash -
              yum install -y nodejs

              # Install nginx
              amazon-linux-extras install nginx1 -y
              systemctl enable nginx
              systemctl start nginx

              # Install MySQL client
              yum install -y mysql

              # Install Git
              yum install -y git
              EOF

  tags = {
    Name        = "App Server 2"
    Environment = "Phase1"
    AZ          = "ap-northeast-2c"
  }
}
