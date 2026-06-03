resource "aws_lambda_function" "database_download" {
  function_name = "lambda_database_download"
  role = var.lab_role_arn
  runtime       = "python3.12"
  handler       = "handler.main"
  filename      = "lambda_database_download.zip"
  timeout       = 300
  memory_size   = 512

  vpc_config {
    subnet_ids         = [aws_subnet.private.id]
    security_group_ids = [aws_security_group.lambda.id]
  }

  environment {
    variables = {
      S3_RAW_BUCKET    = aws_s3_bucket.raw.bucket
      BATCH_JOB_QUEUE  = aws_batch_job_queue.main.name
      BATCH_JOB_DEF    = aws_batch_job_definition.processing.name
    }
  }

  tags = { Name = "lambda_database_download" }
}

resource "aws_lambda_function" "client_images_processing" {
  function_name = "lambda_client_images_processing"
  role = var.lab_role_arn
  runtime       = "python3.12"
  handler       = "handler.main"
  filename      = "lambda_client_images_processing.zip"
  timeout       = 60
  memory_size   = 256

  vpc_config {
    subnet_ids         = [aws_subnet.private.id]
    security_group_ids = [aws_security_group.lambda.id]
  }

  environment {
    variables = {
      S3_CLIENT_BUCKET = aws_s3_bucket.client.bucket
      EC2_AI_SERVER_IP = aws_instance.ec2_ai_server.private_ip
    }
  }

  tags = { Name = "lambda_client_images_processing" }
}

# URL pública para receber uploads via Internet Gateway
resource "aws_lambda_function_url" "client_images" {
  function_name      = aws_lambda_function.client_images_processing.function_name
  authorization_type = "NONE"
}