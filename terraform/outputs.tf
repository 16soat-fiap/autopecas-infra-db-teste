output "db_endpoint" {
  value = aws_db_instance.this.address
}
output "db_port" {
  value = aws_db_instance.this.port
}
output "db_name" {
  value = aws_db_instance.this.db_name
}
output "db_url" {
  value = "jdbc:postgresql://${aws_db_instance.this.address}:5432/${aws_db_instance.this.db_name}?sslmode=require"
}
output "db_security_group_id" {
  value = aws_security_group.database.id
}
output "lambda_security_group_ids" {
  value = [aws_security_group.lambda.id]
}
output "lambda_subnet_ids" {
  value = var.subnet_ids
}
output "vpc_id" {
  value = var.vpc_id
}
