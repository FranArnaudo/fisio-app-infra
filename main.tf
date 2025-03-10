terraform {
  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.50.0"
    }
  }
}

provider "hcloud" {
  token = var.hcloud_token
}

# Register SSH key
resource "hcloud_ssh_key" "default" {
  name       = "my-ssh-key"
  public_key = file("C:/Users/FranA/.ssh/id_ed25519.pub")
}

# Create a Hetzner volume to persist database data
resource "hcloud_volume" "db_volume" {
  name      = "db-volume"
  size      = 50                # Adjust size (in GB) as needed.
  server_id = hcloud_server.app.id
  format    = "ext4"
}

# Create the consolidated server with a user_data script
resource "hcloud_server" "app" {
  name        = "consolidated-app"
  server_type = "cx22"
  image       = "ubuntu-20.04"
  ssh_keys    = [hcloud_ssh_key.default.id]
  user_data   = <<-EOF
                #!/bin/bash
                apt-get update -y
                apt-get install -y docker.io docker-compose git

                # Create mount point for the database volume and mount it
                mkdir -p /mnt/db_volume
                mount /dev/disk/by-id/scsi-0HC_Volume_db-volume /mnt/db_volume

                # Log in to DockerHub (replace with your credentials as needed)
                docker login -u franarnaudo -p DFran24/11/99R

                # Fetch the public IP address from Hetzner metadata

                # Write the docker-compose.yml file
                cat << EOD > /root/docker-compose.yml
                version: '3'
                services:
                  frontend:
                    image: franarnaudo/fisio-app:fisio-app-fe-0.0.4
                    ports:
                      - "80:80"
                    restart: always

                  backend:
                    image: franarnaudo/fisio-app:fisio-app-be-0.0.4
                    ports:
                      - "8080:3000"
                    environment:
                      - POSTGRES_HOST=database
                      - POSTGRES_PORT=5432
                      - POSTGRES_USER=postgres
                      - POSTGRES_PASSWORD=Fran24
                      - POSTGRES_DB=fisio-app
                    restart: always

                  database:
                    image: postgres:13
                    environment:
                      POSTGRES_USER: postgres
                      POSTGRES_PASSWORD: Fran24
                      POSTGRES_DB: fisio-app
                    volumes:
                      - db-data:/var/lib/postgresql/data
                    restart: always

                volumes:
                  db-data:
                    driver: local
                    driver_opts:
                      type: none
                      o: bind
                      device: /mnt/db_volume
                EOD

                # Start containers using Docker Compose
                docker-compose -f /root/docker-compose.yml up -d
                EOF
}

# Firewall rules for the server (exposing only frontend and backend ports)
resource "hcloud_firewall" "app_firewall" {
  name = "app-firewall"

  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "80"
    source_ips = ["0.0.0.0/0"]
  }

  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "8080"
    source_ips = ["0.0.0.0/0"]
  }
}
