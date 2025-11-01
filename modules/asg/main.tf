terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
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
    id      = var.client_launch_template_id
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
    id      = var.account_launch_template_id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "account-ecs-node"
    propagate_at_launch = true
  }
}

resource "aws_autoscaling_policy" "client_scale_out" {
  name                   = "client-scale-out"
  autoscaling_group_name  = aws_autoscaling_group.client_nodes.name
  policy_type             = "SimpleScaling"
  adjustment_type         = "ChangeInCapacity"
  scaling_adjustment      = 1
  cooldown                = 300
}

resource "aws_autoscaling_policy" "client_scale_in" {
  name                   = "client-scale-in"
  autoscaling_group_name  = aws_autoscaling_group.client_nodes.name
  policy_type             = "SimpleScaling"
  adjustment_type         = "ChangeInCapacity"
  scaling_adjustment      = -1
  cooldown                = 300
}

resource "aws_autoscaling_policy" "account_scale_out" {
  name                   = "account-scale-out"
  autoscaling_group_name  = aws_autoscaling_group.account_nodes.name
  policy_type             = "SimpleScaling"
  adjustment_type         = "ChangeInCapacity"
  scaling_adjustment      = 1
  cooldown                = 300
}

resource "aws_autoscaling_policy" "account_scale_in" {
  name                   = "account-scale-in"
  autoscaling_group_name  = aws_autoscaling_group.account_nodes.name
  policy_type             = "SimpleScaling"
  adjustment_type         = "ChangeInCapacity"
  scaling_adjustment      = -1
  cooldown                = 300
}


# CloudWatch CPU Utilization Alarms for ASGs - Client
resource "aws_cloudwatch_metric_alarm" "client_cpu_high" {
  alarm_name          = "client-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = 70
  alarm_description   = "Alarm if client ASG CPU > 70%"
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.client_nodes.name
  }
  alarm_actions = [aws_autoscaling_policy.client_scale_out.arn]
}

resource "aws_cloudwatch_metric_alarm" "client_cpu_low" {
  alarm_name          = "client-cpu-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = 30
  alarm_description   = "Alarm if client ASG CPU < 30%"
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.client_nodes.name
  }
  alarm_actions = [aws_autoscaling_policy.client_scale_in.arn]
}

# CloudWatch CPU Utilization Alarms for ASGs - Account
resource "aws_cloudwatch_metric_alarm" "account_cpu_high" {
  alarm_name          = "account-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = 70
  alarm_description   = "Alarm if account ASG CPU > 70%"
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.account_nodes.name
  }
  alarm_actions = [aws_autoscaling_policy.account_scale_out.arn]
}

resource "aws_cloudwatch_metric_alarm" "account_cpu_low" {
  alarm_name          = "account-cpu-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = 30
  alarm_description   = "Alarm if account ASG CPU < 30%"
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.account_nodes.name
  }
  alarm_actions = [aws_autoscaling_policy.account_scale_in.arn]
}

# ECS Service Auto Scaling - Client
resource "aws_appautoscaling_target" "client_service" {
  max_capacity       = 4
  min_capacity       = 1
  resource_id        = "service/${var.client_cluster_name}/${var.client_service_name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "client_scale_out" {
  name               = "client-scale-out"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.client_service.resource_id
  scalable_dimension = aws_appautoscaling_target.client_service.scalable_dimension
  service_namespace  = aws_appautoscaling_target.client_service.service_namespace

  target_tracking_scaling_policy_configuration {
    target_value       = 70
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    scale_in_cooldown  = 60
    scale_out_cooldown = 60
  }
}

resource "aws_appautoscaling_policy" "client_scale_in" {
  name               = "client-scale-in"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.client_service.resource_id
  scalable_dimension = aws_appautoscaling_target.client_service.scalable_dimension
  service_namespace  = aws_appautoscaling_target.client_service.service_namespace

  target_tracking_scaling_policy_configuration {
    target_value       = 30
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    scale_in_cooldown  = 60
    scale_out_cooldown = 60
  }
}

# ECS Service Auto Scaling - Account
resource "aws_appautoscaling_target" "account_service" {
  max_capacity       = 4
  min_capacity       = 1
  resource_id        = "service/${var.account_cluster_name}/${var.account_service_name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "account_scale_out" {
  name               = "account-scale-out"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.account_service.resource_id
  scalable_dimension = aws_appautoscaling_target.account_service.scalable_dimension
  service_namespace  = aws_appautoscaling_target.account_service.service_namespace

  target_tracking_scaling_policy_configuration {
    target_value       = 70
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    scale_in_cooldown  = 60
    scale_out_cooldown = 60
  }
}

resource "aws_appautoscaling_policy" "account_scale_in" {
  name               = "account-scale-in"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.account_service.resource_id
  scalable_dimension = aws_appautoscaling_target.account_service.scalable_dimension
  service_namespace  = aws_appautoscaling_target.account_service.service_namespace

  target_tracking_scaling_policy_configuration {
    target_value       = 30
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    scale_in_cooldown  = 60
    scale_out_cooldown = 60
  }
}
