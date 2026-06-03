output "s3_raw"     { value = aws_s3_bucket.raw.bucket }
output "s3_trusted" { value = aws_s3_bucket.trusted.bucket }
output "s3_client"  { value = aws_s3_bucket.client.bucket }

output "lambda_database_download_arn"       { value = aws_lambda_function.database_download.arn }
output "lambda_client_images_url"           { value = aws_lambda_function_url.client_images.function_url }
output "ec2_ai_server_private_ip"           { value = aws_instance.ec2_ai_server.private_ip }
output "batch_job_queue"                    { value = aws_batch_job_queue.main.name } 