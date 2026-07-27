variable "function_name" {
  description = "Name of the Lambda function"
  type        = string
}

variable "application_url" {
  description = "Application URL that Lambda will call"
  type        = string
}

variable "runtime" {
  description = "Lambda Python runtime"
  type        = string
  default     = "python3.12"
}

variable "timeout" {
  description = "Lambda timeout in seconds"
  type        = number
  default     = 15
}

variable "memory_size" {
  description = "Lambda memory in MB"
  type        = number
  default     = 128
}

variable "log_retention_days" {
  description = "CloudWatch log retention period"
  type        = number
  default     = 7
}
