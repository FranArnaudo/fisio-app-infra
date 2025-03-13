#!/bin/bash

# Simple deployment script for FisioApp

# Default values
DEPLOYMENT_VERSION="1.0.0"
TERRAFORM_ACTION="apply"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --version)
      DEPLOYMENT_VERSION="$2"
      shift 2
      ;;
    --plan)
      TERRAFORM_ACTION="plan"
      shift
      ;;
    --help)
      echo "Usage: $0 [--version VERSION] [--plan]"
      echo ""
      echo "Options:"
      echo "  --version VERSION    Specify deployment version (default: 1.0.0)"
      echo "  --plan               Run terraform plan instead of apply"
      echo "  --help               Show this help message"
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

# Check if terraform is installed
if ! command -v terraform &> /dev/null; then
  echo "Terraform not found. Please install Terraform."
  exit 1
fi

# Check if terraform.tfvars exists
if [ ! -f terraform.tfvars ]; then
  echo "terraform.tfvars not found. Please create it by copying terraform.tfvars.example and filling in your values."
  exit 1
fi

# Initialize terraform if needed
if [ ! -d .terraform ]; then
  echo "Initializing Terraform..."
  terraform init
fi

# Run terraform with the specified action
echo "Running terraform $TERRAFORM_ACTION with deployment_version=$DEPLOYMENT_VERSION"
terraform $TERRAFORM_ACTION -var="deployment_version=$DEPLOYMENT_VERSION"

# If plan was successful and we're doing an apply, ask for confirmation
if [ "$TERRAFORM_ACTION" == "apply" ]; then
  echo ""
  read -p "Do you want to continue with the deployment? (y/n) " -n 1 -r
  echo ""
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    terraform apply -var="deployment_version=$DEPLOYMENT_VERSION" -auto-approve
  else
    echo "Deployment cancelled"
    exit 0
  fi
fi