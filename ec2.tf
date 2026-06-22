resource "aws_instance" "ec2_ai_server" {
  ami                    = var.ec2_ami
  instance_type          = var.ec2_instance_type
  subnet_id              = aws_subnet.private.id
  vpc_security_group_ids = [aws_security_group.ec2_ai_server.id]
  iam_instance_profile   = "LabInstanceProfile"
  key_name               = var.ec2_key_name
  user_data              = file("${path.module}/setup_ec2_yolo.sh")

  tags = { Name = "ec2_ai_server" }
}