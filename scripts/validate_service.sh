#!/bin/bash
set -e

echo "Validating service..."

# Wait for app to start
sleep 10

# Check if container is running
if ! docker ps | grep flask-app; then
  echo "ERROR: Container is not running"
  exit 1
fi

# Health check
if ! curl -f http://localhost/health; then
  echo "ERROR: Health check failed"
  exit 1
fi

echo "Service validation successful!"