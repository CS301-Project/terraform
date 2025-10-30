variable "bucket_name" {
  description = "Name of the S3 bucket for document verification"
  type        = string
}

variable "force_destroy" {
  description = "Allow bucket to be destroyed even if it contains objects"
  type        = bool
  default     = false
}

variable "enable_versioning" {
  description = "Enable versioning for the S3 bucket"
  type        = bool
  default     = true
}

variable "allowed_origins" {
  description = "List of allowed origins for CORS (for presigned URL uploads)"
  type        = list(string)
  default     = ["*"]
}

variable "document_ingest_lambda_arn" {
  description = "ARN of the Lambda function to trigger on object creation"
  type        = string
}

variable "filter_prefix" {
  description = "S3 object key prefix filter for Lambda trigger"
  type        = string
  default     = ""
}

variable "filter_suffix" {
  description = "S3 object key suffix filter for Lambda trigger (e.g., .pdf, .jpg)"
  type        = string
  default     = ""
}

variable "lambda_permission_id" {
  description = "ID of the Lambda permission resource (for depends_on)"
  type        = string
}
