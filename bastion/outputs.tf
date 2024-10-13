output "instance_ip_ec2" {
  value = aws_instance.ec2_instance.public_ip
}

output "tag_name" {
  value = aws_instance.ec2_instance.tags["Name"]
}

output "instance_state" {
  value = aws_instance.ec2_instance.instance_state
}

