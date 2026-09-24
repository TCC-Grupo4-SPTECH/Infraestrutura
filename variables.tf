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

variable "ec2_root_volume_size" {
  description = "Tamanho do volume raiz das instancias EC2 em GB"
  type        = number
  default     = 40
}

variable "lab_role_arn" {
  description = "ARN da LabRole do AWS Academy"
  type        = string
  default     = null
}

variable "lab_role_name" {
  description = "Nome da role usada pelos serviços AWS"
  type        = string
  default     = "LabRole"
}

variable "aws_account_id" {
  description = "ID da conta AWS"
  default     = "639075827890"
}

variable "ec2_key_name" {
  description = "Nome da chave SSH para acessar a instância EC2"
  default     = "ec2-ia-test"
}