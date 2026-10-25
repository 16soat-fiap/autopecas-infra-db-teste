locals {
  name = "autopecas-db-${var.environment}"
}

data "aws_subnet" "selected" {
  for_each = var.subnet_ids
  id       = each.value
}

resource "aws_db_subnet_group" "this" {
  name       = local.name
  subnet_ids = var.subnet_ids
  lifecycle {
    precondition {
      condition     = alltrue([for subnet in data.aws_subnet.selected : subnet.vpc_id == var.vpc_id]) && length(toset([for subnet in data.aws_subnet.selected : subnet.availability_zone])) >= 2
      error_message = "As sub-redes devem pertencer a VPC informada e cobrir ao menos duas zonas."
    }
  }
}

resource "aws_security_group" "database" {
  name        = "${local.name}-database"
  description = "PostgreSQL somente para clientes autorizados"
  vpc_id      = var.vpc_id
}

resource "aws_security_group" "lambda" {
  name        = "${local.name}-lambda-client"
  description = "Cliente Lambda com acesso exclusivo ao PostgreSQL"
  vpc_id      = var.vpc_id
}

resource "aws_vpc_security_group_ingress_rule" "lambda" {
  security_group_id            = aws_security_group.database.id
  referenced_security_group_id = aws_security_group.lambda.id
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
}

resource "aws_vpc_security_group_egress_rule" "lambda" {
  security_group_id            = aws_security_group.lambda.id
  referenced_security_group_id = aws_security_group.database.id
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
}

data "aws_security_group" "application" {
  for_each = var.application_security_group_ids
  id       = each.value
}

resource "aws_vpc_security_group_ingress_rule" "application" {
  for_each                     = var.application_security_group_ids
  security_group_id            = aws_security_group.database.id
  referenced_security_group_id = each.value
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432

  lifecycle {
    precondition {
      condition     = data.aws_security_group.application[each.key].vpc_id == var.vpc_id
      error_message = "O security group da aplicacao deve pertencer a VPC do banco."
    }
  }
}

resource "aws_db_parameter_group" "this" {
  name   = local.name
  family = "postgres16"
  parameter {
    name         = "rds.force_ssl"
    value        = "1"
    apply_method = "pending-reboot"
  }
}

resource "aws_db_instance" "this" {
  identifier                 = local.name
  engine                     = "postgres"
  engine_version             = "16"
  instance_class             = var.instance_class
  allocated_storage          = 20
  max_allocated_storage      = 0
  storage_type               = "gp3"
  storage_encrypted          = true
  db_name                    = "autopecas"
  username                   = var.db_username
  password                   = var.db_password
  port                       = 5432
  publicly_accessible        = false
  db_subnet_group_name       = aws_db_subnet_group.this.name
  vpc_security_group_ids     = [aws_security_group.database.id]
  parameter_group_name       = aws_db_parameter_group.this.name
  multi_az                   = var.multi_az
  backup_retention_period    = var.backup_retention_days
  deletion_protection        = var.deletion_protection
  skip_final_snapshot        = var.skip_final_snapshot
  final_snapshot_identifier  = var.skip_final_snapshot ? null : var.final_snapshot_identifier
  auto_minor_version_upgrade = true
  copy_tags_to_snapshot      = true

  lifecycle {
    precondition {
      condition     = var.skip_final_snapshot || var.final_snapshot_identifier != null
      error_message = "Informe final_snapshot_identifier quando exigir snapshot final."
    }
  }
}
