output "app_ip" {
  description = "Public IP of the application server"
  value       = hcloud_server.app_server.ipv4_address
}

output "server_status" {
  description = "Current status of the server"
  value       = hcloud_server.app_server.status
}

output "deployment_version" {
  description = "Current deployment version"
  value       = var.deployment_version
}

output "application_url" {
  description = "URL to access the application"
  value       = "http://${hcloud_server.app_server.ipv4_address}"
}

output "api_url" {
  description = "URL to access the API"
  value       = "http://${hcloud_server.app_server.ipv4_address}:3000"
}