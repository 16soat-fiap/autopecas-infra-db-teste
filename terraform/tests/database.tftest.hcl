mock_provider "aws" {}

variables {
  environment               = "homologacao"
  vpc_id                    = "vpc-test"
  subnet_ids                = ["subnet-a", "subnet-b"]
  db_password               = "senha-exclusiva-de-teste-123"
  final_snapshot_identifier = "autopecas-test-final"
}

override_data {
  target = data.aws_subnet.selected["subnet-a"]
  values = {
    vpc_id            = "vpc-test"
    availability_zone = "us-east-1a"
  }
}
override_data {
  target = data.aws_subnet.selected["subnet-b"]
  values = {
    vpc_id            = "vpc-test"
    availability_zone = "us-east-1b"
  }
}

override_data {
  target = data.aws_security_group.application["sg-app"]
  values = {
    vpc_id = "vpc-test"
  }
}

run "private_encrypted_database" {
  command = plan
  assert {
    condition     = !aws_db_instance.this.publicly_accessible && aws_db_instance.this.storage_encrypted
    error_message = "O banco deve ser privado e criptografado."
  }
  assert {
    condition = (aws_db_instance.this.deletion_protection && aws_db_instance.this.skip_final_snapshot &&
      aws_db_instance.this.backup_retention_period == 0 && aws_db_instance.this.max_allocated_storage == 0 &&
    !aws_db_instance.this.multi_az && aws_db_instance.this.allocated_storage == 20)
    error_message = "Perfil do Lab deve manter protecao contra exclusao sem backups, Multi-AZ ou crescimento automatico."
  }
  assert {
    condition     = aws_vpc_security_group_ingress_rule.lambda.from_port == 5432 && aws_vpc_security_group_ingress_rule.lambda.ip_protocol == "tcp"
    error_message = "A Lambda deve acessar somente PostgreSQL."
  }
  assert {
    condition     = length(aws_vpc_security_group_ingress_rule.application) == 0
    error_message = "Nao liberar aplicacao sem configurar seu security group."
  }
}

run "application_access" {
  command = plan
  variables {
    application_security_group_ids = ["sg-app"]
    multi_az                       = true
    backup_retention_days          = 7
  }
  assert {
    condition     = aws_vpc_security_group_ingress_rule.application["sg-app"].referenced_security_group_id == "sg-app" && aws_db_instance.this.multi_az
    error_message = "Liberar somente o SG configurado e respeitar Multi-AZ."
  }
}

run "reject_single_subnet" {
  command = plan
  variables {
    subnet_ids = ["subnet-a"]
  }
  expect_failures = [var.subnet_ids]
}

run "reject_wrong_vpc" {
  command = plan
  variables {
    vpc_id = "vpc-other"
  }
  expect_failures = [aws_db_subnet_group.this]
}


run "reject_missing_snapshot_name" {
  command = plan
  variables {
    skip_final_snapshot       = false
    final_snapshot_identifier = null
  }
  expect_failures = [aws_db_instance.this]
}

run "production_isolation" {
  command = plan
  variables {
    environment = "producao"
  }
  assert {
    condition = (aws_db_instance.this.identifier == "autopecas-db-producao" &&
      aws_db_subnet_group.this.name == "autopecas-db-producao" &&
      aws_db_parameter_group.this.name == "autopecas-db-producao" &&
    aws_security_group.database.name == "autopecas-db-producao-database")
    error_message = "Producao deve ter recursos separados da homologacao."
  }
  assert {
    condition = (aws_db_instance.this.instance_class == "db.t3.micro" &&
      !aws_db_instance.this.multi_az && aws_db_instance.this.backup_retention_period == 0 &&
      aws_db_instance.this.allocated_storage == 20 && aws_db_instance.this.max_allocated_storage == 0 &&
      !aws_db_instance.this.publicly_accessible && aws_db_instance.this.storage_encrypted &&
    aws_db_instance.this.deletion_protection && length(aws_vpc_security_group_ingress_rule.application) == 0)
    error_message = "O perfil de producao do Lab deve preservar o limite de recursos e o isolamento de rede."
  }
}

run "reject_application_in_another_vpc" {
  command = plan
  variables {
    application_security_group_ids = ["sg-app"]
  }
  override_data {
    target = data.aws_security_group.application["sg-app"]
    values = {
      vpc_id = "vpc-other"
    }
  }
  expect_failures = [aws_vpc_security_group_ingress_rule.application["sg-app"]]
}
