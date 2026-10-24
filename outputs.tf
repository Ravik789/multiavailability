

output "application_url" {
  description = "Public URL of the multi-AZ application"
  value       = "http://${aws_lb.app.dns_name}"
}

output "alb_dns_name" {
  value = aws_lb.app.dns_name
}

output "application_instance_ids" {
  value = aws_instance.app[*].id
}

output "application_private_ips" {
  value = aws_instance.app[*].private_ip
}

output "availability_zones" {
  value = var.availability_zones
}

output "vpc_id" {
  value = aws_vpc.main.id
}

