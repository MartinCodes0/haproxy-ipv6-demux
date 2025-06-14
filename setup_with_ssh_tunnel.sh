#!/bin/bash

set -euo pipefail

# Script to install Docker and build images via an SSH tunnel.
# The tunnel is closed automatically when the script exits.

read -p "SSH host: " SSH_HOST
read -p "SSH port [22]: " SSH_PORT
SSH_PORT=${SSH_PORT:-22}
read -p "SSH user: " SSH_USER
read -s -p "SSH password: " SSH_PASS
echo

cleanup() {
    if [[ -f /tmp/sshuttle.pid ]]; then
        echo "Stopping SSH tunnel"
        kill "$(cat /tmp/sshuttle.pid)" || true
        rm -f /tmp/sshuttle.pid
    fi
}
trap cleanup EXIT

echo "Installing required packages..."
apt-get update
apt-get install -y sshpass sshuttle docker.io docker-compose

SSH_CMD="sshpass -p \"$SSH_PASS\" ssh -o StrictHostKeyChecking=no -p $SSH_PORT"

echo "Starting SSH tunnel via sshuttle..."
sshuttle --ssh-cmd "$SSH_CMD" --daemon --pidfile /tmp/sshuttle.pid -r "$SSH_USER@$SSH_HOST" 0.0.0.0/0 ::/0 -v

# Wait a little to ensure tunnel is up
sleep 5

echo "Installing Docker using the official script..."
curl -fsSL https://get.docker.com | bash

# Install docker-compose if not present
if ! command -v docker-compose >/dev/null 2>&1; then
    apt-get install -y docker-compose
fi

# Build and run Docker images
if [ -f docker-compose.yml ]; then
    echo "Building Docker images..."
    docker compose build
    echo "Starting containers..."
    docker compose up -d
fi

echo "Installation complete."

