# terraform-aws-ecs-fargate

A production-pattern three-tier containerized application on AWS using ECS Fargate, RDS PostgreSQL Multi-AZ, and an Application Load Balancer — fully provisioned with Terraform.

---

## Architecture

```
Internet
    │
    │  HTTP port 80
    ▼
┌─────────────────────────────────────────────────────────────┐
│                    Public Subnets                           │
│  ┌──────────────────────────────────────────────────────┐   │
│  │         Application Load Balancer (ALB)              │   │
│  │  Listener port 80 → Target Group → ECS tasks         │   │
│  │  Health check logs → S3 bucket                       │   │
│  └──────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
    │
    │  HTTP port 5000
    ▼
┌─────────────────────────────────────────────────────────────┐
│                    Private Subnets                          │
│  ┌─────────────────────┐  ┌─────────────────────────────┐   │
│  │   ECS Task (AZ-a)   │  │      ECS Task (AZ-b)        │   │
│  │   Flask app:5000    │  │      Flask app:5000          │   │
│  └─────────────────────┘  └─────────────────────────────┘   │
│                                                             │
│  Auto Scaling: min 2 tasks → max 4 tasks @ 60% CPU         │
└─────────────────────────────────────────────────────────────┘
    │
    │  PostgreSQL port 5432
    ▼
┌─────────────────────────────────────────────────────────────┐
│                    Isolated Subnets                         │
│  ┌──────────────────────────────────────────────────────┐   │
│  │         RDS PostgreSQL 16 Multi-AZ                   │   │
│  │  Primary (AZ-a)  ←sync→  Standby (AZ-b)             │   │
│  └──────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

### Subnet Design

The VPC (`10.1.0.0/16`) is divided into three tiers. Each tier reserves an `/21` block giving 8 available `/24` subnets per tier for future growth without address space conflicts:

```
Public   10.1.0.0/21  → 10.1.1.0/24, 10.1.2.0/24    (ALB)
Private  10.1.8.0/21  → 10.1.16.0/24, 10.1.17.0/24  (ECS)
Isolated 10.1.16.0/21 → 10.1.32.0/24, 10.1.33.0/24  (RDS)
Spare    10.1.48.0/21+                                 (future tiers)
```

---

## Modules

### bootstrap/
Creates the remote state infrastructure. Must be deployed before `infra/`.

| Resource | Purpose |
|----------|---------|
| `aws_s3_bucket` | Stores Terraform state remotely |
| `aws_s3_bucket_versioning` | Protects state history — allows rollback |
| `aws_s3_bucket_server_side_encryption_configuration` | Encrypts state at rest |
| `aws_dynamodb_table` | State locking — prevents simultaneous applies |

---

### modules/networking/

**VPC and Subnets**

| Resource | Purpose | Connects To |
|----------|---------|-------------|
| `aws_vpc` | Main network boundary, DNS enabled | All subnets |
| `aws_subnet.public` | 2 AZs, auto-assigns public IPs | ALB, IGW, NAT |
| `aws_subnet.private` | 2 AZs, no public IPs | ECS tasks |
| `aws_subnet.isolated` | 2 AZs, no internet route whatsoever | RDS only |
| `aws_internet_gateway` | Allows public subnets to reach the internet | Public route table |
| `aws_eip` | Static public IP for NAT Gateway | NAT Gateway |
| `aws_nat_gateway` | Allows private subnets outbound internet for ECR image pulls | Private route table |
| `aws_route_table.public_rt` | Routes `0.0.0.0/0` → IGW | Public subnets |
| `aws_route_table.private_rt` | Routes `0.0.0.0/0` → NAT | Private subnets |
| `aws_route_table.isolated` | No routes — completely isolated | Isolated subnets |

**Security Groups**

Security groups are defined as separate `aws_security_group_rule` resources instead of inline blocks. This avoids circular dependency errors since ALB, ECS, and RDS all reference each other's security groups.

The pattern used is **security group chaining** — rules reference other security groups instead of CIDRs, meaning only resources explicitly assigned a security group can communicate, not just anything in the same subnet.

| Security Group | Inbound | Outbound |
|----------------|---------|---------|
| `alb` | 80, 443 from `0.0.0.0/0` | 5000 to ECS sg |
| `ecs` | 5000 from ALB sg | 5432 to RDS sg, 443 to `0.0.0.0/0` |
| `rds` | 5432 from ECS sg | none |

> **Lesson learned:** Writing security groups with inline ingress/egress blocks where resources reference each other causes a cycle error — Terraform can't determine which resource to create first. Separating them into `aws_security_group_rule` resources breaks the cycle by creating empty security groups first and attaching rules after.

---

### modules/ecr/

| Resource | Purpose | Connects To |
|----------|---------|-------------|
| `aws_ecr_repository` | Private Docker registry | ECS task definition image |
| `terraform_data.push_image` | Builds and pushes Docker image automatically during `terraform apply` | Depends on ECR repo |

The `terraform_data` resource runs three commands locally during apply:
1. Authenticate Docker to ECR using AWS credentials
2. Build the Docker image from `app/`
3. Push the image to ECR

`force_delete = true` allows `terraform destroy` to delete the repository even when it contains images.

---

### modules/secrets/

| Resource | Purpose | Connects To |
|----------|---------|-------------|
| `random_password` | Generates a 16-char cryptographically secure password | Secret version, RDS module |
| `aws_secretsmanager_secret` | Creates the secret container | Secret version |
| `aws_secretsmanager_secret_version` | Stores the password value | ECS (via ARN at runtime) |

The password uses `override_special = "!#$%&*()-_=+[]{}?"` to exclude characters RDS doesn't accept (`/`, `@`, `"`, space).

