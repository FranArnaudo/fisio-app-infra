# FisioApp Infrastructure

This repository contains Terraform configuration to deploy and manage the FisioApp infrastructure on Hetzner Cloud.

## Features

- **Persistent Infrastructure**: Server and IP address remains stable between deployments
- **Easy Redeployment**: Simple mechanism to update application without recreating infrastructure
- **Automated Backups**: Daily database backups with retention policy
- **Secure Configuration**: Sensitive values are kept separate and marked as sensitive
- **Docker-based Deployment**: Uses Docker Compose for clean, isolated deployments

## Prerequisites

- [Terraform](https://www.terraform.io/downloads.html) (v1.0.0+)
- [Hetzner Cloud](https://www.hetzner.com/cloud) account and API token
- SSH key pair for server access

## Getting Started

### 1. Configure Variables

Copy the example variables file and edit it with your values:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with your Hetzner Cloud API token and other configuration values.

### 2. Import Existing Resources (If Applicable)

If you already have a server and other resources deployed, use the import script:

```bash
# Edit the script first to set your Hetzner Cloud API token
chmod +x import-existing.sh
./import-existing.sh
```

### 3. Initialize Terraform

```bash
terraform init
```

### 4. Deploy or Update

For a new deployment:

```bash
terraform apply
```

For redeployment with the deployment script:

```bash
./deploy.sh --version 1.0.1
```

This updates the application without recreating the server or changing its IP address.

## Deployment

### First Deployment

```bash
terraform apply
```

### Redeploying

To redeploy the application (updating Docker images or configuration):

```bash
# Update the deployment version to trigger a redeployment
terraform apply -var="deployment_version=1.0.1"
```

Or use the deployment script:

```bash
./deploy.sh --version 1.0.1
```

### Planning Changes

To see what changes would be made:

```bash
terraform plan
```

Or with the deployment script:

```bash
./deploy.sh --plan --version 1.0.1
```

## Maintenance

### Database Backups

Database backups are automatically created daily at 3 AM. They are stored in `/app/backups` on the server.

To restore a backup:

```bash
# SSH into the server
ssh root@<server_ip>

# List available backups
ls -la /app/backups

# Restore a backup
gunzip -c /app/backups/fisioapp_20250312_030000.sql.gz | docker exec -i fisioapp-postgres psql -U fisioapp -d fisioapp
```

### Server Access

```bash
ssh root@<server_ip>
```

### Managing Docker Containers

```bash
ssh root@<server_ip>
cd /app
docker-compose ps
docker-compose logs backend
```

## Updating Docker Images

Update the image tags in your `terraform.tfvars` file:

```
frontend_image_tag = "frontend-v1.1.0"
backend_image_tag = "backend-v1.1.0"
```

Then run:

```bash
terraform apply
```

## File Structure

- `main.tf`: Main Terraform configuration
- `variables.tf`: Variable definitions
- `outputs.tf`: Output values
- `terraform.tfvars`: Variable values (not in source control)
- `templates/`: Configuration templates
  - `docker-compose.yml.tpl`: Docker Compose template
  - `backend.env.tpl`: Backend environment variables template
  - `backup.sh.tpl`: Backup script template
- `import-existing.sh`: Script to import existing resources
- `deploy.sh`: Simplified deployment script

## Troubleshooting

### Unable to connect to the server

- Check that your SSH key is correctly configured
- Verify the server's firewall allows SSH connections

### Application not starting

- Check Docker logs: `docker-compose logs`
- Verify environment variables in `/app/backend.env`

### Database connection issues

- Check that the PostgreSQL container is running: `docker-compose ps`
- Verify database credentials in environment files

## Advanced Configuration

### Custom Domain and SSL

To add a custom domain with SSL:

1. Update the Terraform configuration to include SSL certificates
2. Configure a reverse proxy (like Nginx) in the Docker Compose file
3. Update DNS records to point to the server's IP address

### Scaling

For scaling beyond a single server:

1. Configure database replication
2. Set up a load balancer
3. Modify the Docker Compose configuration for distributed deployment