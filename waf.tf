


///////////////////////////////////////////////////////[ AWS WAFv2 RULES ]////////////////////////////////////////////////

# # ---------------------------------------------------------------------------------------------------------------------#
# Create AWS WAFv2 rules
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_wafv2_web_acl" "this" {
  name        = "${local.project}-WAF-Protections"
  provider    = aws.useast1
  scope       = "CLOUDFRONT"
  description = "${local.project}-WAF-Protections"

  default_action {
    allow {}
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name = "${local.project}-WAF-Protections"
    sampled_requests_enabled = true
  }

  dynamic "rule" {
    for_each = local.waf_ipset_rules
    content {
      name     = rule.key
      priority = rule.value.priority
      action {
        dynamic "allow" {
          for_each = rule.value.action == "allow" ? [1] : []
          content {}
        }
        dynamic "block" {
          for_each = rule.value.action == "block" ? [1] : []
          content {}
        }
      }
      statement {
        ip_set_reference_statement {
          arn = aws_wafv2_ip_set.this[rule.value.ip_set_key].arn
        }
      }
      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = rule.value.metric_name
        sampled_requests_enabled   = true
      }
    }
  }

  rule {
    name     = "${local.project}-country-based"
    priority = 2
    action {
      block {}
    }
    statement {
      geo_match_statement {
        country_codes = var.restricted_countries
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${local.project}-country-based"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "${local.project}-rate-based"
    priority = 3
    action {
      block {}
    }
    statement {
      rate_based_statement {
       limit              = 500
       aggregate_key_type = "IP"
       evaluation_window_sec = 120
       }
     }
      visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${local.project}-rate-rule"
      sampled_requests_enabled   = true
    }
   }

  rule {
    name     = "${local.project}-media-rate-based"
    priority = 4
    action {
      block {}
    }
    statement {
      rate_based_statement {
       limit              = 300
       aggregate_key_type = "IP"
       evaluation_window_sec = 120

       scope_down_statement {
         byte_match_statement {
          field_to_match {
              uri_path   {}
              }
          search_string  = "/media/"
          positional_constraint = "STARTS_WITH"

          text_transformation {
            priority   = 0
            type       = "NONE"
           }
         }
       }
     }
  }
      visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${local.project}-media-rate-based-rule"
      sampled_requests_enabled   = true
    }
   }
   
   rule {
    name     = "${local.project}-customer-rate-based"
    priority = 5
    action {
      block {}
    }
    statement {
      rate_based_statement {
       limit              = 300
       aggregate_key_type = "IP"
       evaluation_window_sec = 120

       scope_down_statement {
         byte_match_statement {
          field_to_match {
              uri_path   {}
              }
          search_string  = "/customer/"
          positional_constraint = "STARTS_WITH"

          text_transformation {
            priority   = 0
            type       = "NONE"
           }
         }
       }
     }
    }
      visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${local.project}-customer-rate-based-rule"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name = "AWSManagedRulesCommonRule"
    priority = 6
    override_action {
      none {}
    }
    statement {
      managed_rule_group_statement {
        name = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name = "${local.project}-AWSManagedRulesCommonRule"
      sampled_requests_enabled = true
    }
  }

  rule {
    name = "AWSManagedRulesAmazonIpReputation"
    priority = 7
    override_action {
      none {}
    }
    statement {
      managed_rule_group_statement {
        name = "AWSManagedRulesAmazonIpReputationList"
        vendor_name = "AWS"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name = "${local.project}-AWSManagedRulesAmazonIpReputation"
      sampled_requests_enabled = true
    }
  }
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create AWS WAFv2 IP set
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_wafv2_ip_set" "this" {
  for_each           = local.waf_ipset
  name               = each.value.name
  description        = each.value.description
  scope              = "CLOUDFRONT"
  ip_address_version = "IPV4"
  addresses          = each.value.addresses
}
