resource "aws_lambda_function" "database_download" {
  function_name = "lambda_database_download"
  role          = local.effective_lab_role_arn
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