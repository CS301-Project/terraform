data "aws_ami" "ecs_optimized" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["amzn2-ami-ecs-hvm-*-x86_64-ebs"]
  }
}

resource "aws_cloudwatch_log_group" "client" {
  name              = "/ecs/client-task"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_group" "account" {
  name              = "/ecs/account-task"
  retention_in_days = 7
}

resource "aws_ecs_cluster" "client" {
  name = "client-ecs-cluster"
}

resource "aws_ecs_cluster" "account" {
  name = "account-ecs-cluster"
}

resource "aws_launch_template" "client_nodes" {
  name_prefix   = "client-ecs-node-"
  image_id      = data.aws_ami.ecs_optimized.id
  instance_type = "t3.medium"

  # todo: add IAM when configured
  # iam_instance_profile {
  #   name = aws_iam_instance_profile.ecs_instance.name
  # }

  user_data = base64encode(<<-EOF
    #!/bin/bash
    echo "ECS_CLUSTER=client-ecs-cluster" >> /etc/ecs/ecs.config
  EOF
  )
  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [var.client_ecs_sg_id]
  }

  iam_instance_profile {
    name = var.ecs_instance_profile_name
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "client-ecs-node"
    }
  }
}

resource "aws_launch_template" "account_nodes" {
  name_prefix   = "account-ecs-node-"
  image_id      = data.aws_ami.ecs_optimized.id
  instance_type = "t3.medium"

  # todo: add IAM when configured
  # iam_instance_profile {
  #   name = aws_iam_instance_profile.ecs_instance.name
  # }

  user_data = base64encode(<<-EOF
    #!/bin/bash
    echo "ECS_CLUSTER=account-ecs-cluster" >> /etc/ecs/ecs.config
  EOF
  )

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [var.account_ecs_sg_id]
  }

  iam_instance_profile {
    name = var.ecs_instance_profile_name
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "account-ecs-node"
    }
  }
}

resource "aws_autoscaling_group" "client_nodes" {
  name                = "client-ecs-asg"
  min_size            = 2
  max_size            = 4
  desired_capacity    = 2
  vpc_zone_identifier = var.ecs_private_subnet_ids

  launch_template {
    id      = aws_launch_template.client_nodes.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "client-ecs-node"
    propagate_at_launch = true
  }
}

resource "aws_autoscaling_group" "account_nodes" {
  name                = "account-ecs-asg"
  min_size            = 2
  max_size            = 4
  desired_capacity    = 2
  vpc_zone_identifier = var.ecs_private_subnet_ids

  launch_template {
    id      = aws_launch_template.account_nodes.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "account-ecs-node"
    propagate_at_launch = true
  }
}

resource "aws_ecs_task_definition" "client" {
  family                   = "client-task"
  network_mode             = "bridge"
  requires_compatibilities = ["EC2"]
  cpu                      = "512"
  memory                   = "1024"

  task_role_arn      = var.ecs_task_role_client_arn
  execution_role_arn = var.ecs_task_execution_role_arn
  container_definitions = jsonencode([
    {
      name      = "client"
      image     = "${var.client_repository_url}:latest"
      essential = true
      portMappings = [
        {
          containerPort = 8080
          hostPort      = 8080
          protocol      = "tcp"
        }
      ]
      environment = [
        {
          name  = "DB_HOST"
          value = var.client_db_endpoint
        },
        {
          name  = "DB_USERNAME"
          value = var.client_db_username
        },
        {
          name  = "SQS_LOGGING_URL"
          value = var.sqs_logging_url
        }
      ]
      secrets = [
        {
          name      = "DB_PASSWORD"
          valueFrom = "${var.client_db_secret_arn}:password::"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/client-task"
          "awslogs-region"        = "ap-southeast-1"
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])
}

resource "aws_ecs_task_definition" "account" {
  family                   = "account-task"
  network_mode             = "bridge"
  requires_compatibilities = ["EC2"]
  cpu                      = "1024"
  memory                   = "2048"

  execution_role_arn = var.ecs_task_execution_role_arn
  container_definitions = jsonencode([
    {
      name      = "account"
      image     = "${var.account_repository_url}:latest"
      essential = true
      portMappings = [
        {
          containerPort = 8080
          hostPort      = 8080
          protocol      = "tcp"
        }
      ]
      environment = [
        {
          name  = "DB_HOST"
          value = var.account_db_endpoint
        },
        {
          name  = "DB_USERNAME"
          value = var.account_db_username
        },
        {
          name  = "SQS_LOGGING_URL"
          value = var.sqs_logging_url
        }
      ]
      secrets = [
        {
          name      = "DB_PASSWORD"
          valueFrom = "${var.account_db_secret_arn}:password::"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/account-task"
          "awslogs-region"        = "ap-southeast-1"
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])
}

resource "aws_ecs_service" "client" {
  name                              = "client-service"
  cluster                           = aws_ecs_cluster.client.id
  task_definition                   = aws_ecs_task_definition.client.arn
  desired_count                     = 2
  launch_type                       = "EC2"
  health_check_grace_period_seconds = 200
  load_balancer {
    target_group_arn = var.client_alb_target_group_arn
    container_name   = "client"
    container_port   = 8080
  }
}

resource "aws_ecs_service" "account" {
  name                              = "account-service"
  cluster                           = aws_ecs_cluster.account.id
  task_definition                   = aws_ecs_task_definition.account.arn
  desired_count                     = 2
  launch_type                       = "EC2"
  health_check_grace_period_seconds = 200
  load_balancer {
    target_group_arn = var.account_alb_target_group_arn
    container_name   = "account"
    container_port   = 8080
  }
}

