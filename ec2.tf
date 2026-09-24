resource "aws_instance" "ec2_ai_server" {
  ami                    = var.ec2_ami
  instance_type          = var.ec2_instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.ec2_ai_server.id]
  iam_instance_profile   = "LabInstanceProfile"
  key_name               = var.ec2_key_name
  user_data              = file("${path.module}/setup_ec2_yolo.sh")

  tags = { Name = "ec2_ai_server" }
}

resource "aws_eip" "ai_server" {
  domain = "vpc"

  tags = { Name = "${var.project}-ai-server-eip" }
}

resource "aws_eip_association" "ai_server" {
  instance_id   = aws_instance.ec2_ai_server.id
  allocation_id = aws_eip.ai_server.id
}

resource "aws_instance" "ec2_frontend" {
  ami                    = var.ec2_ami
  instance_type          = var.ec2_instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.ec2_frontend.id]
  key_name               = var.ec2_key_name
  user_data              = file("${path.module}/setup_ec2_frontend.sh")

  tags = { Name = "ec2_frontend" }
}

resource "aws_eip" "frontend" {
  domain = "vpc"

  tags = { Name = "${var.project}-frontend-eip" }
}

resource "aws_eip_association" "frontend" {
  instance_id   = aws_instance.ec2_frontend.id
  allocation_id = aws_eip.frontend.id
}