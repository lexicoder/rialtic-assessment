terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.71.0"
    }
  }
}

provider "aws" {
  region = "eu-central-1"
}

resource "aws_s3_bucket" "upload_bucket" {
  bucket = "upload-bucket"
  acl    = "private"
}

resource "aws_s3_bucket_notification" "bucket_notif" {
  bucket = aws_s3_bucket.upload_bucket.id

  queue {
    queue_arn     = aws_sqs_queue.upload_queue.arn
    events        = ["s3:ObjectCreated:*"]
  }
}

resource "aws_sqs_queue" "upload_queue" {
  name                      = "upload-queue"
  delay_seconds             = 60
  max_message_size          = 1024
  message_retention_seconds = 172800
  receive_wait_time_seconds = 20
}

resource "aws_sqs_queue_policy" "notify_policy" {
  queue_url = aws_sqs_queue.upload_queue.id
  policy = data.aws_iam_policy_document.iam_notif_policy_doc.json
}

data "aws_iam_policy_document" "iam_notif_policy_doc" {
  statement {
    sid = "1"

    effect = "Allow"

    actions = [
      "sqs:SendMessage"
    ]

    resources = [
      aws_sqs_queue.upload_queue.arn,
    ]

    principals {
      type        = "AWS"
      identifiers = ["*"]
    }

    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"

      values = [
        "${aws_s3_bucket.upload_bucket.arn}"
      ]
    }
  }
}
