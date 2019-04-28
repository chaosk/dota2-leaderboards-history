variable "name" {
  type = "string"
}

variable "repo_name" {
  type = "string"
}

variable "repo_url" {
  type = "string"
}

variable "description" {
  type    = "string"
  default = ""
}

variable "available_memory_mb" {
  type    = "string"
  default = 128
}

variable "runtime" {
  type    = "string"
  default = "python37"
}
