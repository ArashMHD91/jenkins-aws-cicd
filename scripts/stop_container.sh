#!/bin/bash
set -e

echo "Stopping existing container..."

# Stop and remove existing container
docker stop flask-app || true
docker rm flask-app || true

echo "Container stopped successfully"
