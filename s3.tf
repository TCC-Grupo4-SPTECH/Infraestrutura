resource "aws_s3_bucket" "raw" {
  bucket        = "${var.project}-project-s3-raw"
  force_destroy = true
  tags          = { Name = "${var.project}-project-s3-raw" }
}

resource "aws_s3_bucket" "trusted" {
  bucket        = "${var.project}-project-s3-trusted"
  force_destroy = true
  tags          = { Name = "${var.project}-project-s3-trusted" }
}

resource "aws_s3_bucket" "client" {
  bucket        = "${var.project}-project-s3-client"
  force_destroy = true
  tags          = { Name = "${var.project}-project-s3-client" }
}


resource "aws_s3_bucket_public_access_block" "raw" {
  bucket                  = aws_s3_bucket.raw.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_public_access_block" "trusted" {
  bucket                  = aws_s3_bucket.trusted.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_public_access_block" "client" {
  bucket                  = aws_s3_bucket.client.id
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "client" {
  bucket = aws_s3_bucket.client.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "PublicReadObjects"
      Effect    = "Allow"
      Principal = "*"
      Action    = "s3:GetObject"
      Resource  = "${aws_s3_bucket.client.arn}/*"
    }]
  })
}