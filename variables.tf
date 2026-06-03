variable "region" {
  default = "us-east-1"
}

variable "project" {
  default = "ai-pipeline"
}

variable "ec2_ami" {
  description = "AMI da EC2 (ex: Amazon Linux 2023)"
  default     = "ami-0c101f26f147fa7fd"
}

variable "ec2_instance_type" {
  default = "t3.medium"
}

variable "lab_role_arn" {
  description = "ARN da LabRole do AWS Academy"
  default     = "arn:aws:iam::639075827890:role/LabRole"
}

variable "aws_account_id" {
  description = "ID da conta AWS"
  default     = "639075827890"
}

variable "ec2_key_name" {
  description = "Nome da chave SSH para acessar a instância EC2"
  default     = "ec2-ia-test"
}