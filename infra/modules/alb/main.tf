resource "random_id" "alb_logs" {
  byte_length = 4
}

resource "aws_s3_bucket" "alb_logs" {
  bucket        = "ecs-fargate-alb-logs-${random_id.alb_logs.hex}"
  force_destroy = true

  tags = merge(var.tags, { Name = "alb-logs" }, { Environment = "modules/alb" })
}

resource "aws_s3_bucket_policy" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id
  policy = data.aws_iam_policy_document.alb_logs.json
}

data "aws_iam_policy_document" "alb_logs" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["logdelivery.elasticloadbalancing.amazonaws.com"]
    }

    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.alb_logs.arn}/alb-logs/AWSLogs/*"]
  }
}


resource "aws_lb" "ecs-alb" {
  name                             = "ecs-alb"
  load_balancer_type               = "application"
  enable_cross_zone_load_balancing = true
  security_groups                  = [var.alb_sg_ids]
  subnets                          = var.public_subnets_ids
  health_check_logs {
    bucket  = aws_s3_bucket.alb_logs.id
    enabled = true
    prefix  = "alb-logs"
  }

  tags = merge(var.tags, { Name = "alb" }, { Environment = "modules/alb" })
}

resource "aws_lb_target_group" "ecs" {
  name                              = "ecs-alb-tg"
  load_balancing_cross_zone_enabled = true
  port                              = 5000
  protocol                          = "HTTP"
  vpc_id                            = var.vpc_id
  target_type                       = "ip"

  health_check {
    path                = "/health"
    healthy_threshold   = 3
    interval            = 35
    unhealthy_threshold = 3
    timeout             = 5
  }
  tags = merge(var.tags, { Name = "ecs-target-group" }, { Environment = "modules/alb" })


}

resource "aws_lb_listener" "ecs-alb" {
  load_balancer_arn = aws_lb.ecs-alb.arn
  port              = 80
  protocol          = "HTTP" #HTTPS with ACM would be added in production

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ecs.arn
  }

}

