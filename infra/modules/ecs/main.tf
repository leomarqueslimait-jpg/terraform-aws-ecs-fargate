resource "aws_ecs_cluster" "this" {
  name = "ecs-docker-cluster"
}

resource "aws_ecs_task_definition" "app" {
  family                   = "app"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.task.arn

  container_definitions = jsonencode([
    {
      name      = "app"
      image     = var.container_image
      essential = true

      portMappings = [{
        containerPort = 5000
        protocol      = "tcp"
      }]

      environment = [
        { name = "DB_HOST", value = var.db_endpoint },
        { name = "DB_NAME", value = "appdb" },
        { name = "DB_USER", value = "dbadmin" },
        { name = "DB_PORT", value = "5432" }
      ]

      secrets = [
        {
          name      = "DB_PASSWORD"
          valueFrom = var.secrets_arn
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = "/ecs/app"
          awslogs-region        = "us-east-1"
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])
}

resource "aws_ecs_service" "app" {
  name            = "app-service"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = 2
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnets_id
    security_groups  = [var.ecs_sg_id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = var.target_group_arn
    container_name   = "app"
    container_port   = 5000
  }
}

resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/ecs/app"
  retention_in_days = 7
}

#what to scale and capacity
resource "aws_appautoscaling_target" "ecs" {
  max_capacity       = 4
  min_capacity       = 2
  resource_id        = "service/${aws_ecs_cluster.this.name}/${aws_ecs_service.app.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

#the policy. defines when to scale - the target
resource "aws_appautoscaling_policy" "cpu" {
  name               = "ecs-cpu-utilization"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs.scalable_dimension #what to scale?  referencing   scalable_dimension = "ecs:servicec:DesiredCount"

  service_namespace = aws_appautoscaling_target.ecs.service_namespace #which aws service?

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value       = 60 # scale out/in when CPU hits 60%
    scale_in_cooldown  = 60 # wait 60s before scaling in
    scale_out_cooldown = 60 # wait 60s before scaling out
  }
}