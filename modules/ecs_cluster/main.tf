resource "aws_ecs_cluster" "main" {
  name = "main-ecs-cluster"
}

data "aws_ami" "ecs_optimized" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["amzn2-ami-ecs-hvm-*-x86_64-ebs"]
  }
}

resource "aws_launch_template" "client_nodes" {
  name_prefix   = "client-ecs-node-"
  image_id      = data.aws_ami.ecs_optimized.id
  instance_type = "t3.medium"

  # todo: add IAM when configured
  # iam_instance_profile {
  #   name = aws_iam_instance_profile.ecs_instance.name
  # }

  user_data = filebase64("${path.module}/register-ecs-node.sh")

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

  user_data = filebase64("${path.module}/register-ecs-node.sh")

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
  cpu                      = "256"
  memory                   = "512"

  container_definitions = jsonencode([
    {
      name = "client"
      # todo: replace with actual client image when ready
      # image     = "123456789012.dkr.ecr.us-west-2.amazonaws.com/client:latest"
      image     = "amazonlinux:2"
      essential = true
      portMappings = [
        {
          containerPort = 8080
          hostPort      = 8080
          protocol      = "tcp"
        }
      ]
      # todo: add log configuration to connect to cloudwatch
      # logConfiguration = {
      #   logDriver = "awslogs"
      #   options = {
      #     awslogs-group         = "/ecs/client"
      #     awslogs-region        = var.region
      #     awslogs-stream-prefix = "ecs"
      #   }
      # }
    }
  ])
}

resource "aws_ecs_task_definition" "account" {
  family                   = "account-task"
  network_mode             = "bridge"
  requires_compatibilities = ["EC2"]
  cpu                      = "256"
  memory                   = "512"

  container_definitions = jsonencode([
    {
      name = "account"
      # todo: replace with actual client image when ready
      # image     = "123456789012.dkr.ecr.us-west-2.amazonaws.com/account:latest"
      image     = "amazonlinux:2"
      essential = true
      portMappings = [
        {
          containerPort = 8080
          hostPort      = 8080
          protocol      = "tcp"
        }
      ]
      # todo: add log configuration to connect to cloudwatch
      # logConfiguration = {
      #   logDriver = "awslogs"
      #   options = {
      #     awslogs-group         = "/ecs/account"
      #     awslogs-region        = var.region
      #     awslogs-stream-prefix = "ecs"
      #   }
      # }
    }
  ])
}

resource "aws_ecs_service" "client" {
  name            = "client-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.client.arn
  desired_count   = 2
  launch_type     = "EC2"

  load_balancer {
    target_group_arn = var.client_alb_target_group_arn
    container_name   = "client"
    container_port   = 8080
  }
}

resource "aws_ecs_service" "account" {
  name            = "account-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.account.arn
  desired_count   = 2
  launch_type     = "EC2"

  load_balancer {
    target_group_arn = var.account_alb_target_group_arn
    container_name   = "account"
    container_port   = 8080
  }

}


