output "app_ip" {
  description = "Public IP of the consolidated app server"
  value       = hcloud_server.app.ipv4_address
}