**How the secret is consumed:**
- **RDS** — receives the password directly as a module output (`db_password`) at apply time
- **ECS** — receives only the secret ARN and AWS injects the value as `DB_PASSWORD` at container runtime

> **Lesson learned:** Secrets Manager has a 30 day recovery window by default. After `terraform destroy`, the secret is scheduled for deletion but not immediately deleted. Running `terraform apply` again fails because the name is taken. For portfolio projects where you destroy and recreate frequently, setting `recovery_window_in_days = 0` deletes the secret immediately on destroy. In production, keep the 30 day window as a safety net against accidental deletion.

> **Lesson learned:** Originally the RDS module fetched the password using a `data.aws_secretsmanager_secret_version` data source. This caused a race condition — Terraform tried to read the secret in the same apply that created it, and sometimes the secret wasn't fully propagated before RDS tried to fetch it. The fix was to remove the data source entirely and pass the password directly from the secrets module output through `infra/main.tf`. This eliminates the timing issue because Terraform's dependency graph guarantees the password value exists before RDS is created.

---

### modules/rds/

| Resource | Purpose | Connects To |
|----------|---------|-------------|
| `aws_db_subnet_group` | Defines which subnets RDS can use (isolated only) | RDS instance |
| `aws_db_instance` | PostgreSQL 16 Multi-AZ database | ECS via endpoint |

**Key configuration:**

| Setting | Value | Reason |
|---------|-------|--------|
| `multi_az` | `true` | Standby in second AZ, automatic failover |
| `storage_encrypted` | `true` | Data encrypted at rest |
| `publicly_accessible` | `false` | No internet access |
| `storage_type` | `gp3` | Newer, faster, cheaper than gp2 |
| `backup_retention_period` | `7` | 7 days of automated backups |
| `skip_final_snapshot` | `true` | Portfolio — set to `false` in production |
| `deletion_protection` | `false` | Portfolio — set to `true` in production |

> **Lesson learned:** `aws_db_instance` has two similar attributes — `endpoint` returns `host:port` as a combined string, while `address` returns only the hostname. Using `endpoint` as `DB_HOST` caused a DNS resolution error because the port was being included in the hostname. Always use `address` when you need just the host.

---

### modules/alb/

