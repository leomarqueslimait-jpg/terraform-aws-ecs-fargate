output "vpc_cidr" {
  description = "VPC cidr block"
  value       = aws_vpc.this.cidr_block
}

output "vpc_id" {
  description = "ID of VPC"
  value       = aws_vpc.this.id
}

output "private_subnets_cidr" {
  description = "CIDR of private subnets"
  value       = aws_subnet.private[*].cidr_block
}

output "public_subnets_cidr" {
  description = "CIDR of public subnets"
  value       = aws_subnet.public[*].cidr_block
}

output "isolated_subnets_cidr" {
  description = "CIDR of isolated subnets"
  value       = aws_subnet.isolated[*].cidr_block
}

#we use this ouput so ECS and RDS can use these subnets
output "private_subnets_id" {
  description = "ID of private subnets"
  value       = aws_subnet.private[*].id
}

#We use this output so ALB module can use these subnets
output "public_subnets_id" {
  description = "ID of public subnets"
  value       = aws_subnet.public[*].id

}

output "isolated_subnets_id" {
  description = "ID of isolated subnets"
  value       = aws_subnet.isolated[*].id
}

output "nat_id" {
  description = "ID of NAT"
  value       = aws_nat_gateway.this.id
}
output "public_route_table_id" {
  description = "ID of public route table"
  value       = aws_route_table.public_rt.id
}

output "private_route_table_id" {
  description = "ID of private route table"
  value       = aws_route_table.private_rt.id
}

output "alb_sg_id" {
  description = "ID of ALB security_group"
  value = aws_security_group.alb.id
  
}

output "ecs_sg_id" {
  description = "ID of ECS security_group"
  value = aws_security_group.ecs.id
}

output "rds_sg_id" {
  description = "ID of RDS security_group"
  value = aws_security_group.rds.id
}