# Application Load Balancer
resource "aws_lb" "app_alb" {
  name               = "app-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [for subnet in aws_subnet.public : subnet.id]

  enable_deletion_protection = false

  tags = { Name = "App ALB" }
}

# Target Group for App Servers
resource "aws_lb_target_group" "app_tg" {
  name     = "app-target-group"
  port     = 8000
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
  }

  tags = { Name = "App Target Group" }
}

# Register App Instances to Target Group
resource "aws_lb_target_group_attachment" "app_targets" {
  for_each = aws_instance.app

  target_group_arn = aws_lb_target_group.app_tg.arn
  target_id        = each.value.id
  port             = 8000
}

# ALB Listener
resource "aws_lb_listener" "app_listener" {
  load_balancer_arn = aws_lb.app_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_tg.arn
  }

  tags = { Name = "App ALB Listener" }
}
