output "ubuntu_instance_public_ip" {
  value = aws_instance.web.public_ip
}