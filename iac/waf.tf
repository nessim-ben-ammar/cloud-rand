resource "aws_wafv2_web_acl" "api_gw_waf" {
  name        = "${local.name_prefix}-waf"
  description = "WAF with rate limiting"
  scope       = "REGIONAL"
  default_action {
    allow {}
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    sampled_requests_enabled   = true
    metric_name                = "${local.name_prefix}-waf"
  }

  rule {
    name     = "${local.name_prefix}-waf-ip-rate-limit"
    priority = 1

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = 10
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      sampled_requests_enabled   = true
      metric_name                = "${local.name_prefix}-waf-ip-rate-limit"
    }
  }

  rule {
    name     = "${local.name_prefix}-waf-body-size-restriction"
    priority = 2

    action {
      block {}
    }

    statement {
      size_constraint_statement {
        comparison_operator = "GT"
        size                = 256
        field_to_match {
          body {}
        }
        text_transformation {
          priority = 0
          type     = "NONE"
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      sampled_requests_enabled   = true
      metric_name                = "${local.name_prefix}-waf-body-size-restriction"
    }
  }

  rule {
    name     = "${local.name_prefix}-waf-core-rule-set"
    priority = 3

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      sampled_requests_enabled   = true
      metric_name                = "${local.name_prefix}-waf-core-rule-set"
    }
  }
}

resource "aws_wafv2_web_acl_association" "api_gw_waf" {
  resource_arn = aws_api_gateway_stage.stage.arn
  web_acl_arn  = aws_wafv2_web_acl.api_gw_waf.arn
}