| Resource | Purpose | Connects To |
|----------|---------|-------------|
| `random_id` | Generates unique suffix for S3 bucket name | S3 bucket |
| `aws_s3_bucket` | Stores ALB health check logs | ALB via `health_check_logs` block |
| `aws_s3_bucket_policy` | Grants ALB permission to write logs to S3 | S3 bucket |
| `aws_lb` | Application Load Balancer in public subnets | Listener, ALB security group |
| `aws_lb_target_group` | Pool of ECS task IPs on port 5000, runs health checks | ALB listener, ECS service |
| `aws_lb_listener` | Listens on port 80, forwards to target group | ALB, target group |

**How the three ALB resources connect:**

```
aws_lb                → the load balancer (no references to others)
aws_lb_target_group   → pool of destinations (references vpc_id only)
aws_lb_listener       → the glue (references both ALB and target group)
aws_ecs_service       → registers task IPs into target group at runtime
```

The listener is the only resource that connects the ALB to the target group. The target group itself starts empty — the ECS service registers task IPs into it when tasks start and deregisters them when tasks stop. The ALB is completely unaware of this process — it just sees healthy IPs appear and disappear in the pool.

**Health check:**
- Path: `/health` — dedicated lightweight endpoint that always returns 200
- Interval: 35 seconds / Timeout: 5 seconds
- Healthy threshold: 3 / Unhealthy threshold: 3

`target_type = "ip"` is required because Fargate tasks are addressed by private IP, not EC2 instance ID.

---

### modules/ecs/

**`main.tf`**

| Resource | Purpose | Connects To |
|----------|---------|-------------|
| `aws_ecs_cluster` | Logical grouping for tasks and services | ECS service |
| `aws_cloudwatch_log_group` | Receives container logs at `/ecs/app` | Task definition log config |
| `aws_ecs_task_definition` | Blueprint: image, CPU, memory, env vars, secrets, ports | ECS service |
| `aws_ecs_service` | Keeps 2 tasks running, registers IPs into ALB target group | Cluster, task definition, ALB, networking |
| `aws_appautoscaling_target` | Registers ECS service as an auto scalable resource | Auto scaling policy |
| `aws_appautoscaling_policy` | Scales tasks out when CPU > 60%, in when CPU drops | Auto scaling target |

**How auto scaling connects to the rest of the architecture:**

```
aws_appautoscaling_target
  → resource_id = "service/ecs-docker-cluster/app-service"
  → registers this specific ECS service as scalable

aws_appautoscaling_policy
  → references target via resource_id, scalable_dimension, service_namespace
  → watches ECSServiceAverageCPUUtilization metric
  → when CPU > 60%: increases aws_ecs_service desired_count
  → new tasks start → register their IPs into ALB target group automatically
  → ALB starts sending traffic to new tasks with no configuration changes
```

The auto scaling target and policy live in the ECS module because they directly reference the ECS cluster and service names. The ALB is completely unaware of scaling — it just sees more healthy task IPs appear in the target group pool.

**Auto scaling configuration:**

| Setting | Value | Purpose |
|---------|-------|---------|
| `min_capacity` | 2 | Always keep at least 2 tasks for HA |
| `max_capacity` | 4 | Never exceed 4 tasks |
| `target_value` | 60% CPU | Scale out above, scale in below |
| `scale_out_cooldown` | 60s | Wait before adding more tasks |
| `scale_in_cooldown` | 60s | Wait before removing tasks |

**Container configuration:**

| Setting | Value | Purpose |
|---------|-------|---------|
| `image` | ECR URL`:v1` | Which container to run |
| `cpu / memory` | 256 / 512 | 0.25 vCPU, 512MB RAM |
| `essential` | `true` | Restart entire task if container crashes |
| `containerPort` | 5000 | Exposes Flask port to task network interface |
| `environment` | DB_HOST, DB_NAME, DB_USER, DB_PORT | Non-sensitive config as plain text |
| `secrets` | DB_PASSWORD from Secrets Manager ARN | Password injected securely at runtime |
| `logConfiguration` | awslogs → `/ecs/app` | Ships stdout/stderr to CloudWatch |

**`iam.tf`**

