output "tf_state_bucket" {
  description = "Copiar a la variable TF_STATE_BUCKET de GitHub"
  value       = aws_s3_bucket.tfstate.bucket
}

output "github_actions_role_arn" {
  description = "Copiar a la variable AWS_ROLE_ARN de GitHub"
  value       = aws_iam_role.github_actions.arn
}
