output "vpc_id" {
  description = "VPC id."
  value       = aws_vpc.main.id
}

output "public_subnet_id" {
  description = "The public subnet: nodes and the ingress NLB."
  value       = aws_subnet.public.id
}

output "private_subnet_ids" {
  description = "Private subnets (RDS subnet group, EKS control-plane ENIs)."
  value       = aws_subnet.private[*].id
}

output "private_cidrs" {
  description = "CIDRs of the private subnets: the chart's networkPolicies.postgresCidr egress rule."
  value       = aws_subnet.private[*].cidr_block
}
