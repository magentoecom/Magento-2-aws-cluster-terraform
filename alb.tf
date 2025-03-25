


/////////////////////////////////////////////////[ APPLICATION LOAD BALANCER ]////////////////////////////////////////////

# # ---------------------------------------------------------------------------------------------------------------------#
# Create Application Load Balancers
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_lb" "this" {
  name               = "${local.project}-alb"
  internal           = false
  load_balancer_type = "application"
  enable_deletion_protection = var.alb["enable_deletion_protection"]
  drop_invalid_header_fields = true
  security_groups    = [aws_security_group.alb.id]
  subnets            = values(aws_subnet.this).*.id
  access_logs {
    bucket  = aws_s3_bucket.this["system"].bucket
    prefix  = "ALB"
    enabled = true
  }
  tags = {
    Name = "${local.project}-alb"
  }
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create Target Groups for Load Balancers
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_lb_target_group" "this" {
  name        = "${local.project}-varnish"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.this.id
  health_check {
    path                = "/${random_string.this["health_check"].result}"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 3
    unhealthy_threshold = 2
    matcher             = "200"
  }
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create https:// listener for Load Balancer - default
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_lb_listener" "https" {
  depends_on = [aws_acm_certificate_validation.default]
  load_balancer_arn = aws_lb.this.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-Res-2021-06"
  certificate_arn   = aws_acm_certificate.default.arn
  default_action {
    type             = "fixed-response"
    fixed_response {
        content_type = "text/plain"
        message_body = "No targets are responding to this request"
        status_code  = "418"
        }
    }
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create http:// listener for Load Balancer - redirect to https://
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create conditional listener rule for Load Balancer - forward to varnish
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_lb_listener_rule" "varnish" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 30
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }
  condition {
    host_header {
      values = [var.domain]
    }
  }
  condition {
    http_header {
      http_header_name = "X-Magenx-Header"
      values = [random_uuid.this.result]
    }
  }
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create CloudWatch HTTP 5XX metrics and email alerts
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_cloudwatch_metric_alarm" "httpcode_target_5xx_count" {
  alarm_name          = "${local.project}-http-5xx-errors-from-target"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Sum"
  threshold           = var.alb["error_threshold"]
  alarm_description   = "HTTPCode 5XX count for frontend instances over ${var.alb["error_threshold"]}"
  alarm_actions       = ["${aws_sns_topic.default.arn}"]
  ok_actions          = ["${aws_sns_topic.default.arn}"]
  
  dimensions = {
    TargetGroup  = aws_lb_target_group.this.arn
    LoadBalancer = aws_lb.this.arn
  }
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create CloudWatch HTTP 5XX metrics and email alerts
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_cloudwatch_metric_alarm" "httpcode_elb_5xx_count" {
  alarm_name          = "${local.project}-http-5xx-errors-from-loadbalancer"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "HTTPCode_ELB_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Sum"
  threshold           = var.alb["error_threshold"]
  alarm_description   = "HTTPCode 5XX count for loadbalancer over ${var.alb["error_threshold"]}"
  alarm_actions       = ["${aws_sns_topic.default.arn}"]
  ok_actions          = ["${aws_sns_topic.default.arn}"]
  
  dimensions = {
    LoadBalancer = aws_lb.this.arn
  }
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create CloudWatch RequestCount metrics and email alerts
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_cloudwatch_metric_alarm" "alb_rps" {
  alarm_name          = "${local.project}-loadbalancer-rps"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "RequestCount"
  namespace           = "AWS/ApplicationELB"
  period              = "120"
  statistic           = "Sum"
  threshold           = var.alb["rps_threshold"]
  alarm_description   = "The number of requests processed over 2 minutes greater than ${var.alb["rps_threshold"]}"
  alarm_actions       = ["${aws_sns_topic.default.arn}"]
  ok_actions          = ["${aws_sns_topic.default.arn}"]

  dimensions = {
    LoadBalancer = aws_lb.this.arn
  }
}


