output "private-ssh-key" {
    value     = tls_private_key.key.private_key_pem
    description = "..."
    sensitive = true
}

output "aws-ssh-key-pair-name" {
    value = aws_key_pair.key.key_name
    description = "..."
}

output "bastion-security-group-id" {
    value = aws_security_group.sg.id
    description = "..."
}
