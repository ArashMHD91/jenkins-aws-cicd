#!/bin/bash

echo "Stopping existing container..."

# Stop and remove existing container (ignore errors if it doesn't exist)
docker stop flask-app 2>/dev/null || echo "Container not running"
docker rm flask-app 2>/dev/null || echo "Container not found"

echo "Container cleanup completed"