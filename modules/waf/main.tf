terraform { required_version = ">= 1.5" }

terraform {
  required_version = ">= 1.0"
}

resource "aws_wafv2_web_acl" "this" {
  name        = var.name
  description = "WAF for CloudFront"
  scope       = "CLOUDFRONT" # Use provider alias aws.use1 (us-east-1)

  default_action {
    allow {}
  }

  # --- Managed rule group: Common ---
  rule {
    name     = "AWS-AWSManagedRulesCommonRuleSet"
    priority = 1

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    # For managed groups, use override_action (not action)
    override_action {
      none {}
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.name}-common"
      sampled_requests_enabled   = true
    }
  }

  # --- Managed rule group: KnownBadInputs ---
  rule {
    name     = "AWS-AWSManagedRulesKnownBadInputsRuleSet"
    priority = 2

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }

    override_action {
      none {}
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.name}-kbi"
      sampled_requests_enabled   = true
    }
  }

  # --- Optional rate limit (custom rule requires action{}, not override_action) ---
  dynamic "rule" {
    for_each = var.enable_rate_limit ? [1] : []
    content {
      name     = "RateLimit"
      priority = 10

      statement {
        rate_based_statement {
          limit              = var.rate_limit_requests
          aggregate_key_type = "IP"
        }
      }

      action {
        block {}
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "${var.name}-rate"
        sampled_requests_enabled   = true
      }
    }
  }

  # --- Required top-level visibility_config ---
  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = var.name
    sampled_requests_enabled   = true
  }
}
