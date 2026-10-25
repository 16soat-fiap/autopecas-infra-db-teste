variable "region" {
  type    = string
  default = "us-east-1"
}
variable "environment" {
  type = string
  validation {
    condition     = contains(["homologacao", "producao"], var.environment)
    error_message = "Use homologacao ou producao."
  }
}
variable "vpc_id" {
  type = string
  validation {
    condition     = startswith(var.vpc_id, "vpc-")
    error_message = "Informe a VPC compartilhada pelo banco e clientes."
  }
}
variable "subnet_ids" {
  description = "Sub-redes da VPC em pelo menos duas zonas de disponibilidade."
  type        = set(string)
  validation {
    condition     = length(var.subnet_ids) >= 2 && alltrue([for id in var.subnet_ids : startswith(id, "subnet-")])
    error_message = "Informe pelo menos duas sub-redes."
  }
}
variable "application_security_group_ids" {
  description = "Security groups de origem reais da aplicacao Kubernetes."
  type        = set(string)
  default     = []
}
variable "db_username" {
  type    = string
  default = "autopecas_admin"
}
variable "db_password" {
  type      = string
  sensitive = true
  validation {
    condition     = length(var.db_password) >= 16 && length(var.db_password) <= 128 && can(regex("^[A-Za-z0-9!#$%&()*+,.:;<=>?^_{}|~-]+$", var.db_password))
    error_message = "Use 16 a 128 caracteres ASCII sem espacos, barra, aspas ou arroba."
  }
}
variable "instance_class" {
  type    = string
  default = "db.t3.micro"
}
variable "multi_az" {
  type    = bool
  default = false
}
variable "backup_retention_days" {
  type    = number
  default = 0
  validation {
    condition     = var.backup_retention_days >= 0 && var.backup_retention_days <= 35 && floor(var.backup_retention_days) == var.backup_retention_days
    error_message = "Retencao deve ser um inteiro de 0 a 35 (zero desativa backups automaticos) dias."
  }
}
variable "deletion_protection" {
  type    = bool
  default = true
}
variable "skip_final_snapshot" {
  description = "Concessao do laboratorio: excluir o banco sem reter snapshot final."
  type        = bool
  default     = true
}
variable "final_snapshot_identifier" {
  description = "Nome unico do snapshot final, usado somente quando skip_final_snapshot=false."
  type        = string
  default     = null
  validation {
    condition     = var.final_snapshot_identifier == null ? true : can(regex("^[a-z][a-z0-9-]*[a-z0-9]$", var.final_snapshot_identifier)) && !strcontains(var.final_snapshot_identifier, "--")
    error_message = "Use identificador RDS valido, sem hifens consecutivos."
  }
}
