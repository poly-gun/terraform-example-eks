output "aws-database-secret" {
  value = aws_secretsmanager_secret.credentials.name
}
