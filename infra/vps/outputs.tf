output "vps_public_ip" {
  description = "Elastic IP of the VPS"
  value       = aws_eip.vps.public_ip
}

output "vps_nip_domain" {
  description = "nip.io domain — use this for Certbot and in README hosted URL"
  value       = "${aws_eip.vps.public_ip}.nip.io"
}

output "vps_https_url" {
  value = "https://${aws_eip.vps.public_ip}.nip.io"
}

output "ssh_command" {
  description = "SSH into the VPS"
  value       = "ssh -i ~/.ssh/${var.key_pair_name}.pem ubuntu@${aws_eip.vps.public_ip}"
}