| Resource | Purpose |
|----------|---------|
| `aws_iam_role.execution` | Used by ECS to pull image from ECR, fetch secrets, write logs |
| `aws_iam_role.task` | Used by app code at runtime (currently minimal permissions) |
| `aws_iam_role_policy_attachment.execution` | Attaches `AmazonECSTaskExecutionRolePolicy` (ECR + CloudWatch) |
| `aws_iam_role_policy.secrets` | Grants `secretsmanager:GetSecretValue` on the specific secret ARN |

```
Execution role → ECS infrastructure (pull image, fetch secrets, write logs)
Task role      → Application code permissions (what Flask can call in AWS)
```

---

## Full Connection Map

```
module.secrets
  ├── db_password ─────────────────────────────► module.rds password (apply time)
  └── rds_secret_arn ──────────────────────────► module.ecs secrets valueFrom (runtime)

module.networking
  ├── vpc_id ──────────────────────────────────► alb target group vpc_id
  ├── public_subnets_id ───────────────────────► aws_lb subnets
  ├── private_subnets_id ──────────────────────► aws_ecs_service network_configuration
  ├── isolated_subnets_id ─────────────────────► aws_db_subnet_group subnet_ids
  ├── alb_sg_id ───────────────────────────────► aws_lb security_groups
  ├── ecs_sg_id ───────────────────────────────► aws_ecs_service security_groups
  └── rds_sg_id ───────────────────────────────► aws_db_instance vpc_security_group_ids

module.ecr
  └── repository_url ──────────────────────────► aws_ecs_task_definition image

module.rds
  └── db_endpoint (address only) ──────────────► ecs DB_HOST environment variable

module.alb
  └── target_group_arn ────────────────────────► aws_ecs_service load_balancer block

aws_ecs_service (runtime)
  └── registers task IPs ──────────────────────► ALB target group pool
```

---

## Application Endpoints

| Endpoint | Response | Purpose |
|----------|---------|---------|
| `GET /` | `{"message": "Hello from ECS!"}` | Confirms app is running |
| `GET /health` | `{"status": "healthy"}` | ALB health check target |
| `GET /db` | `{"status": "database connected"}` | Confirms RDS connectivity |
| `GET /stress` | `{"result": ..., "status": "done"}` | CPU intensive endpoint for load testing |

---

## Deployment

### Prerequisites
- AWS CLI configured
- Terraform >= 1.7
- Docker installed and running

### Deploy

```bash
# 1. Create remote state infrastructure
cd bootstrap
terraform init
terraform apply

# 2. Deploy all infrastructure
# Docker image is built and pushed automatically via terraform_data
cd ../infra
terraform init
terraform apply
```

### Test

```bash
terraform output alb_dns_name

curl http://<alb_dns_name>/
curl http://<alb_dns_name>/health
curl http://<alb_dns_name>/db
```

### Load Test

```bash
sudo apt install -y apache2-utils
ab -n 5000 -c 50 http://<alb_dns_name>/stress
```

Watch tasks scale in: AWS Console → ECS → Clusters → ecs-docker-cluster → Tasks

### Destroy

```bash
terraform destroy
```

---

## Production Considerations

| Setting | This Project | Production |
|---------|-------------|------------|
| HTTPS | HTTP port 80 | HTTPS port 443 with ACM certificate |
| HTTP | forwards to ECS | redirects to HTTPS (301) |
| `deletion_protection` | `false` | `true` |
| `skip_final_snapshot` | `true` | `false` |
| `recovery_window_in_days` | `0` | `30` |
| Auto scaling max | 4 tasks | based on load testing |
| RDS instance | `db.t3.micro` | `db.t3.medium` or larger |
| CloudWatch retention | 7 days | 30-90 days |
| Domain | ALB auto-generated DNS | Custom domain via Route 53 + ACM |

---

## Cost Estimate (us-east-1)

| Resource | Cost |
|----------|------|
| NAT Gateway | ~$0.045/hr |
| RDS db.t3.micro Multi-AZ | ~$0.036/hr |
| ALB | ~$0.008/hr |
| ECS Fargate 2 tasks | ~$0.010/hr |
| Secrets Manager | ~$0.40/month |
| **Total** | **~$0.10/hr (~$2.40/day)** |

> Destroy resources after testing to avoid unnecessary charges.
