#!/bin/bash

set -euo pipefail

# Exit if not running as root
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root" >&2
    exit 1
fi

# Script to install Docker and build images via an SSH tunnel.
# The tunnel is closed automatically when the script exits.

read -rp "SSH host: " SSH_HOST
read -rp "SSH port [22]: " SSH_PORT
SSH_PORT=${SSH_PORT:-22}
read -rp "SSH user: " SSH_USER
read -rsp "SSH password: " SSH_PASS
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
apt-get update -y
apt-get install -y sshpass sshuttle curl

SSH_CMD="sshpass -p \"$SSH_PASS\" ssh -o StrictHostKeyChecking=no -p $SSH_PORT"

echo "Starting SSH tunnel via sshuttle..."
sshuttle --ssh-cmd "$SSH_CMD" --daemon --pidfile /tmp/sshuttle.pid -r "$SSH_USER@$SSH_HOST" 0.0.0.0/0 ::/0 -v

# Wait a little to ensure tunnel is up
sleep 5

echo "Installing Docker using the official script..."
curl -fsSL https://get.docker.com | bash

# Install docker compose plugin if not present
if ! command -v docker compose >/dev/null 2>&1; then
    apt-get install -y docker-compose-plugin
fi

# Build and run Docker images
if [ -f docker-compose.yml ]; then
    echo "Building Docker images..."
    docker compose build
    echo "Starting containers..."
    docker compose up -d
fi

echo "Installation complete."

