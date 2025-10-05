#!/bin/bash
set -e

echo "Installing dependencies..."

# Ensure Docker is running
systemctl start docker

# Login to ECR (replace with your account ID)
aws ecr get-login-password --region us-west-2 | \
  docker login --username AWS --password-stdin 503561416397.dkr.ecr.us-west-2.amazonaws.com

echo "Dependencies installed successfully"