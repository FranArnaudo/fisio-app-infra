variable "hcloud_token" {
  description = "Hetzner Cloud API token"
  type        = string
  sensitive   = true
}

variable "server_location" {
  description = "Location for the server (nbg1, fsn1, hel1, ash)"
  type        = string
  default     = "hel1"  # Helsinki as default
}

variable "ssh_private_key_path" {
  description = "Path to the SSH private key file"
  type        = string
  default     = "~/.ssh/id_rsa"
}

variable "db_user" {
  description = "Database username"
  type        = string
  default     = "fisioapp"
}

variable "db_password" {
  description = "Database password"
  type        = string
  sensitive   = true
}

variable "db_name" {
  description = "Database name"
  type        = string
  default     = "fisioapp"
}

variable "docker_image_repo" {
  description = "Docker image repository"
  type        = string
  default     = "franarnaudo/fisio-app"
}

variable "frontend_image_tag" {
  description = "Frontend image tag"
  type        = string
  default     = "frontend-latest"
}

variable "backend_image_tag" {
  description = "Backend image tag"
  type        = string
  default     = "backend-latest"
}

variable "jwt_secret" {
  description = "JWT Secret for authentication"
  type        = string
  sensitive   = true
}

variable "deployment_version" {
  description = "Version tag to trigger redeployment"
  type        = string
  default     = "1.0.0"
}

variable "backups_to_keep" {
  description = "Number of database backups to retain"
  type        = number
  default     = 7
}

variable "docker_username" {
  description = "Docker Hub username"
  type        = string
  default     = "franarnaudo"
}

variable "docker_password" {
  description = "Docker Hub password"
  type        = string
  sensitive   = true
}