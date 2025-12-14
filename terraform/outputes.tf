# outputs.tf
output "public_instance_public_ip" {
  description = "Public IP of the public instance"
  value       = aws_instance.public.public_ip
}

output "private_instance_1_private_ip" {
  description = "Private IP of private instance 1"
  value       = aws_instance.private_1.private_ip
}

output "private_instance_2_private_ip" {
  description = "Private IP of private instance 2"
  value       = aws_instance.private_2.private_ip
}

output "ssh_private_key_path" {
  description = "Path to the generated SSH private key"
  value       = local_file.private_key.filename
  sensitive   = true
}