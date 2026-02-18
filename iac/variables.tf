variable "lambda_hot_reload" {
  description = "Use LocalStack hot-reload for Lambdas (mounts local code; no zip upload). Requires prepare-hot-reload and volume mount in compose."
  type        = bool
  default     = false
}
