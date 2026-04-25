output "target_group_arn" {
  description = "ARN of the target group. ECS will use this to IP address"
  value       = aws_lb_target_group.ecs.arn
}

output "alb_dns_name" {
  description = "DNS name of the ALB"
  value       = aws_lb.ecs-alb.dns_name
}