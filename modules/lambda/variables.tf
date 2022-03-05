variable "name" {
  type        = string

  description = "Lambda name"
}

variable "description" {
    type = string
    default     = ""
    description = "Lambda description"
}

variable "handler" {
    type = string
    default = "index.lambda_handler"
    description = "Lambda handler"
}

variable "runtime" {
    type = string
    description = "Runtime for the lambda"
}

variable "source" {
    type = string
    description = "Path for the lambda code"
}
