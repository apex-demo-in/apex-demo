resource "aws_cloudwatch_log_group" "flow_log" {
  name              = "/aws/vpc-flow-log/${var.name}"
  retention_in_days = var.flow_log_retention_days
  kms_key_id        = aws_kms_key.stack.arn
}

resource "aws_iam_role" "flow_log" {
  name        = "${var.name}-flow-log"
  description = "Role assumed by VPC Flow Logs to write into CloudWatch Logs"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Action    = "sts:AssumeRole"
        Principal = { Service = "vpc-flow-logs.amazonaws.com" }
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "flow_log" {
  name = "${var.name}-flow-log"
  role = aws_iam_role.flow_log.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Resource = "${aws_cloudwatch_log_group.flow_log.arn}:*"
      }
    ]
  })
}

resource "aws_flow_log" "vpc" {
  vpc_id                   = module.vpc.vpc_id
  traffic_type             = "ALL"
  iam_role_arn             = aws_iam_role.flow_log.arn
  log_destination_type     = "cloud-watch-logs"
  log_destination          = aws_cloudwatch_log_group.flow_log.arn
  max_aggregation_interval = 60
}
