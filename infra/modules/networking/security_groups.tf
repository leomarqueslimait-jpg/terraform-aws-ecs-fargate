resource "aws_security_group" "alb" {
  name        = "alb_sg"
  description = "Allow  0.0.0.0/0 ALB inbound and outbound traffic"
  vpc_id      = aws_vpc.this.id


  tags = merge(local.common_tags, { Name = "${var.name}-alb-sg" })
}

resource "aws_security_group" "ecs" {
    description = "Controls traffic to and from ALB and RDS"
  name   = "ecs_sg"
  vpc_id = aws_vpc.this.id

  
  tags = merge(local.common_tags, { Name = "${var.name}-ecs-sg" })

}

resource "aws_security_group" "rds" {
    description = "Controls traffic to and from ECS"
  name   = "rds_sg"
  vpc_id = aws_vpc.this.id

  tags = merge(local.common_tags, { Name = "${var.name}-rds-sg" })

}

resource "aws_security_group_rule" "alb_ingress_https" {
  description = "Allow traffic from the internet on port 443"
    type = "ingress"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    security_group_id = aws_security_group.alb.id
}

resource "aws_security_group_rule" "alb_ingress_http" {
   description = "Allow traffic from the internet on port 80"
   type = "ingress"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    security_group_id = aws_security_group.alb.id
}

resource "aws_security_group_rule" "alb_egress_ecs" {
type = "egress"
description     = "Allow connection to ECS"
    from_port       = 5000
    to_port         = 5000
    protocol        = "tcp"
    source_security_group_id = aws_security_group.ecs.id
    security_group_id = aws_security_group.alb.id
}

resource "aws_security_group_rule" "ecs_ingress_alb" {
    type = "ingress"
    description     = "Allow traffic from ALB"
    from_port       = 5000
    to_port         = 5000
    protocol        = "tcp"
    source_security_group_id = aws_security_group.alb.id
    security_group_id = aws_security_group.ecs.id
  
}

resource "aws_security_group_rule" "ecs_egress_rds" {
    type = "egress"
    description     = "Allow traffic to RDS"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    source_security_group_id = aws_security_group.rds.id
    security_group_id = aws_security_group.ecs.id
  
}

resource "aws_security_group_rule" "ecs_egress_https" {
  type = "egress"
  description = "Allow traffic to pull ECR images"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    security_group_id = aws_security_group.ecs.id
  
}

resource "aws_security_group_rule" "rds_ingress_ecs" {
  type = "ingress"
  description     = "Allow traffic from ECS"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    source_security_group_id = aws_security_group.ecs.id
    security_group_id = aws_security_group.rds.id
  }
