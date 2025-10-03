output "port"         { value = aws_db_instance.this[0].port }
output "secret_arn"   { value = aws_secretsmanager_secret.db.arn }
output "secret_name"  { value = aws_secretsmanager_secret.db.name }
output "security_group_id" {
  value = aws_security_group.db[0].id
}

output "endpoint" {
  value = aws_db_instance.this[0].address
}
