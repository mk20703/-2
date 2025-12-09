# 1. 최신 우분투 이미지 찾기
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# 2. 테라폼이 직접 키 생성 (SSH-Keygen 대체)
resource "tls_private_key" "pk" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# 3. AWS에 공개키 등록
resource "aws_key_pair" "deployer" {
  key_name   = "my-deploy-key"
  public_key = tls_private_key.pk.public_key_openssh
}

# 4. 내 컴퓨터에 개인키 파일로 저장 (접속용)
resource "local_file" "ssh_key" {
  filename = "${path.module}/key.pem"
  content  = tls_private_key.pk.private_key_pem
}

# 5. EC2 생성 (Public Subnet)
resource "aws_instance" "web_a" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"
  key_name      = aws_key_pair.deployer.key_name
  subnet_id     = aws_subnet.public["ap-northeast-2a"].id 
  
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  associate_public_ip_address = true
  
  tags = { Name = "Unicorn Web Server" }
}

resource "aws_instance" "jenkins" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"
  key_name      = aws_key_pair.deployer.key_name
  subnet_id     = aws_subnet.public["ap-northeast-2a"].id
  
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  associate_public_ip_address = true
  
  tags = { Name = "Jenkins Server" }
}
