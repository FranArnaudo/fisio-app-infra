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

# Create a new SSH key
resource "hcloud_ssh_key" "default" {
  name       = "FisioApp Deployment Key"
  public_key = file("~/.ssh/id_rsa.pub")
}

# Create a server
resource "hcloud_server" "app_server" {
  name        = "fisioapp-server"
  image       = "ubuntu-20.04"
  server_type = "cx21"  # 4GB RAM, 2 vCPU - adjust as needed
  location    = var.server_location
  ssh_keys    = [hcloud_ssh_key.default.id]
  
  # Ensure firewall allows needed ports
  firewall_ids = [hcloud_firewall.app_firewall.id]

  # Additional volume for database persistence
  connection {
    type        = "ssh"
    user        = "root"
    private_key = file("~/.ssh/id_rsa")
    host        = self.ipv4_address
  }

  # Initial server setup
  provisioner "remote-exec" {
    inline = [
      "apt update",
      "apt install -y docker.io docker-compose",
      "systemctl enable docker",
      "systemctl start docker",
      "mkdir -p /app/data",
      "docker volume create postgres_data"
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

# Create the docker-compose.yml file
resource "null_resource" "docker_compose" {
  depends_on = [hcloud_server.app_server]

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
      private_key = file("~/.ssh/id_rsa")
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
      private_key = file("~/.ssh/id_rsa")
      host        = hcloud_server.app_server.ipv4_address
    }
  }

  # Deploy the application
  provisioner "remote-exec" {
    inline = [
      "cd /app",
      "docker-compose down || true",
      "docker-compose pull",
      "docker-compose up -d"
    ]

    connection {
      type        = "ssh"
      user        = "root"
      private_key = file("~/.ssh/id_rsa")
      host        = hcloud_server.app_server.ipv4_address
    }
  }
}

# Add backup setup
resource "null_resource" "setup_backups" {
  depends_on = [null_resource.docker_compose]

  # Copy backup script
  provisioner "file" {
    content = <<-EOT
      #!/bin/bash
      TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
      BACKUP_DIR="/app/backups"
      
      # Create backup directory if it doesn't exist
      mkdir -p $BACKUP_DIR
      
      # Backup the database
      docker exec fisioapp-postgres pg_dump -U ${var.db_user} -d ${var.db_name} > $BACKUP_DIR/fisioapp_$TIMESTAMP.sql
      
      # Compress the backup
      gzip $BACKUP_DIR/fisioapp_$TIMESTAMP.sql
      
      # Keep only the 7 most recent backups
      ls -t $BACKUP_DIR/*.gz | tail -n +8 | xargs rm -f
    EOT
    destination = "/app/backup.sh"

    connection {
      type        = "ssh"
      user        = "root"
      private_key = file("~/.ssh/id_rsa")
      host        = hcloud_server.app_server.ipv4_address
    }
  }

  # Make backup script executable and set up cron job
  provisioner "remote-exec" {
    inline = [
      "chmod +x /app/backup.sh",
      "mkdir -p /app/backups",
      "crontab -l 2>/dev/null | { cat; echo \"0 3 * * * /app/backup.sh\"; } | crontab -"
    ]

    connection {
      type        = "ssh"
      user        = "root"
      private_key = file("~/.ssh/id_rsa")
      host        = hcloud_server.app_server.ipv4_address
    }
  }
}