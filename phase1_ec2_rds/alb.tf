# Application Load Balancer
resource "aws_lb" "main" {
  name               = "phase1-lupang-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = [for subnet in aws_subnet.public : subnet.id]

  enable_deletion_protection = false
  enable_http2               = true

  tags = {
    Name        = "Lupang Application Load Balancer"
    Environment = "Phase1"
  }
}

# Target Group for App Servers
resource "aws_lb_target_group" "app" {
  name     = "phase1-lupang-app-tg"
  port     = 80  # nginx 기본 포트
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200,301,302"  # nginx 기본 페이지 응답 코드 포함
  }

  deregistration_delay = 30

  tags = {
    Name        = "App Server Target Group"
    Environment = "Phase1"
  }
}

# HTTP Listener
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }

  tags = {
    Name        = "HTTP Listener"
    Environment = "Phase1"
  }
}

# ============================================================
#  Auto Scaling
# ============================================================

# Launch Template
resource "aws_launch_template" "app" {
  name_prefix   = "phase1-app-lt-"
  image_id      = data.aws_ami.amazon_linux_2.id
  instance_type = "t2.micro"
  key_name      = aws_key_pair.main.key_name

  # 중요: user_data를 base64encode로 인코딩
  user_data = base64encode(<<-EOF
    #!/bin/bash
    # 로그 파일 설정
    exec > >(tee /var/log/user-data.log)
    exec 2>&1

    echo "Starting user-data script at $(date)"

    # 시스템 업데이트
    yum update -y

    # Node.js 18 설치
    curl -sL https://rpm.nodesource.com/setup_18.x | bash -
    yum install -y nodejs

    # Nginx 설치 및 시작
    amazon-linux-extras install nginx1 -y
    systemctl enable nginx
    systemctl start nginx

    # MySQL 클라이언트 설치
    yum install -y mysql

    # Git 설치
    yum install -y git

    # 간단한 헬스체크 페이지 생성 (nginx 기본 페이지 사용)
    echo "Healthy" > /usr/share/nginx/html/health.html

    echo "User-data script completed at $(date)"
  EOF
  )

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [aws_security_group.app.id]
    delete_on_termination       = true
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name        = "App-ASG-Instance"
      Environment = "Phase1"
      ManagedBy   = "AutoScaling"
    }
  }

  # Latest 버전 자동 업데이트
  update_default_version = true

  tags = {
    Name        = "App Launch Template"
    Environment = "Phase1"
  }
}

# Auto Scaling Group
resource "aws_autoscaling_group" "app" {
  name                = "phase1-app-asg"
  max_size            = 4
  min_size            = 2
  desired_capacity    = 2
  vpc_zone_identifier = [for subnet in aws_subnet.private : subnet.id]

  # 헬스체크 설정 - ELB 사용 권장
  health_check_type         = "ELB"  # EC2 대신 ELB 사용
  health_check_grace_period = 300    # 5분으로 증가 (앱 시작 시간 고려)

  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }

  target_group_arns = [
    aws_lb_target_group.app.arn
  ]

  # 인스턴스 교체 정책
  termination_policies = ["OldestInstance"]

  # 가용 영역 균등 분산
  enabled_metrics = [
    "GroupMinSize",
    "GroupMaxSize",
    "GroupDesiredCapacity",
    "GroupInServiceInstances",
    "GroupTotalInstances"
  ]

  tag {
    key                 = "Name"
    value               = "App-ASG-Instance"
    propagate_at_launch = true
  }

  tag {
    key                 = "Environment"
    value               = "Phase1"
    propagate_at_launch = true
  }

  tag {
    key                 = "ManagedBy"
    value               = "AutoScaling"
    propagate_at_launch = true
  }

  # 라이프사이클 훅 (선택사항)
  lifecycle {
    create_before_destroy = true
  }
}

# Auto Scaling Policy - Target Tracking (CPU 기반)
resource "aws_autoscaling_policy" "cpu_target" {
  name                   = "cpu-target-tracking"
  autoscaling_group_name = aws_autoscaling_group.app.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 70.0  # CPU 70% 유지
  }
}

# Auto Scaling Policy - Target Tracking (ALB Request Count)
resource "aws_autoscaling_policy" "alb_request_count" {
  name                   = "alb-request-count-target"
  autoscaling_group_name = aws_autoscaling_group.app.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ALBRequestCountPerTarget"
      resource_label         = "${aws_lb.main.arn_suffix}/${aws_lb_target_group.app.arn_suffix}"
    }
    target_value = 1000.0  # 타겟당 1000 요청/분
  }
}
