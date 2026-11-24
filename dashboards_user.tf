# Fine-grained access control is backed by the OpenSearch internal user
# database, which requires a master username and password rather than an IAM
# role. The password is generated here, so it is present in OpenTofu state:
# treat the state backend as sensitive. The canonical copy for operators is the
# SSM SecureString below, encrypted with the stack KMS key.
#
# Rotating it means changing this password and applying: OpenSearch accepts a
# new master_user_password in place.
#
# The username is not stored in SSM: it is a stack variable with a default and
# is exposed as the dashboards_master_user_name output.

resource "random_password" "dashboards_master" {
  length  = 32
  special = true

  # OpenSearch rejects some punctuation in master passwords, so the set is
  # restricted to characters it reliably accepts.
  override_special = "!#$%&*()-_=+[]{}:?"

  min_lower   = 1
  min_upper   = 1
  min_numeric = 1
  min_special = 1
}

resource "aws_ssm_parameter" "dashboards_master_password" {
  name        = "/${var.name_prefix}/opensearch/master-user-password"
  description = "Password for the ${var.opensearch_master_user_name} master user on the ${local.domain_name} OpenSearch domain"
  type        = "SecureString"
  key_id      = module.kms_primary.key_arn
  value       = random_password.dashboards_master.result
  tier        = "Standard"

  tags = {
    Name = "${var.name_prefix}-opensearch-master-user-password"
  }
}
