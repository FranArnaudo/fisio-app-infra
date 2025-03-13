#!/bin/bash

# This script helps import existing Hetzner Cloud resources into Terraform state

# Set variables
HCLOUD_TOKEN="0xjCtP8xuhaQsYFC7TNELBuGRSzAP73jhprEEbD6PUFn1QXW2ZcMKUL056BHN9ns"
SERVER_NAME="fisioapp-server"
SSH_KEY_NAME="FisioApp Deployment Key"

# Check if HCLOUD_TOKEN is set
if [ -z "$HCLOUD_TOKEN" ]; then
  echo "Please edit this script and set your HCLOUD_TOKEN before running"
  exit 1
fi

# Install hcloud CLI if not already installed
if ! command -v hcloud &> /dev/null; then
  echo "Installing hcloud CLI..."
  
  # Detect OS
  if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    # For Linux
    curl -fsSL https://github.com/hetznercloud/cli/releases/latest/download/hcloud-linux-amd64.tar.gz | tar -xzf - -C /tmp
    sudo mv /tmp/hcloud /usr/local/bin/
  elif [[ "$OSTYPE" == "darwin"* ]]; then
    # For macOS
    brew install hcloud
  else
    echo "Unsupported OS. Please install hcloud CLI manually."
    exit 1
  fi
fi

# Configure hcloud
echo "Configuring hcloud CLI..."
echo -n "$HCLOUD_TOKEN" > /tmp/hcloud_token
export HCLOUD_TOKEN="$HCLOUD_TOKEN"

# Get server ID
echo "Finding server ID for '$SERVER_NAME'..."
SERVER_ID=$(hcloud server list -o noheader -o columns=id,name | grep "$SERVER_NAME" | awk '{print $1}')

if [ -z "$SERVER_ID" ]; then
  echo "Server '$SERVER_NAME' not found"
  exit 1
else
  echo "Server '$SERVER_NAME' found with ID: $SERVER_ID"
fi

# Get SSH key ID
echo "Finding SSH key ID for '$SSH_KEY_NAME'..."
SSH_KEY_ID=$(hcloud ssh-key list -o noheader -o columns=id,name | grep "$SSH_KEY_NAME" | awk '{print $1}')

if [ -z "$SSH_KEY_ID" ]; then
  echo "SSH key '$SSH_KEY_NAME' not found"
else
  echo "SSH key '$SSH_KEY_NAME' found with ID: $SSH_KEY_ID"
fi

# Get firewall ID
FIREWALL_NAME="app-firewall"
echo "Finding firewall ID for '$FIREWALL_NAME'..."
FIREWALL_ID=$(hcloud firewall list -o noheader -o columns=id,name | grep "$FIREWALL_NAME" | awk '{print $1}')

if [ -z "$FIREWALL_ID" ]; then
  echo "Firewall '$FIREWALL_NAME' not found"
else
  echo "Firewall '$FIREWALL_NAME' found with ID: $FIREWALL_ID"
fi

# Import server
if [ ! -z "$SERVER_ID" ]; then
  echo "Importing server into Terraform state..."
  terraform import hcloud_server.app_server $SERVER_ID
fi

# Import firewall
if [ ! -z "$FIREWALL_ID" ]; then
  echo "Importing firewall into Terraform state..."
  terraform import hcloud_firewall.app_firewall $FIREWALL_ID
fi

echo "Done importing resources. You can now run 'terraform plan' to check if your configuration matches the imported resources."