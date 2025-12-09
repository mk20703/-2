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

# SSH 키 설정 (아까 만든 키 페어 사용)
resource "aws_key_pair" "deployer" {
  key_name   = "mykey"
  public_key = file("~/.ssh/id_rsa.pub")
}

resource "aws_instance" "web_a" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"
  key_name      = aws_key_pair.deployer.key_name
  
  # ✅ 중요: Private -> Public으로 변경 (인터넷 가능하게!)
  subnet_id     = aws_subnet.public["ap-northeast-2a"].id 
  
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  associate_public_ip_address = true
  
  tags = { Name = "Unicorn Web Server" }
}

resource "aws_instance" "jenkins" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"
  key_name      = aws_key_pair.deployer.key_name
  
  # ✅ 중요: Private -> Public으로 변경
  subnet_id     = aws_subnet.public["ap-northeast-2a"].id
  
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  associate_public_ip_address = true
  
  tags = { Name = "Jenkins Server" }
}
