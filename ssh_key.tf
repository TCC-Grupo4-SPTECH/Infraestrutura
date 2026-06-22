# Gera chave SSH privada
resource "tls_private_key" "ec2_ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Salva a chave privada em arquivo .pem local
resource "local_file" "private_key" {
  filename        = "${var.ec2_key_name}.pem"
  content         = tls_private_key.ec2_ssh.private_key_pem
  file_permission = "0600"
}

# Cria a chave pública no AWS
resource "aws_key_pair" "ec2_ssh" {
  key_name   = var.ec2_key_name
  public_key = tls_private_key.ec2_ssh.public_key_openssh

  tags = { Name = "${var.project}-ssh-key" }
}
