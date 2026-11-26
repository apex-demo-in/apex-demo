data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

# Instance role: access is over SSM Session Manager, so no inbound ports and
# no long-lived credentials are needed.
data "aws_iam_policy_document" "instance_assume_role" {
  statement {
    sid     = "EC2AssumeRole"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "instance" {
  name               = "${var.name}-instance"
  description        = "Role for the ${var.name} application instance (SSM Session Manager access)"
  assume_role_policy = data.aws_iam_policy_document.instance_assume_role.json
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.instance.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "instance" {
  name = "${var.name}-instance"
  role = aws_iam_role.instance.name
}

resource "aws_security_group" "instance" {
  name        = "${var.name}-instance"
  description = "Security group for the ${var.name} application instance. No inbound access; outbound HTTPS only."
  vpc_id      = module.vpc.vpc_id

  tags = {
    Name = "${var.name}-instance"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Outbound HTTPS only: enough for SSM Session Manager and package updates.
# No ingress rules at all, so 22 and 3389 are closed to the internet.
resource "aws_vpc_security_group_egress_rule" "https" {
  security_group_id = aws_security_group.instance.id
  description       = "Allow outbound HTTPS for SSM Session Manager and package updates"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_instance" "app" {
  ami           = data.aws_ssm_parameter.al2023.value
  instance_type = var.instance_type

  subnet_id              = module.vpc.public_subnets[0]
  vpc_security_group_ids = [aws_security_group.instance.id]
  iam_instance_profile   = aws_iam_instance_profile.instance.name

  # The public address comes from the Elastic IP association below.
  associate_public_ip_address = false

  monitoring    = true
  ebs_optimized = true

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  root_block_device {
    encrypted             = true
    kms_key_id            = aws_kms_key.stack.arn
    volume_type           = "gp3"
    volume_size           = var.root_volume_size
    delete_on_termination = true
  }

  tags = {
    Name = "${var.name}-app"
  }
}

resource "aws_eip" "app" {
  domain = "vpc"

  tags = {
    Name = "${var.name}-app"
  }

  depends_on = [module.vpc]
}

resource "aws_eip_association" "app" {
  instance_id   = aws_instance.app.id
  allocation_id = aws_eip.app.id
}
