# Define required providers
terraform {
  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.50.0"
    }
  }
}

# Configure the Hetzner Cloud Provider
provider "hcloud" {
  token = var.hcloud_token
}

# Data source for existing SSH key - use this instead of creating a new one
data "hcloud_ssh_key" "existing" {
  name = "FisioApp Deployment Key"
}

# Server configuration
resource "hcloud_server" "app_server" {
  name        = "fisioapp-server"
  image       = "ubuntu-20.04"
  server_type = "cx22"  # 4GB RAM, 2 vCPU
  location    = var.server_location
  ssh_keys    = [data.hcloud_ssh_key.existing.id]
  
  # Reference existing firewall
  firewall_ids = [hcloud_firewall.app_firewall.id]

  # Keep the server resource to a minimum
  # We don't want to modify the server itself during redeployments
  lifecycle {
    ignore_changes = [
      image,
      ssh_keys
    ]
  }
}

# Create a firewall for the server
resource "hcloud_firewall" "app_firewall" {
  name = "app-firewall"

  # Allow SSH
  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "22"
    source_ips = ["0.0.0.0/0", "::/0"]
  }

  # Allow HTTP
  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "80"
    source_ips = ["0.0.0.0/0", "::/0"]
  }

  # Allow HTTPS
  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "443"
    source_ips = ["0.0.0.0/0", "::/0"]
  }
  
  # Allow PostgreSQL external access
  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "5432"
    source_ips = ["0.0.0.0/0", "::/0"]  # Consider restricting this to specific IPs
  }
}

# Deployment resource - this will run every time you apply
# because of the triggers configuration
resource "null_resource" "deployment" {
  depends_on = [hcloud_server.app_server]

  # This will trigger a redeployment every time you run terraform apply
  # with a different deployment_version
  triggers = {
    deployment_version = var.deployment_version
  }

  # Initial server setup - will only run on first deploy
  provisioner "remote-exec" {
  inline = [
    "if [ ! -d /app ]; then",
    "  apt update",
    "  apt install -y docker.io docker-compose",
    "  systemctl enable docker",
    "  systemctl start docker",
    "  mkdir -p /app/data",
    "  docker volume create postgres_data || true",
    "fi",
    "# Always perform Docker login - outside the conditional",
    "echo ${var.docker_password} | docker login -u ${var.docker_username} --password-stdin"
  ]

    connection {
      type        = "ssh"
      user        = "root"
      private_key = file(var.ssh_private_key_path)
      host        = hcloud_server.app_server.ipv4_address
    }
  }

  # Generate docker-compose.yml on remote server
  provisioner "file" {
    content = templatefile("${path.module}/templates/docker-compose.yml.tpl", {
      docker_image_repo = var.docker_image_repo
      frontend_image_tag = var.frontend_image_tag
      backend_image_tag = var.backend_image_tag
      db_user = var.db_user
      db_password = var.db_password
      db_name = var.db_name
      api_url = "http://${hcloud_server.app_server.ipv4_address}:3000"
    })
    destination = "/app/docker-compose.yml"

    connection {
      type        = "ssh"
      user        = "root"
      private_key = file(var.ssh_private_key_path)
      host        = hcloud_server.app_server.ipv4_address
    }
  }

  # Generate environment files
  provisioner "file" {
    content = templatefile("${path.module}/templates/backend.env.tpl", {
      db_host     = "postgres"  # Service name in docker-compose
      db_user     = var.db_user
      db_password = var.db_password
      db_name     = var.db_name
      jwt_secret  = var.jwt_secret
    })
    destination = "/app/backend.env"

    connection {
      type        = "ssh"
      user        = "root"
      private_key = file(var.ssh_private_key_path)
      host        = hcloud_server.app_server.ipv4_address
    }
  }

  # Deploy the application
 provisioner "remote-exec" {
    inline = [
      "cd /app",
      "docker-compose down || true",
      "echo ${var.docker_password} | docker login -u ${var.docker_username} --password-stdin",
      "docker-compose pull",
      "docker-compose up -d"
    ]

    connection {
      type        = "ssh"
      user        = "root"
      private_key = file(var.ssh_private_key_path)
      host        = hcloud_server.app_server.ipv4_address
    }
  }
}

# Add backup setup - triggers only when backup configuration changes
resource "null_resource" "setup_backups" {
  depends_on = [null_resource.deployment]

  triggers = {
    backup_script_hash = sha256(file("${path.module}/templates/backup.sh.tpl"))
  }

  # Copy backup script
  provisioner "file" {
    content = templatefile("${path.module}/templates/backup.sh.tpl", {
      db_user = var.db_user
      db_name = var.db_name
      backups_to_keep = var.backups_to_keep
    })
    destination = "/app/backup.sh"

    connection {
      type        = "ssh"
      user        = "root"
      private_key = file(var.ssh_private_key_path)
      host        = hcloud_server.app_server.ipv4_address
    }
  }

  # Make backup script executable and set up cron job
  provisioner "remote-exec" {
    inline = [
      "chmod +x /app/backup.sh",
      "mkdir -p /app/backups",
      "(crontab -l 2>/dev/null | grep -v '/app/backup.sh' || true; echo \"0 3 * * * /app/backup.sh\") | crontab -"
    ]

    connection {
      type        = "ssh"
      user        = "root"
      private_key = file(var.ssh_private_key_path)
      host        = hcloud_server.app_server.ipv4_address
    }
  }
}