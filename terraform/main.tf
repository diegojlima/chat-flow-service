
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region  = var.aws_region
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
}

data "aws_iam_policy_document" "assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda_exec_role" {
  name               = "lambda_exec_role"
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy.json
}

resource "aws_lambda_function" "chat_flow_service" {
  filename      = "${path.module}/../dist"
  function_name = var.lambda_function_name
  role          = aws_iam_role.lambda_exec_role.arn
  handler       = var.lambda_handler
  runtime       = var.lambda_runtime

  environment {
    variables = {
      MONGODB_URI            = aws_docdb_cluster.example.endpoint
      PROCESSED_QUEUE_URL    = aws_sqs_queue.processed_queue.url
      INTERACTION_QUEUE_URL  = aws_sqs_queue.interaction_queue.url
    }
  }

  source_code_hash = filebase64sha256("${path.module}/../lambda/deployment_package.zip")
}

resource "aws_sqs_queue" "interaction_queue" {
  name = "interaction_queue"
}

resource "aws_sqs_queue" "processed_queue" {
  name = "processed_queue"
}

resource "aws_docdb_cluster" "example" {
  cluster_identifier      = "docdb-cluster-example"
  master_username         = var.mongodb_username
  master_password         = var.mongodb_password
  backup_retention_period = 5
  preferred_backup_window = "07:00-09:00"
  skip_final_snapshot     = true
}

output "lambda_function_name" {
  value = aws_lambda_function.chat_flow_service.function_name
}

output "interaction_queue_url" {
  value = aws_sqs_queue.interaction_queue.url
}

output "processed_queue_url" {
  value = aws_sqs_queue.processed_queue.url
}

output "mongodb_endpoint" {
  value = aws_docdb_cluster.example.endpoint
}
