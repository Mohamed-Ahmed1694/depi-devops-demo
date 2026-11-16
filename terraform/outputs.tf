output "server_public_ip" {
  value = aws_instance.demo.public_ip
}

output "ssh_command" {
  value = "ssh -i ${var.private_key_path} ubuntu@${aws_instance.demo.public_ip}"
}

output "urls" {
  value = {
    app        = "http://${aws_instance.demo.public_ip}:30080"
    jenkins    = "http://${aws_instance.demo.public_ip}:8080 (only if install_jenkins=true)"
    prometheus = "http://${aws_instance.demo.public_ip}:30090"
    grafana    = "http://${aws_instance.demo.public_ip}:30030"
  }
}
