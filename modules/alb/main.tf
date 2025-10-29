resource "aws_lb" "main" {
  name               = "main-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = var.assigned_sg_ids
  subnets            = var.public_subnet_ids

  enable_deletion_protection = false

  tags = {
    Name = "main-alb"
  }
}

resource "aws_lb_target_group" "client" {
  name                 = "tg-client"
  port                 = 8080
  protocol             = "HTTP"
  vpc_id               = var.vpc_id
  target_type          = "instance"
  deregistration_delay = 30

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 10
    timeout             = 10
    interval            = 30
    path                = "/actuator/health"
    matcher             = "200"
  }
}

resource "aws_lb_target_group" "account" {
  name     = "tg-account"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  target_type          = "instance"
  deregistration_delay = 30

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 10
    timeout             = 10
    interval            = 30
    path                = "/actuator/health"
    matcher             = "200"
  }
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80     #todo : update port to 443
  protocol          = "HTTP" #todo: update protocol to HTTPS
  # ssl_policy        = "ELBSecurityPolicy-2023-01"
  # certificate_arn   = var.acm_certificate_arn #todo: pass in the ACM ARN

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "Not Found"
      status_code  = "404"
    }
  }
}

resource "aws_lb_listener_rule" "client_rule" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 10

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.client.arn
  }

  condition {
    path_pattern {
      values = [
        "/client-profile/*",
        "/client-profile"
      ]
    }
  }
}

resource "aws_lb_listener_rule" "account_rule" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 20

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.account.arn
  }

  condition {
    path_pattern {
      values = [
        "/account/*",
        "/account"
      ]
    }
  }
}


