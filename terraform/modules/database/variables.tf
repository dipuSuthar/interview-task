variable "name" { type = string }
variable "subnet_ids" { type = list(string) }
variable "security_group_id" { type = string }
variable "db_name" {
  type    = string
  default = "appdb"
}
variable "username" {
  type    = string
  default = "appadmin"
}
variable "engine_version" {
  type    = string
  default = "8.0"
}
variable "instance_class" {
  type    = string
  default = "db.t3.micro"
}
variable "allocated_storage" {
  type    = number
  default = 20
}
variable "multi_az" {
  type    = bool
  default = false
}
variable "create_read_replica" {
  type    = bool
  default = true
}
variable "backup_retention_days" {
  type        = number
  default     = 1
  description = "Must be >= 1 for a read replica to be possible."
}
variable "deletion_protection" {
  type    = bool
  default = false
}
variable "skip_final_snapshot" {
  type    = bool
  default = true
}
variable "secret_recovery_days" {
  type    = number
  default = 0
}
