resource "aws_batch_compute_environment" "main" {
  compute_environment_name = "${var.project}-batch-compute"
  type                     = "MANAGED"
  service_role     = var.lab_role_arn

  compute_resources {
    type               = "FARGATE"
    max_vcpus          = 16
    subnets            = [aws_subnet.private.id]
    security_group_ids = [aws_security_group.batch.id]
  }
}

resource "aws_batch_job_queue" "main" {
  name     = "${var.project}-job-queue"
  state    = "ENABLED"
  priority = 1

  compute_environment_order {
    order               = 1
    compute_environment = aws_batch_compute_environment.main.arn
  }
}

resource "aws_batch_job_definition" "processing" {
  name = "${var.project}-job-definition"
  type = "container"
  platform_capabilities = ["FARGATE"]

  container_properties = jsonencode({
    image   = "python:3.12-slim"
    command = ["python", "batch_process.py"]

    fargatePlatformConfiguration = {
      platformVersion = "LATEST"
    }

    resourceRequirements = [
      { type = "VCPU",   value = "2" },
      { type = "MEMORY", value = "4096" }
    ]

    executionRoleArn = var.lab_role_arn

    environment = [
      { name = "S3_RAW_BUCKET",     value = aws_s3_bucket.raw.bucket },
      { name = "S3_TRUSTED_BUCKET", value = aws_s3_bucket.trusted.bucket },
      { name = "AUGMENTATIONS_PER_IMAGE", value = "10" }
    ]
  })
}