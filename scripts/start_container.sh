#!/bin/bash
set -e

echo "Starting new container..."

# Pull latest image from ECR
docker pull 503561416397.dkr.ecr.us-west-2.amazonaws.com/jenkins-cicd-app:latest

# Run container
docker run -d \
  --name flask-app \
  -p 80:5000 \
  --restart unless-stopped \
  503561416397.dkr.ecr.us-west-2.amazonaws.com/jenkins-cicd-app:latest

echo "Container started successfully"